require 'rails_helper'

RSpec.describe Exchanges::BaseExchangeService, type: :service do
  # Создаем тестовый класс, наследующий BaseExchangeService
  let(:test_service_class) do
    Class.new(Exchanges::BaseExchangeService) do
      def exchange_name
        "TestExchange"
      end

      def build_websocket_url(symbol)
        "wss://test.exchange.com/#{symbol.downcase}"
      end

      def handle_message(symbol, data)
        # Простая реализация для тестов
      end

      def parse_price_data(data)
        JSON.parse(data)
      end
    end
  end

  let(:service) { test_service_class.instance }

  before do
    # Принудительно останавливаем сервис
    service.stop if service.respond_to?(:running?) && service.running?

    # Сбрасываем внутреннее состояние сервиса
    service.instance_variable_set(:@connections, {})
    service.instance_variable_set(:@subscribed_symbols, Set.new)
    service.instance_variable_set(:@running, false)

    # Очищаем Rails cache
    Rails.cache.clear

    # Отключаем реальные WebSocket подключения
    allow(Faye::WebSocket::Client).to receive(:new).and_return(double(
      on: nil,
      close: nil
    ))
  end

  after do
    service.stop if service.respond_to?(:running?) && service.running?
  end

  describe '#start' do
    it 'устанавливает флаг running в true' do
      service.start
      expect(service.running?).to be true
    end

    it 'подписывается на активные алерты' do
      create(:alert, symbol: "BTCUSDT", active: true)
      expect(service).to receive(:subscribe_to_active_alerts)
      service.start
    end
  end

  describe '#stop' do
    before do
      service.start
    end

    it 'устанавливает флаг running в false' do
      service.stop
      expect(service.running?).to be false
    end

    it 'очищает кеш алертов' do
      Rails.cache.write("alerts:symbols:BTCUSDT", [ 1, 2, 3 ])
      service.stop
      expect(Rails.cache.read("alerts:symbols:BTCUSDT")).to be_nil
    end
  end

  describe '#add_alert' do
    let!(:alert) { create(:alert, symbol: "BTCUSDT", threshold_price: 50000.0, direction: "above") }

    it 'добавляет ID алерта в кеш символов' do
      service.add_alert(alert)
      cached_ids = Rails.cache.read("alerts:symbols:#{alert.symbol}")
      expect(cached_ids).to be_present
      expect(cached_ids).to include(alert.id)
    end

    it 'добавляет данные алерта в кеш' do
      service.add_alert(alert)
      cached_data = Rails.cache.read("alerts:data:#{alert.id}")

      expect(cached_data).to be_present
      expect(cached_data).to include(
        symbol: alert.symbol,
        threshold_price: alert.threshold_price,
        direction: alert.direction,
        last_price: nil
      )
    end

    it 'не дублирует алерт в кеше' do
      service.add_alert(alert)
      service.add_alert(alert)

      cached_ids = Rails.cache.read("alerts:symbols:#{alert.symbol}")
      expect(cached_ids).to be_present
      expect(cached_ids.count(alert.id)).to eq(1)
    end

    it 'логирует добавление алерта' do
      expect(Rails.logger).to receive(:info).with(/Алерт ##{alert.id}.*добавлен/)
      service.add_alert(alert)
    end
  end

  describe '#remove_alert' do
    let!(:alert) { create(:alert, symbol: "BTCUSDT") }

    before do
      service.add_alert(alert)
    end

    it 'удаляет ID алерта из кеша символов' do
      service.remove_alert(alert.id, alert.symbol)
      cached_ids = Rails.cache.read("alerts:symbols:#{alert.symbol}")
      expect(cached_ids).not_to include(alert.id) if cached_ids
    end

    it 'удаляет данные алерта из кеша' do
      service.remove_alert(alert.id, alert.symbol)
      cached_data = Rails.cache.read("alerts:data:#{alert.id}")
      expect(cached_data).to be_nil
    end

    context 'когда это последний алерт для символа' do
      it 'отписывается от символа' do
        expect(service).to receive(:unsubscribe_from_symbol).with(alert.symbol)
        service.remove_alert(alert.id, alert.symbol)
      end

      it 'удаляет ключ символа из кеша' do
        service.remove_alert(alert.id, alert.symbol)
        expect(Rails.cache.exist?("alerts:symbols:#{alert.symbol}")).to be false
      end
    end

    context 'когда есть другие алерты для символа' do
      let!(:another_alert) { create(:alert, symbol: "BTCUSDT") }

      it 'не отписывается от символа' do
        # Добавляем алерты в тесте
        service.add_alert(alert)
        service.add_alert(another_alert)

        # Мокаем unsubscribe_from_symbol чтобы проверить, что он не вызывается
        allow(service).to receive(:unsubscribe_from_symbol)
        expect(service).not_to receive(:unsubscribe_from_symbol)
        service.remove_alert(alert.id, alert.symbol)
      end

      it 'сохраняет другие ID алертов в кеше' do
        # Добавляем алерты в тесте
        service.add_alert(alert)
        service.add_alert(another_alert)

        service.remove_alert(alert.id, alert.symbol)
        cached_ids = Rails.cache.read("alerts:symbols:#{alert.symbol}")
        expect(cached_ids).to be_present
        expect(cached_ids).to include(another_alert.id)
      end
    end
  end

  describe '#update_alert' do
    let!(:alert) { create(:alert, symbol: "BTCUSDT", threshold_price: 50000.0) }

    it 'обновляет данные алерта в кеше' do
      # Добавляем алерт в кеш
      service.add_alert(alert)

      alert.threshold_price = 60000.0
      service.update_alert(alert)

      cached_data = Rails.cache.read("alerts:data:#{alert.id}")
      expect(cached_data).to be_present
      expect(cached_data[:threshold_price]).to eq(60000.0)
    end

    it 'логирует обновление алерта' do
      expect(Rails.logger).to receive(:info).with(/Алерт ##{alert.id}.*обновлен/)
      service.update_alert(alert)
    end
  end

  describe '#alerts_count_for_symbol' do
    let(:symbol) { "BTCUSDT" }

    context 'когда нет алертов для символа' do
      it 'возвращает 0' do
        expect(service.alerts_count_for_symbol(symbol)).to eq(0)
      end
    end

    context 'когда есть алерты для символа' do
      let!(:alert1) { create(:alert, symbol: symbol) }
      let!(:alert2) { create(:alert, symbol: symbol) }

      it 'возвращает правильное количество алертов' do
        # Добавляем алерты в тесте
        service.add_alert(alert1)
        service.add_alert(alert2)
        expect(service.alerts_count_for_symbol(symbol)).to eq(2)
      end
    end
  end

  describe '#subscribe_to_symbol' do
    let(:symbol) { "BTCUSDT" }

    it 'создает WebSocket подключение' do
      ws_mock = double('websocket')
      allow(ws_mock).to receive(:on)
      expect(Faye::WebSocket::Client).to receive(:new).with(
        "wss://test.exchange.com/btcusdt"
      ).and_return(ws_mock)

      service.subscribe_to_symbol(symbol)
    end

    it 'добавляет символ в список подписанных' do
      service.subscribe_to_symbol(symbol)
      expect(service.subscribed_symbols).to include(symbol)
    end

    it 'не создает дублирующее подключение' do
      service.subscribe_to_symbol(symbol)
      expect(Faye::WebSocket::Client).not_to receive(:new)
      service.subscribe_to_symbol(symbol)
    end

    context 'когда происходит ошибка подключения' do
      before do
        allow(Faye::WebSocket::Client).to receive(:new).and_raise(StandardError.new("Connection error"))
      end

      it 'логирует ошибку' do
        expect(Rails.logger).to receive(:error).with(/Ошибка подключения/).at_least(:once)
        expect(Rails.logger).to receive(:error).with(anything).at_least(:once)
        service.subscribe_to_symbol(symbol)
      end

      it 'не добавляет символ в список подписанных' do
        service.subscribe_to_symbol(symbol)
        expect(service.subscribed_symbols).not_to include(symbol)
      end
    end
  end

  describe '#unsubscribe_from_symbol' do
    let(:symbol) { "BTCUSDT" }
    let(:ws_mock) { double('websocket', on: nil, close: nil) }

    before do
      allow(Faye::WebSocket::Client).to receive(:new).and_return(ws_mock)
      service.subscribe_to_symbol(symbol)
    end

    it 'закрывает WebSocket подключение' do
      expect(ws_mock).to receive(:close)
      service.unsubscribe_from_symbol(symbol)
    end

    it 'удаляет символ из списка подписанных' do
      service.unsubscribe_from_symbol(symbol)
      expect(service.subscribed_symbols).not_to include(symbol)
    end

    it 'логирует отписку' do
      expect(Rails.logger).to receive(:info).with(/отписан от #{symbol}/)
      service.unsubscribe_from_symbol(symbol)
    end
  end

  describe '#running?' do
    it 'возвращает false когда сервис не запущен' do
      expect(service.running?).to be false
    end

    it 'возвращает true когда сервис запущен' do
      service.start
      expect(service.running?).to be true
    end
  end

  describe '#subscribed_symbols' do
    it 'возвращает массив подписанных символов' do
      service.subscribe_to_symbol("BTCUSDT")
      service.subscribe_to_symbol("ETHUSDT")

      expect(service.subscribed_symbols).to match_array([ "BTCUSDT", "ETHUSDT" ])
    end

    it 'возвращает пустой массив когда нет подписок' do
      expect(service.subscribed_symbols).to eq([])
    end
  end

  describe '#trigger_alert (private)' do
    let!(:alert) { create(:alert, symbol: "BTCUSDT", active: true, triggered_at: nil) }
    let(:current_price) { BigDecimal("50000.00") }

    before do
      service.add_alert(alert)
    end

    it 'обновляет алерт как сработавший' do
      service.send(:trigger_alert, alert.id, current_price)
      alert.reload

      expect(alert.triggered?).to be true
      expect(alert.active).to be false
      expect(alert.triggered_at).to be_present
    end

    it 'удаляет алерт из кеша' do
      service.send(:trigger_alert, alert.id, current_price)

      cached_data = Rails.cache.read("alerts:data:#{alert.id}")
      expect(cached_data).to be_nil
    end

    it 'отправляет broadcast через ActionCable' do
      expect(ActionCable.server).to receive(:broadcast).with("alerts", hash_including(
        type: "triggered",
        alert_id: alert.id,
        symbol: alert.symbol,
        current_price: current_price.to_f
      ))

      service.send(:trigger_alert, alert.id, current_price)
    end

    it 'логирует срабатывание алерта' do
      expect(Rails.logger).to receive(:info).with(/Алерт ##{alert.id}.*сработал/).at_least(:once)
      expect(Rails.logger).to receive(:info).with(anything).at_least(:once)
      service.send(:trigger_alert, alert.id, current_price)
    end

    context 'когда алерт не найден' do
      it 'не вызывает ошибку' do
        expect {
          service.send(:trigger_alert, 999999, current_price)
        }.not_to raise_error
      end
    end

    context 'когда алерт уже сработал' do
      before do
        alert.update(triggered_at: 1.hour.ago, active: false)
      end

      it 'не обновляет алерт повторно' do
        original_triggered_at = alert.triggered_at
        service.send(:trigger_alert, alert.id, current_price)
        alert.reload

        expect(alert.triggered_at).to eq(original_triggered_at)
      end
    end

    context 'когда возникает ошибка при обновлении' do
      before do
        allow(Alert).to receive(:find_by).and_return(alert)
        allow(alert).to receive(:update!).and_raise(StandardError.new("Database error"))
      end

      it 'логирует ошибку' do
        expect(Rails.logger).to receive(:error).with(/Ошибка срабатывания алерта/)
        service.send(:trigger_alert, alert.id, current_price)
      end
    end
  end

  describe '#subscribe_to_active_alerts (private)' do
    context 'когда есть активные алерты' do
      let!(:alert1) { create(:alert, symbol: "BTCUSDT", active: true, triggered_at: nil) }
      let!(:alert2) { create(:alert, symbol: "ETHUSDT", active: true, triggered_at: nil) }
      let!(:inactive_alert) { create(:alert, symbol: "BNBUSDT", active: false) }
      let!(:triggered_alert) { create(:alert, :triggered, symbol: "ADAUSDT") }

      it 'добавляет только активные не сработавшие алерты' do
        # Убеждаемся что алерты действительно активны
        expect(alert1.active?).to be true
        expect(alert2.active?).to be true
        expect(alert1.triggered?).to be false
        expect(alert2.triggered?).to be false

        service.send(:subscribe_to_active_alerts)

        expect(Rails.cache.exist?("alerts:data:#{alert1.id}")).to be true
        expect(Rails.cache.exist?("alerts:data:#{alert2.id}")).to be true
        expect(Rails.cache.exist?("alerts:data:#{inactive_alert.id}")).to be false
        expect(Rails.cache.exist?("alerts:data:#{triggered_alert.id}")).to be false
      end

      it 'подписывается на уникальные символы' do
        expect(service).to receive(:subscribe_to_symbol).with("BTCUSDT")
        expect(service).to receive(:subscribe_to_symbol).with("ETHUSDT")
        expect(service).not_to receive(:subscribe_to_symbol).with("BNBUSDT")
        expect(service).not_to receive(:subscribe_to_symbol).with("ADAUSDT")

        service.send(:subscribe_to_active_alerts)
      end

      it 'логирует количество загруженных алертов' do
        expect(Rails.logger).to receive(:info).with(/Загружено 2 алертов для 2 символов/).at_least(:once)
        expect(Rails.logger).to receive(:info).with(anything).at_least(:once)
        service.send(:subscribe_to_active_alerts)
      end
    end

    context 'когда нет активных алертов' do
      it 'не выполняет действий' do
        expect(service).not_to receive(:add_alert)
        expect(service).not_to receive(:subscribe_to_symbol)

        service.send(:subscribe_to_active_alerts)
      end
    end
  end

  describe 'Singleton паттерн' do
    it 'возвращает один и тот же экземпляр' do
      instance1 = test_service_class.instance
      instance2 = test_service_class.instance

      expect(instance1).to be(instance2)
    end

    it 'не позволяет создавать экземпляры через new' do
      expect { test_service_class.new }.to raise_error(NoMethodError)
    end
  end
end
