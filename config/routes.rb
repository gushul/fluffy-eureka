Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :users, only: [] do
        resource :account, only: [:show] do
          get :transactions, on: :member
        end

        resources :orders, only: %i[index show create] do
          member do
            patch :complete
            patch :cancel
          end
        end
      end
    end
  end
end
