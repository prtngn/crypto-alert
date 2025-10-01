class CreateTradingPairs < ActiveRecord::Migration[8.0]
  def change
    create_table :trading_pairs do |t|
      t.string :symbol, null: false
      t.string :name
      t.string :base_asset, null: false
      t.string :quote_asset, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    add_index :trading_pairs, :symbol, unique: true
    add_index :trading_pairs, :active
    add_index :trading_pairs, :quote_asset
  end
end
