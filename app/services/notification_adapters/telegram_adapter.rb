require "net/http"
require "uri"
require "json"

module NotificationAdapters
  class TelegramAdapter < BaseAdapter
    def send_notification(alert, current_price)
      bot_token = channel.config["bot_token"]
      chat_id = channel.config["chat_id"]
      message = format_message(alert, current_price)

      send_telegram_message(bot_token, chat_id, message)
    end

    private

    def send_telegram_message(bot_token, chat_id, text)
      url = URI("https://api.telegram.org/bot#{bot_token}/sendMessage")

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(url.path, { "Content-Type" => "application/json" })
      request.body = {
        chat_id: chat_id,
        text: text,
        parse_mode: "HTML"
      }.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "Telegram API error: #{response.body}"
      end
    end
  end
end
