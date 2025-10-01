module NotificationAdapters
  class BrowserAdapter < BaseAdapter
    def send_notification(alert, current_price)
      direction_symbol = alert.direction == "up" ? "↑" : "↓"

      ActionCable.server.broadcast("browser_notifications", {
        type: "alert_triggered",
        title: "🚨 Crypto Alert",
        body: "#{alert.symbol} #{direction_symbol} $#{current_price}",
        data: {
          alert_id: alert.id,
          symbol: alert.symbol,
          price: current_price.to_f,
          threshold: alert.threshold_price.to_f,
          direction: alert.direction
        }
      })
    end
  end
end
