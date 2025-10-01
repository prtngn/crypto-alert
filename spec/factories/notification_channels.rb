FactoryBot.define do
  factory :notification_channel do
    sequence(:name) { |n| "Канал уведомлений #{n}" }
    channel_type { "log" }
    active { true }
    config { {} }

    trait :email do
      channel_type { "email" }
      config { { "to" => "test@example.com" } }
    end

    trait :telegram do
      channel_type { "telegram" }
      config { { "chat_id" => "123456", "bot_token" => "test_token" } }
    end

    trait :browser do
      channel_type { "browser" }
    end

    trait :inactive do
      active { false }
    end
  end
end
