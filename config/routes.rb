Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :documents do
    resource :cards, only: :create, controller: "document_cards"
  end
  resource :search, only: :show
  resources :search_results, only: :index
  resources :questions, only: %i[index show create]
  resource :exam, only: :show
  resources :cards, only: [] do
    resources :attempts, only: :create
  end
  resources :attempts, only: :show

  root "documents#index"
end
