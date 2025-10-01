module NotificationAdapters
  class EmailAdapter < BaseAdapter
    def send_notification(alert, current_price)
      to_email = channel.config["to"]
      subject = "🚨 Crypto Alert: #{alert.symbol} #{alert.direction == 'up' ? '↑' : '↓'}"
      message = format_message(alert, current_price)

      AlertMailer.alert_triggered(to_email, subject, message).deliver_later
    end
  end
end
