module Exchanges
  class BinanceService < BaseExchangeService
    BASE_URL = "wss://stream.binance.com:9443/ws"

    private

    def exchange_name
      "Binance"
    end

    def build_websocket_url(symbol)
      symbol_lower = symbol.downcase
      "#{BASE_URL}/#{symbol_lower}@ticker"
    end

    def handle_message(symbol, data)
      begin
        ticker = JSON.parse(data)
        current_price = BigDecimal(ticker["c"])

        Rails.logger.info "📊 #{exchange_name} Получена цена для #{symbol}: $#{current_price}"

        ActionCable.server.broadcast("prices", {
          symbol: symbol,
          price: current_price.to_f,
          exchange: "binance"
        })

        alert_ids = Rails.cache.read("alerts:symbols:#{symbol}")
        Rails.logger.info "🔍 #{exchange_name} Проверка алертов для #{symbol}: #{alert_ids.inspect}"
        return unless alert_ids&.any?

        alert_ids.each do |alert_id|
          alert_data = Rails.cache.read("alerts:data:#{alert_id}")
          next unless alert_data

          threshold_price = BigDecimal(alert_data[:threshold_price].to_s)

          should_trigger = case alert_data[:direction]
          when "above"
            current_price >= threshold_price
          when "below"
            current_price <= threshold_price
          end

          if should_trigger
            trigger_alert(alert_id, current_price)
          else
            alert_data[:last_price] = current_price
            Rails.cache.write("alerts:data:#{alert_id}", alert_data)

            ActionCable.server.broadcast("alerts", {
              type: "price_update",
              alert_id: alert_id,
              symbol: symbol,
              current_price: current_price.to_f,
              last_price: current_price.to_f,
              exchange: "binance"
            })
          end
        end
      rescue JSON::ParserError => e
        Rails.logger.error "❌ #{exchange_name} Ошибка парсинга JSON для #{symbol}: #{e.message}"
      rescue => e
        Rails.logger.error "❌ #{exchange_name} Ошибка обработки сообщения для #{symbol}: #{e.message}"
      end
    end

    def parse_price_data(data)
      ticker = JSON.parse(data)
      {
        price: BigDecimal(ticker["c"]),
        volume: ticker["v"],
        change_24h: ticker["P"],
        high_24h: ticker["h"],
        low_24h: ticker["l"]
      }
    end
  end
end
