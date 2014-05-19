UsersMoydCo::Application.routes.draw do

  get  'oauth2/authorize'
  post 'oauth2/authorize'
  get  'oauth2/deny_authorize'
  get  'oauth2/allow_authorize'
  post 'oauth2/token',  to: 'oauth2#token_request'
  post 'oauth2/revoke'

  resources :checks, only: [:index, :create]

  resources :users do
    resources :oauth2, only: [:index, :destroy]
    resources :apps do
      member do
        put :update_secret
      end
    end
    resource :user_details, only: [:edit, :update]
    resources :topups,      only: [:show, :create, :edit, :update]
    resources :vouchers,    only: [:index, :create, :destroy] do
      collection do
        post :new_voucher
      end
    end
    resources :consumes,    only: [:create]

    member do
      get :validate_token
      put :validate_token_do
      get :resend_confirm_email
    end
  end

  resources :sessions, only: [:new, :create, :destroy] do
    collection do
      post :sign_with_grant
      get :password_lost
      post :password_lost_do
      get :get_token_password_lost
      post :check_token_password_lost
    end
  end

  root 'checks#index'

  match '/signup',  to: 'users#new',            via: 'get'
  match '/signin',  to: 'sessions#new',         via: 'get'
  match '/signout', to: 'sessions#destroy',     via: 'delete'

  mount StripeEvent::Engine => '/stripe-callbacks'
end
