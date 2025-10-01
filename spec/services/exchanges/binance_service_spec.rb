require 'rails_helper'

RSpec.describe Exchanges::BinanceService, type: :service do
  let(:service) { described_class.instance }

  before do
    # Очистка Singleton между тестами
    service.stop if service.respond_to?(:running?) && service.running?

    # Сбрасываем внутреннее состояние сервиса
    service.instance_variable_set(:@connections, {})
    service.instance_variable_set(:@subscribed_symbols, Set.new)
    service.instance_variable_set(:@running, false)
  end

  after do
    service.stop if service.respond_to?(:running?) && service.running?
  end

  describe '#exchange_name' do
    it 'возвращает "Binance"' do
      expect(service.send(:exchange_name)).to eq("Binance")
    end
  end

  describe '#build_websocket_url' do
    it 'строит правильный URL для WebSocket подключения' do
      url = service.send(:build_websocket_url, "BTCUSDT")
      expect(url).to eq("wss://stream.binance.com:9443/ws/btcusdt@ticker")
    end

    it 'конвертирует символ в нижний регистр' do
      url = service.send(:build_websocket_url, "ETHUSDT")
      expect(url).to eq("wss://stream.binance.com:9443/ws/ethusdt@ticker")
    end
  end

  describe '#parse_price_data' do
    let(:ticker_data) do
      {
        "c" => "50000.50",
        "v" => "1000.5",
        "P" => "2.5",
        "h" => "51000.00",
        "l" => "49000.00"
      }.to_json
    end

    it 'парсит данные о цене из JSON' do
      result = service.send(:parse_price_data, ticker_data)

      expect(result[:price]).to eq(BigDecimal("50000.50"))
      expect(result[:volume]).to eq("1000.5")
      expect(result[:change_24h]).to eq("2.5")
      expect(result[:high_24h]).to eq("51000.00")
      expect(result[:low_24h]).to eq("49000.00")
    end
  end

  describe '#handle_message' do
    let(:symbol) { "BTCUSDT" }
    let(:ticker_data) do
      {
        "c" => "50000.00",
        "v" => "1000.5",
        "P" => "2.5",
        "h" => "51000.00",
        "l" => "49000.00"
      }.to_json
    end

    context 'когда нет активных алертов для символа' do
      it 'обрабатывает сообщение без ошибок' do
        expect {
          service.send(:handle_message, symbol, ticker_data)
        }.not_to raise_error
      end

      it 'не отправляет broadcast когда нет алертов' do
        expect(ActionCable.server).not_to receive(:broadcast)

        service.send(:handle_message, symbol, ticker_data)
      end
    end

    context 'когда есть активные алерты' do
      let!(:alert) { create(:alert, symbol: symbol, threshold_price: 48000.00, direction: "above") }

      before do
        # Симулируем добавление алерта в кеш в правильном формате
        Rails.cache.write("alerts:symbols:#{symbol}", [ alert.id ])
        Rails.cache.write("alerts:data:#{alert.id}", {
          symbol: alert.symbol,
          threshold_price: alert.threshold_price,
          direction: alert.direction,
          notification_channel_ids: [],
          last_price: nil
        })
      end

      context 'когда условие срабатывания выполнено (цена выше порога)' do
        it 'обрабатывает сообщение без ошибок' do
          expect {
            service.send(:handle_message, symbol, ticker_data)
          }.not_to raise_error
        end

        it 'инициализирует алерт при первом обновлении' do
          # Ожидаем broadcast в канал "alerts" для инициализации (не срабатывания)
          expect(ActionCable.server).to receive(:broadcast).with("alerts", hash_including(
            type: "price_update",
            alert_id: alert.id,
            symbol: symbol,
            current_price: 50000.00,
            last_price: 50000.00
          ))

          service.send(:handle_message, symbol, ticker_data)
        end
      end

      context 'когда условие срабатывания не выполнено' do
        let(:ticker_data_below) do
          {
            "c" => "45000.00",
            "v" => "1000.5",
            "P" => "2.5",
            "h" => "51000.00",
            "l" => "49000.00"
          }.to_json
        end

        it 'обрабатывает сообщение без ошибок' do
          expect {
            service.send(:handle_message, symbol, ticker_data_below)
          }.not_to raise_error
        end

        it 'отправляет broadcast с данными о цене' do
          # Ожидаем broadcast в канал "alerts" для обновления цены (алерт не сработал)
          expect(ActionCable.server).to receive(:broadcast).with("alerts", hash_including(
            type: "price_update",
            alert_id: alert.id,
            symbol: symbol,
            current_price: 45000.00
          ))

          service.send(:handle_message, symbol, ticker_data_below)
        end
      end

      context 'когда направление "below"' do
        let!(:alert_below) { create(:alert, symbol: "ETHUSDT", threshold_price: 3000.00, direction: "below") }
        let(:eth_ticker_below) do
          {
            "c" => "2900.00",
            "v" => "500.5",
            "P" => "-2.5",
            "h" => "3100.00",
            "l" => "2900.00"
          }.to_json
        end

        before do
          Rails.cache.write("alerts:symbols:ETHUSDT", [ alert_below.id ])
          Rails.cache.write("alerts:data:#{alert_below.id}", {
            symbol: alert_below.symbol,
            threshold_price: alert_below.threshold_price,
            direction: alert_below.direction,
            notification_channel_ids: [],
            last_price: nil
          })
        end

        it 'обрабатывает сообщение без ошибок' do
          expect {
            service.send(:handle_message, "ETHUSDT", eth_ticker_below)
          }.not_to raise_error
        end

        it 'инициализирует алерт при первом обновлении' do
          # Ожидаем broadcast в канал "alerts" для инициализации (не срабатывания)
          expect(ActionCable.server).to receive(:broadcast).with("alerts", hash_including(
            type: "price_update",
            alert_id: alert_below.id,
            symbol: "ETHUSDT",
            current_price: 2900.00,
            last_price: 2900.00
          ))

          service.send(:handle_message, "ETHUSDT", eth_ticker_below)
        end
      end
    end

    context 'когда JSON невалидный' do
      it 'логирует ошибку парсинга' do
        expect(Rails.logger).to receive(:error).with(/Ошибка парсинга JSON/)
        service.send(:handle_message, symbol, "invalid json")
      end

      it 'не вызывает исключение' do
        expect {
          service.send(:handle_message, symbol, "invalid json")
        }.not_to raise_error
      end
    end

    context 'когда происходит общая ошибка' do
      before do
        allow(JSON).to receive(:parse).and_raise(StandardError.new("Тестовая ошибка"))
      end

      it 'логирует общую ошибку обработки' do
        expect(Rails.logger).to receive(:error).with(/Ошибка обработки сообщения/)
        service.send(:handle_message, symbol, ticker_data)
      end

      it 'не вызывает исключение' do
        expect {
          service.send(:handle_message, symbol, ticker_data)
        }.not_to raise_error
      end
    end
  end

  describe 'интеграция с ActionCable' do
    let(:symbol) { "BTCUSDT" }
    let(:ticker_data) do
      { "c" => "50000.00", "v" => "1000", "P" => "2", "h" => "51000", "l" => "49000" }.to_json
    end

    before do
      # Очищаем кеш, чтобы убедиться, что нет алертов
      Rails.cache.delete_matched("alerts:*")
    end

    it 'не отправляет broadcast когда нет алертов' do
      expect(ActionCable.server).not_to receive(:broadcast)

      service.send(:handle_message, symbol, ticker_data)
    end
  end

  describe '#check_threshold_crossing' do
    let(:threshold_price) { BigDecimal("100.0") }

    context 'для направления "above"' do
      it 'возвращает true при пересечении снизу вверх' do
        result = service.send(:check_threshold_crossing,
          BigDecimal("110.0"), # current_price
          BigDecimal("95.0"),  # last_price
          threshold_price,
          "above"
        )
        expect(result).to be true
      end

      it 'возвращает false если цена уже была выше порога' do
        result = service.send(:check_threshold_crossing,
          BigDecimal("120.0"), # current_price
          BigDecimal("105.0"), # last_price
          threshold_price,
          "above"
        )
        expect(result).to be false
      end

      it 'возвращает false если цена все еще ниже порога' do
        result = service.send(:check_threshold_crossing,
          BigDecimal("90.0"),  # current_price
          BigDecimal("95.0"),  # last_price
          threshold_price,
          "above"
        )
        expect(result).to be false
      end

      it 'возвращает false если last_price равен nil' do
        result = service.send(:check_threshold_crossing,
          BigDecimal("110.0"), # current_price
          nil,                 # last_price
          threshold_price,
          "above"
        )
        expect(result).to be false
      end
    end

    context 'для направления "below"' do
      it 'возвращает true при пересечении сверху вниз' do
        result = service.send(:check_threshold_crossing,
          BigDecimal("90.0"),  # current_price
          BigDecimal("105.0"), # last_price
          threshold_price,
          "below"
        )
        expect(result).to be true
      end

      it 'возвращает false если цена уже была ниже порога' do
        result = service.send(:check_threshold_crossing,
          BigDecimal("80.0"),  # current_price
          BigDecimal("95.0"),  # last_price
          threshold_price,
          "below"
        )
        expect(result).to be false
      end

      it 'возвращает false если цена все еще выше порога' do
        result = service.send(:check_threshold_crossing,
          BigDecimal("110.0"), # current_price
          BigDecimal("105.0"), # last_price
          threshold_price,
          "below"
        )
        expect(result).to be false
      end
    end
  end

  describe 'логика инициализации алерта' do
    let(:symbol) { "STRKUSDT" }
    let!(:alert) { create(:alert, symbol: symbol, threshold_price: 0.1, direction: "above") }

    before do
      Rails.cache.write("alerts:symbols:#{symbol}", [ alert.id ])
      Rails.cache.write("alerts:data:#{alert.id}", {
        symbol: alert.symbol,
        threshold_price: alert.threshold_price,
        direction: alert.direction,
        notification_channel_ids: [],
        last_price: nil
      })
    end

    context 'при первом обновлении цены' do
      let(:first_ticker_data) do
        { "c" => "0.13", "v" => "1000", "P" => "2", "h" => "0.15", "l" => "0.12" }.to_json
      end

      it 'инициализирует алерт без срабатывания' do
        expect(ActionCable.server).to receive(:broadcast).with("alerts", hash_including(
          type: "price_update",
          alert_id: alert.id,
          symbol: symbol,
          current_price: 0.13,
          last_price: 0.13
        ))

        service.send(:handle_message, symbol, first_ticker_data)
      end

      it 'не срабатывает алерт при первом обновлении' do
        expect(ActionCable.server).not_to receive(:broadcast).with("alerts", hash_including(
          type: "triggered"
        ))

        service.send(:handle_message, symbol, first_ticker_data)
      end
    end

    context 'при последующих обновлениях' do
      let(:first_ticker_data) do
        { "c" => "0.13", "v" => "1000", "P" => "2", "h" => "0.15", "l" => "0.12" }.to_json
      end

      let(:second_ticker_data) do
        { "c" => "0.08", "v" => "1000", "P" => "2", "h" => "0.15", "l" => "0.08" }.to_json
      end

      let(:third_ticker_data) do
        { "c" => "0.12", "v" => "1000", "P" => "2", "h" => "0.15", "l" => "0.08" }.to_json
      end

      it 'срабатывает алерт только при пересечении порога снизу вверх' do
        # Первое обновление - инициализация
        service.send(:handle_message, symbol, first_ticker_data)

        # Второе обновление - цена упала ниже порога
        service.send(:handle_message, symbol, second_ticker_data)

        # Третье обновление - цена поднялась выше порога (должен сработать алерт)
        expect(ActionCable.server).to receive(:broadcast).with("alerts", hash_including(
          type: "triggered",
          alert_id: alert.id,
          symbol: symbol,
          current_price: 0.12
        ))

        service.send(:handle_message, symbol, third_ticker_data)
      end
    end
  end
end
