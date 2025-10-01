require "singleton"

module Exchanges
  class BaseExchangeService
    include Singleton

    def initialize
      @connections = {}
      @subscribed_symbols = Set.new
      @running = false
    end

  def start
    @running = true
    Rails.logger.info "🚀 Запуск #{exchange_name} WebSocket сервиса ..."
    subscribe_to_active_alerts
  end

    def stop
      @running = false
      @connections.each { |symbol, ws| ws.close if ws }
      @connections.clear
      @subscribed_symbols.clear
      Rails.cache.delete_matched("alerts:*")
      Rails.logger.info "🛑 #{exchange_name} WebSocket сервис остановлен"
    end

    def add_alert(alert)
      symbol_key = "alerts:symbols:#{alert.symbol}"
      alert_ids = Rails.cache.read(symbol_key) || []

      if alert_ids.include?(alert.id)
        Rails.logger.debug "🔄 Алерт ##{alert.id} (#{alert.symbol}) уже в кеше #{exchange_name}"
        return
      end

      alert_ids << alert.id
      Rails.cache.write(symbol_key, alert_ids)

      data_key = "alerts:data:#{alert.id}"
      Rails.cache.write(data_key, {
        symbol: alert.symbol,
        threshold_price: alert.threshold_price,
        direction: alert.direction,
        notification_channel_ids: alert.notification_channel_ids,
        last_price: nil
      })

      Rails.logger.info "📥 Алерт ##{alert.id} (#{alert.symbol}) добавлен в кеш #{exchange_name}"
    end

    def remove_alert(alert_id, symbol)
      symbol_key = "alerts:symbols:#{symbol}"
      alert_ids = Rails.cache.read(symbol_key) || []
      alert_ids.delete(alert_id)

      if alert_ids.empty?
        Rails.cache.delete(symbol_key)
        unsubscribe_from_symbol(symbol)
      else
        Rails.cache.write(symbol_key, alert_ids)
      end

      Rails.cache.delete("alerts:data:#{alert_id}")
      Rails.logger.info "📤 Алерт ##{alert_id} (#{symbol}) удален из кеша #{exchange_name}"
    end

    def update_alert(alert)
      data_key = "alerts:data:#{alert.id}"
      Rails.cache.write(data_key, {
        symbol: alert.symbol,
        threshold_price: alert.threshold_price,
        direction: alert.direction,
        notification_channel_ids: alert.notification_channel_ids,
        last_price: nil
      })
      Rails.logger.info "🔄 Алерт ##{alert.id} (#{alert.symbol}) обновлен в кеше #{exchange_name}"
    end

    def alerts_count_for_symbol(symbol)
      symbol_key = "alerts:symbols:#{symbol}"
      alert_ids = Rails.cache.read(symbol_key) || []
      alert_ids.count
    end

    def subscribe_to_symbol(symbol)
      return if @subscribed_symbols.include?(symbol)

      begin
        ws_url = build_websocket_url(symbol)
        Rails.logger.info "🌐 #{exchange_name} Подключение к WebSocket для #{symbol}: #{ws_url}"

        ws = Faye::WebSocket::Client.new(ws_url)

        ws.on :open do |event|
          Rails.logger.info "🔗 #{exchange_name} WebSocket подключен для #{symbol}"
          @subscribed_symbols.add(symbol)
        end

        ws.on :message do |event|
          Rails.logger.debug "📨 #{exchange_name} Получено сообщение для #{symbol}: #{event.data[0..100]}..."
          handle_message(symbol, event.data)
        end

        ws.on :close do |event|
          Rails.logger.warn "❌ #{exchange_name} WebSocket отключен для #{symbol}: #{event.code} #{event.reason}"
          @subscribed_symbols.delete(symbol)
          @connections.delete(symbol)
        end

        ws.on :error do |event|
          Rails.logger.error "❌ #{exchange_name} WebSocket ошибка для #{symbol}: #{event.message}"
        end

        @connections[symbol] = ws
        @subscribed_symbols.add(symbol)
        Rails.logger.info "✅ #{exchange_name} WebSocket клиент создан для #{symbol}"
      rescue => e
        Rails.logger.error "❌ Ошибка подключения к #{exchange_name} для #{symbol}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    def unsubscribe_from_symbol(symbol)
      ws = @connections[symbol]
      if ws
        ws.close
        @connections.delete(symbol)
        @subscribed_symbols.delete(symbol)
        Rails.logger.info "🔌 #{exchange_name} отписан от #{symbol}"
      end
    end

    def running?
      @running
    end

    def subscribed_symbols
      @subscribed_symbols.to_a
    end

    private

    def exchange_name
      raise NotImplementedError, "Должен быть реализован в наследнике"
    end

    def build_websocket_url(symbol)
      raise NotImplementedError, "Должен быть реализован в наследнике"
    end

    def handle_message(symbol, data)
      raise NotImplementedError, "Должен быть реализован в наследнике"
    end

    def parse_price_data(data)
      raise NotImplementedError, "Должен быть реализован в наследнике"
    end

    def subscribe_to_active_alerts
      alerts = Alert.active.not_triggered.includes(:notification_channels).to_a
      return unless alerts.any?

      alerts.each { |alert| add_alert(alert) }
      symbols = alerts.map(&:symbol).uniq
      Rails.logger.info "📊 #{exchange_name}: Загружено #{alerts.count} алертов для #{symbols.count} символов: #{symbols.join(', ')}"
      symbols.each { |symbol| subscribe_to_symbol(symbol) }
    end

    def trigger_alert(alert_id, current_price)
      Alert.transaction do
        alert = Alert.find_by(id: alert_id)
        return unless alert && alert.active? && !alert.triggered?

        alert.update!(
          triggered_at: Time.current,
          active: false
        )

        remove_alert(alert_id, alert.symbol)

        ActionCable.server.broadcast("alerts", {
          type: "triggered",
          alert_id: alert_id,
          symbol: alert.symbol,
          current_price: current_price.to_f,
          triggered_at: alert.triggered_at.iso8601
        })

        Rails.logger.info "🔔 #{exchange_name} Алерт ##{alert_id} (#{alert.symbol}) сработал при цене $#{current_price}"
      end
    rescue => e
      Rails.logger.error "❌ #{exchange_name} Ошибка срабатывания алерта ##{alert_id}: #{e.message}"
    end
  end
end
