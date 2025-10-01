require "singleton"

class ExchangeManager
  include Singleton

  def initialize
    @services = {}
    @enabled_exchanges = Rails.application.config.enabled_exchanges
  end

  def start
    @enabled_exchanges.each do |exchange_name|
      exchange_settings = Rails.application.config.exchange_settings[exchange_name.to_sym]
      service_class = exchange_settings[:class].constantize
      @services[exchange_name] = service_class.instance
      @services[exchange_name].start
    end
  end

  def stop
    @services.each { |name, service| service.stop }
    @services.clear
  end

  def add_alert(alert)
    @services.each { |name, service| service.add_alert(alert) }
  end

  def remove_alert(alert_id, symbol)
    @services.each { |name, service| service.remove_alert(alert_id, symbol) }
  end

  def update_alert(alert)
    @services.each { |name, service| service.update_alert(alert) }
  end

  def subscribe_to_symbol(symbol)
    @services.each { |name, service| service.subscribe_to_symbol(symbol) }
  end

  def unsubscribe_from_symbol(symbol)
    @services.each { |name, service| service.unsubscribe_from_symbol(symbol) }
  end

  def status
    {
      enabled_exchanges: @enabled_exchanges,
      running_services: @services.select { |name, service| service.running? }.keys,
      total_services: @services.count
    }
  end

  def get_service(exchange_name)
    @services[exchange_name]
  end

  def running?
    @services.any? { |name, service| service.running? }
  end
end
