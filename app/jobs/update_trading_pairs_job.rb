require "net/http"
require "json"

class UpdateBinanceTradingPairsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "🔄 Обновление списка торговых пар из Binance..."

    exchange_info = fetch_exchange_info
    return unless exchange_info

    symbols_data = exchange_info["symbols"]
    Rails.logger.info "📊 Получено #{symbols_data.count} торговых пар"

    active_symbols = symbols_data.select do |s|
      s["status"] == "TRADING"
    end

    active_symbols.each do |symbol_data|
      pair = TradingPair.find_or_initialize_by(symbol: symbol_data["symbol"])

      pair.assign_attributes(
        base_asset: symbol_data["baseAsset"],
        quote_asset: symbol_data["quoteAsset"],
        active: symbol_data["status"] == "TRADING"
      )
    end

    current_symbols = active_symbols.map { |s| s["symbol"] }
    TradingPair.where.not(symbol: current_symbols).update_all(active: false)

    Rails.logger.info "✅ Обновление завершено."
  end

  private

  def fetch_exchange_info
    url = URI("https://api.binance.com/api/v3/exchangeInfo")
    response = Net::HTTP.get_response(url)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "Ошибка получения exchangeInfo: #{response.code}"
      nil
    end
  rescue => e
    Rails.logger.error "Ошибка запроса к Binance API: #{e.message}"
    nil
  end
end
