module NotificationAdapters
  class BaseAdapter
    attr_reader :channel

    def initialize(channel)
      @channel = channel
    end

    def send_notification(alert, current_price)
      raise NotImplementedError, "Подклассы должны реализовать метод send_notification"
    end

    protected

    def format_message(alert, current_price)
      direction_text = alert.direction == "up" ? "выше" : "ниже"

      "🚨 АЛЕРТ СРАБОТАЛ!\n\n" \
      "Символ: #{alert.symbol}\n" \
      "Направление: #{direction_text}\n" \
      "Пороговая цена: #{alert.threshold_price}\n" \
      "Текущая цена: #{current_price}\n" \
      "Время срабатывания: #{alert.triggered_at.strftime('%Y-%m-%d %H:%M:%S')}"
    end
  end
end
