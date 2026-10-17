Rails.application.routes.draw do
  root "analysis#index"

  get "signup", to: "registrations#new"
  post "signup", to: "registrations#create"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  get "demo", to: "demo#enter"
  delete "logout", to: "sessions#destroy"

  resources :trackman_sessions, only: %i[index create show destroy]
  get "progress", to: "analysis#index"

  get "account", to: "account#show"
  patch "account", to: "account#update"
  post "account/regenerate_api_key", to: "account#regenerate_api_key"
  post "account/regenerate_game_token", to: "account#regenerate_game_token"

  namespace :api do
    namespace :v1 do
      get "/", to: "root#index"
      get "me", to: "me#show"
      resources :sessions, controller: "trackman_sessions", only: %i[index show create destroy]
      get "summary", to: "summary#index"
      get "progress", to: "progress#index"
      get "shots", to: "shots#index"

      # Read-only club stats for the game (game token or api key; CORS-open)
      get "clubs", to: "clubs#index"
      get "clubs/:club", to: "clubs#show", as: :club
      match "clubs", to: "clubs#preflight", via: :options
      match "clubs/:club", to: "clubs#preflight", via: :options
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
