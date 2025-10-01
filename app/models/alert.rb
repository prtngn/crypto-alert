class Alert < ApplicationRecord
  has_many :alert_notification_channels, dependent: :destroy
  has_many :notification_channels, through: :alert_notification_channels

  validates :symbol, presence: true
  validates :threshold_price, presence: true, numericality: { greater_than: 0 }
  validates :direction, presence: true, inclusion: { in: %w[above below], message: "%{value} должен быть 'above' или 'below'" }
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }
  scope :triggered, -> { where.not(triggered_at: nil) }
  scope :not_triggered, -> { where(triggered_at: nil) }

  after_create :subscribe_to_websocket
  after_update :manage_websocket_subscription
  before_destroy :prepare_websocket_unsubscribe
  after_destroy :check_websocket_unsubscribe

  def triggered?
    triggered_at.present?
  end

  def check_price(current_price)
    return if triggered? || !active?

    should_trigger = case direction
    when "above"
      current_price >= threshold_price
    when "below"
      current_price <= threshold_price
    end

    if should_trigger
      trigger!(current_price)
    end
  end

  def trigger!(current_price)
    update(triggered_at: Time.current, active: false)
  end

  def reset!
    update(triggered_at: nil, active: true)
  end

  private

  def subscribe_to_websocket
    return unless active? && !triggered?

    manager = ExchangeManager.instance
    manager.add_alert(self)
    manager.subscribe_to_symbol(symbol)
    Rails.logger.info "✅ Алерт ##{id} (#{symbol}) подписан на обновления"
  end

  def manage_websocket_subscription
    manager = ExchangeManager.instance

    # Если алерт стал активным и не сработавшим - добавляем в кеш и подписываемся
    if saved_change_to_active? && active? && !triggered?
      manager.add_alert(self)
      manager.subscribe_to_symbol(symbol)
    # Если алерт обновился, но остался активным - обновляем в кеше
    elsif active? && !triggered? && (saved_change_to_threshold_price? || saved_change_to_direction?)
      manager.update_alert(self)
    # Если алерт деактивирован или сработал - удаляем из кеша
    elsif (saved_change_to_active? && !active?) || saved_change_to_triggered_at?
      manager.remove_alert(id, symbol)
      check_websocket_unsubscribe
    end
  end

  def prepare_websocket_unsubscribe
    @symbol_for_unsubscribe = symbol
  end

  def check_websocket_unsubscribe
    return unless @symbol_for_unsubscribe

    manager = ExchangeManager.instance
    if manager.alerts_count_for_symbol(@symbol_for_unsubscribe) == 0
      manager.unsubscribe_from_symbol(@symbol_for_unsubscribe)
    end
  end
end
