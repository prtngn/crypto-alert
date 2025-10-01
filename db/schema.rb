# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_30_070920) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "alert_direction", ["above", "below"]

  create_table "alert_notification_channels", force: :cascade do |t|
    t.bigint "alert_id", null: false
    t.bigint "notification_channel_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_id", "notification_channel_id"], name: "index_alert_notification_channels_unique", unique: true
    t.index ["alert_id"], name: "index_alert_notification_channels_on_alert_id"
    t.index ["notification_channel_id"], name: "index_alert_notification_channels_on_notification_channel_id"
  end

  create_table "alerts", force: :cascade do |t|
    t.string "symbol", null: false
    t.decimal "threshold_price", precision: 18, scale: 8, null: false
    t.enum "direction", null: false, enum_type: "alert_direction"
    t.boolean "active", default: true, null: false
    t.datetime "triggered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_alerts_on_active"
    t.index ["symbol"], name: "index_alerts_on_symbol"
    t.index ["triggered_at"], name: "index_alerts_on_triggered_at"
  end

  create_table "notification_channels", force: :cascade do |t|
    t.string "name", null: false
    t.string "channel_type", null: false
    t.jsonb "config", default: {}, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_notification_channels_on_active"
    t.index ["channel_type"], name: "index_notification_channels_on_channel_type"
  end

  create_table "trading_pairs", force: :cascade do |t|
    t.string "symbol", null: false
    t.string "name"
    t.string "base_asset", null: false
    t.string "quote_asset", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_trading_pairs_on_active"
    t.index ["quote_asset"], name: "index_trading_pairs_on_quote_asset"
    t.index ["symbol"], name: "index_trading_pairs_on_symbol", unique: true
  end

  add_foreign_key "alert_notification_channels", "alerts"
  add_foreign_key "alert_notification_channels", "notification_channels"
end
