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
end
