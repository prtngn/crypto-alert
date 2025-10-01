FactoryBot.define do
  factory :alert do
    symbol { "BTCUSDT" }
    threshold_price { 50000.0 }
    direction { "above" }
    active { true }
    triggered_at { nil }

    trait :below do
      direction { "below" }
    end

    trait :triggered do
      triggered_at { Time.current }
      active { false }
    end

    trait :inactive do
      active { false }
    end

    trait :with_notification_channels do
      after(:create) do |alert|
        create_list(:notification_channel, 2, alerts: [ alert ])
      end
    end
  end
end
