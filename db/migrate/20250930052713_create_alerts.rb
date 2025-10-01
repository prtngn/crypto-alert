class CreateAlerts < ActiveRecord::Migration[8.0]
  def change
    execute <<-SQL
      CREATE TYPE alert_direction AS ENUM ('above', 'below');
    SQL

    create_table :alerts do |t|
      t.string :symbol, null: false
      t.decimal :threshold_price, precision: 18, scale: 8, null: false
      t.enum :direction, enum_type: :alert_direction, null: false
      t.boolean :active, default: true, null: false
      t.datetime :triggered_at

      t.timestamps
    end

    add_index :alerts, :symbol
    add_index :alerts, :active
    add_index :alerts, :triggered_at

    reversible do |dir|
      dir.down { execute "DROP TYPE IF EXISTS alert_direction" }
    end
  end
end
