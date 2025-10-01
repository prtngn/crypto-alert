class NotificationChannel < ApplicationRecord
  has_many :alert_notification_channels, dependent: :destroy
  has_many :alerts, through: :alert_notification_channels

  validates :name, presence: true
  validates :channel_type, presence: true, inclusion: {
    in: %w[log email telegram browser],
    message: "%{value} должен быть 'log', 'email', 'telegram' или 'browser'"
  }
  validates :active, inclusion: { in: [ true, false ] }
  validate :validate_config

  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(channel_type: type) }

  private

  def validate_config
    return if config.blank?

    case channel_type
    when "email"
      errors.add(:config, "должен содержать 'to'") unless config["to"].present?
    when "telegram"
      errors.add(:config, "должен содержать 'chat_id'") unless config["chat_id"].present?
      errors.add(:config, "должен содержать 'bot_token'") unless config["bot_token"].present?
    end
  end
end
