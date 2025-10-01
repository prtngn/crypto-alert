class CreateAlertNotificationChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :alert_notification_channels do |t|
      t.references :alert, null: false, foreign_key: true
      t.references :notification_channel, null: false, foreign_key: true

      t.timestamps
    end

    add_index :alert_notification_channels, [ :alert_id, :notification_channel_id ],
              unique: true,
              name: 'index_alert_notification_channels_unique'
  end
end
