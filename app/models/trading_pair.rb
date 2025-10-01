class TradingPair < ApplicationRecord
  validates :symbol, presence: true, uniqueness: true
  validates :base_asset, presence: true
  validates :quote_asset, presence: true
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }
  scope :usdt_pairs, -> { where(quote_asset: "USDT") }
  scope :by_popularity, -> { order(:symbol) }

  def display_name = name.presence || "#{base_asset}/#{quote_asset}"
end
