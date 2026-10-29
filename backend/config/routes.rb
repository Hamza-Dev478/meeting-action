Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resource :me, only: :show, controller: "me"

      resources :meetings, only: %i[index show create] do
        resources :suggestion_generations, only: :create
      end

      resources :suggestions, only: [] do
        member do
          post :accept
          post :dismiss
        end
      end

      resources :action_items, only: %i[index update]

      # Development-only seeded sign-in. Never drawn in production.
      if Rails.env.local?
        namespace :dev do
          resource :session, only: :create
          resources :users, only: :index
        end
      end
    end
  end
end
