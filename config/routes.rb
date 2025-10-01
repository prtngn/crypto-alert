Rails.application.routes.draw do
  root "alerts#index"

  resources :alerts do
    member do
      post :reset
      post :toggle_active
    end
  end

  resources :notification_channels do
    member do
      post :toggle_active
      post :test
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  mount ActionCable.server => "/cable"
end
