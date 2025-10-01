RSpec.configure do |config|
  config.before(:each) do |example|
    # Отключаем callback'и Alert только для тестов сервисов
    if example.metadata[:type] == :service
      Alert.skip_callback(:create, :after, :subscribe_to_websocket)
      Alert.skip_callback(:update, :after, :manage_websocket_subscription)
      Alert.skip_callback(:destroy, :before, :prepare_websocket_unsubscribe)
      Alert.skip_callback(:destroy, :after, :check_websocket_unsubscribe)
    end
  end

  config.after(:each) do |example|
    # Включаем callback'и обратно
    if example.metadata[:type] == :service
      Alert.set_callback(:create, :after, :subscribe_to_websocket)
      Alert.set_callback(:update, :after, :manage_websocket_subscription)
      Alert.set_callback(:destroy, :before, :prepare_websocket_unsubscribe)
      Alert.set_callback(:destroy, :after, :check_websocket_unsubscribe)
    end
  end

  # Очистка Singleton сервисов между тестами
  config.before(:each, type: :service) do
    # Останавливаем и сбрасываем все Singleton сервисы только если они не моки
    begin
      manager = ExchangeManager.instance
      unless manager.is_a?(RSpec::Mocks::InstanceDouble) || manager.is_a?(RSpec::Mocks::Double)
        manager.stop
      end
    rescue
      # Игнорируем ошибки если сервис не запущен
    end

    begin
      binance_service = Exchanges::BinanceService.instance
      unless binance_service.is_a?(RSpec::Mocks::InstanceDouble) || binance_service.is_a?(RSpec::Mocks::Double)
        binance_service.stop
      end
    rescue
      # Игнорируем ошибки если сервис не запущен
    end
  end
end
