class CreateNotificationChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_channels do |t|
      t.string :name, null: false
      t.string :channel_type, null: false
      t.jsonb :config, default: {}, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :notification_channels, :channel_type
    add_index :notification_channels, :active
  end
end
