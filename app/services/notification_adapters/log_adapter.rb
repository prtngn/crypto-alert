module NotificationAdapters
  class LogAdapter < BaseAdapter
    def send_notification(alert, current_price)
      message = format_message(alert, current_price)

      log_file = Rails.root.join("log", "alerts.log")
      File.open(log_file, "a") do |f|
        f.puts "\n#{Time.current} - #{message}\n"
      end
    end
  end
end
