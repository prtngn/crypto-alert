class AlertsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "alerts"
    stream_from "prices"

    send_current_prices
  end

  def unsubscribed = stop_all_streams

  private

  def send_current_prices
    Alert.active.not_triggered.find_each do |alert|
      alert_data = Rails.cache.read("alerts:data:#{alert.id}")
      if alert_data && alert_data[:last_price]
        transmit({
          type: "price_update",
          alert_id: alert.id,
          symbol: alert.symbol,
          current_price: alert_data[:last_price].to_f,
          last_price: alert_data[:last_price].to_f,
          exchange: "cached"
        })
      end
    end
  end
end
