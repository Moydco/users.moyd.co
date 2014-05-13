UsersMoydCo::Application.routes.draw do

  resources :checks, only: [:index, :create]

  resources :users do
    resource :user_details, only: [:edit, :update]
    resources :topups,      only: [:show, :create, :edit, :update]
    resources :vouchers,    only: [:create, :destroy] do
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
