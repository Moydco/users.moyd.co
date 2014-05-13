UsersMoydCo::Application.routes.draw do

  resources :checks, only: [:index, :create]

  resources :users do
    resource :user_details, only: [:edit, :update]
    resources :topups,      only: [:show, :create, :edit, :update]
    resources :vouchers,    only: [:create]
    resources :consumes,    only: [:create]

    member do
      get :validate_token
      put :validate_token_do
      get :resend_confirm_email
    end
  end

  resources :sessions, only: [:new, :create, :destroy]

  root 'checks#index'

  match '/signup',  to: 'users#new',            via: 'get'
  match '/signin',  to: 'sessions#new',         via: 'get'
  match '/signout', to: 'sessions#destroy',     via: 'delete'

  mount StripeEvent::Engine => '/stripe-callbacks'
end
