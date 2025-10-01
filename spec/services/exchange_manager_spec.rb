require 'rails_helper'

RSpec.describe ExchangeManager, type: :service do
  let(:manager) { described_class.instance }

  before(:each) do
    # Полностью сбрасываем состояние менеджера
    manager.stop if manager.respond_to?(:running?) && manager.running?
    manager.instance_variable_set(:@services, {})

    # Очищаем все моки
    RSpec::Mocks.space.proxy_for(Exchanges::BinanceService).reset if RSpec::Mocks.space.proxy_for(Exchanges::BinanceService)
  end

  after(:each) do
    manager.stop if manager.respond_to?(:running?) && manager.running?
    manager.instance_variable_set(:@services, {})
  end

  def create_binance_service_mock
    binance_service = instance_double(Exchanges::BinanceService)
    allow(Exchanges::BinanceService).to receive(:instance).and_return(binance_service)
    allow(binance_service).to receive(:start)
    allow(binance_service).to receive(:stop)
    allow(binance_service).to receive(:running?).and_return(false)
    allow(binance_service).to receive(:add_alert)
    allow(binance_service).to receive(:remove_alert)
    allow(binance_service).to receive(:update_alert)
    allow(binance_service).to receive(:subscribe_to_symbol)
    allow(binance_service).to receive(:unsubscribe_from_symbol)
    binance_service
  end

  describe '#start' do
    it 'запускает все включенные биржи' do
      binance_service = create_binance_service_mock
      expect(binance_service).to receive(:start)
      manager.start
    end

    it 'добавляет сервисы в хеш' do
      create_binance_service_mock
      manager.start
      expect(manager.status[:total_services]).to be > 0
    end
  end

  describe '#stop' do
    before do
      create_binance_service_mock
      manager.start
    end

    it 'останавливает все запущенные сервисы' do
      # Получаем сервис из менеджера и настраиваем ожидание
      service = manager.get_service("binance")
      expect(service).to receive(:stop)
      manager.stop
    end

    it 'очищает хеш сервисов' do
      manager.stop
      expect(manager.status[:total_services]).to eq(0)
    end
  end

  describe '#add_alert' do
    let(:alert) { create(:alert, symbol: "BTCUSDT") }

    before do
      create_binance_service_mock
      manager.start
    end

    it 'добавляет алерт во все сервисы' do
      service = manager.get_service("binance")
      expect(service).to receive(:add_alert).with(alert)
      manager.add_alert(alert)
    end
  end

  describe '#remove_alert' do
    let(:alert_id) { 1 }
    let(:symbol) { "BTCUSDT" }

    before do
      create_binance_service_mock
      manager.start
    end

    it 'удаляет алерт из всех сервисов' do
      service = manager.get_service("binance")
      expect(service).to receive(:remove_alert).with(alert_id, symbol)
      manager.remove_alert(alert_id, symbol)
    end
  end

  describe '#update_alert' do
    let(:alert) { create(:alert, symbol: "BTCUSDT") }

    before do
      create_binance_service_mock
      manager.start
    end

    it 'обновляет алерт во всех сервисах' do
      service = manager.get_service("binance")
      expect(service).to receive(:update_alert).with(alert)
      manager.update_alert(alert)
    end
  end

  describe '#subscribe_to_symbol' do
    let(:symbol) { "BTCUSDT" }

    before do
      create_binance_service_mock
      manager.start
    end

    it 'подписывается на символ во всех сервисах' do
      service = manager.get_service("binance")
      expect(service).to receive(:subscribe_to_symbol).with(symbol)
      manager.subscribe_to_symbol(symbol)
    end
  end

  describe '#unsubscribe_from_symbol' do
    let(:symbol) { "BTCUSDT" }

    before do
      create_binance_service_mock
      manager.start
    end

    it 'отписывается от символа во всех сервисах' do
      service = manager.get_service("binance")
      expect(service).to receive(:unsubscribe_from_symbol).with(symbol)
      manager.unsubscribe_from_symbol(symbol)
    end
  end

  describe '#status' do
    context 'когда менеджер не запущен' do
      it 'возвращает статус с пустыми сервисами' do
        status = manager.status
        expect(status[:total_services]).to eq(0)
        expect(status[:running_services]).to eq([])
      end
    end

    context 'когда менеджер запущен' do
      before do
        create_binance_service_mock
        manager.start
      end

      it 'возвращает статус с включенными биржами' do
        status = manager.status
        expect(status[:enabled_exchanges]).to include("binance")
      end

      it 'возвращает количество сервисов' do
        status = manager.status
        expect(status[:total_services]).to be > 0
      end

      context 'когда есть запущенные сервисы' do
        before do
          create_binance_service_mock
          manager.start
          service = manager.get_service("binance")
          allow(service).to receive(:running?).and_return(true)
        end

        it 'включает запущенные сервисы в статус' do
          status = manager.status
          expect(status[:running_services]).to include("binance")
        end
      end
    end
  end

  describe '#get_service' do
    before do
      create_binance_service_mock
      manager.start
    end

    it 'возвращает сервис по имени биржи' do
      service = manager.get_service("binance")
      expect(service).to be_present
      expect(service).to respond_to(:start)
      expect(service).to respond_to(:stop)
      expect(service).to respond_to(:running?)
    end

    it 'возвращает nil для несуществующей биржи' do
      service = manager.get_service("nonexistent")
      expect(service).to be_nil
    end
  end

  describe '#running?' do
    context 'когда менеджер не запущен' do
      it 'возвращает false' do
        expect(manager.running?).to be false
      end
    end

    context 'когда хотя бы один сервис запущен' do
      before do
        create_binance_service_mock
        manager.start
        service = manager.get_service("binance")
        allow(service).to receive(:running?).and_return(true)
      end

      it 'возвращает true' do
        expect(manager.running?).to be true
      end
    end

    context 'когда все сервисы остановлены' do
      before do
        create_binance_service_mock
        manager.start
        service = manager.get_service("binance")
        allow(service).to receive(:running?).and_return(false)
      end

      it 'возвращает false' do
        expect(manager.running?).to be false
      end
    end
  end

  describe 'Singleton паттерн' do
    it 'возвращает один и тот же экземпляр' do
      instance1 = described_class.instance
      instance2 = described_class.instance

      expect(instance1).to be(instance2)
    end

    it 'не позволяет создавать экземпляры через new' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end

  describe 'интеграция с конфигурацией Rails' do
    it 'использует включенные биржи из конфигурации' do
      expect(Rails.application.config).to respond_to(:enabled_exchanges)
    end

    it 'использует настройки бирж из конфигурации' do
      expect(Rails.application.config).to respond_to(:exchange_settings)
    end
  end
end
