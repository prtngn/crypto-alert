class BrowserNotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "browser_notifications"
  end

  def unsubscribed
    stop_all_streams
  end
end
