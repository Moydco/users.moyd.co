UsersMoydCo::Application.routes.draw do
  devise_for :users

  resources :users
  resources :semi_static, :only => [:index, :check_token]
  resources :charges

  post 'check_token' => 'semi_static#check_token'

  root 'semi_static#index'

  mount StripeEvent::Engine => '/stripe-callbacks'
end
