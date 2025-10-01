Rails.application.configure do
  enabled_exchanges = ENV.fetch("ENABLED_EXCHANGES", "binance").split(",").map(&:strip)

  exchange_settings = {
    binance: {
      class: "Exchanges::BinanceService",
      name: "Binance",
      enabled: true
    }
  }

  config.enabled_exchanges = enabled_exchanges
  config.exchange_settings = exchange_settings
end

Rails.application.config.after_initialize do
  unless Rails.env.test?
    EventManager.instance.start
    ExchangeManager.instance.start
  end
end

at_exit do
  unless Rails.env.test?
    ExchangeManager.instance.stop
    EventManager.instance.stop
  end
end
