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

        Rails.logger.debug "📊 #{exchange_name} Получена цена для #{symbol}: $#{current_price}"

        alert_ids = Rails.cache.read("alerts:symbols:#{symbol}")
        Rails.logger.debug "🔍 #{exchange_name} Проверка алертов для #{symbol}: #{alert_ids.inspect}"
        return unless alert_ids&.any?

        alert_ids.each do |alert_id|
          alert_data = Rails.cache.read("alerts:data:#{alert_id}")
          next unless alert_data

          should_trigger = check_threshold_crossing(
            current_price,
            alert_data[:last_price],
            alert_data[:threshold_price],
            alert_data[:direction]
          )

          if should_trigger
            trigger_alert(alert_id, current_price)
          else
            ActionCable.server.broadcast("alerts", {
              type: "price_update",
              alert_id: alert_id,
              symbol: symbol,
              current_price: current_price.to_f,
              last_price: current_price.to_f,
              exchange: "binance"
            })
          end

          alert_data[:last_price] = current_price
          Rails.cache.write("alerts:data:#{alert_id}", alert_data)
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

    def check_threshold_crossing(current_price, last_price, threshold_price, direction)
      return false if last_price.nil?

      case direction
      when "above"
        last_price < threshold_price && current_price >= threshold_price
      when "below"
        last_price > threshold_price && current_price <= threshold_price
      end
    end
  end
end
