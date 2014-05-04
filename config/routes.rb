UsersMoydCo::Application.routes.draw do

  resources :checks, :only => [:index, :create]

  resources :users
  resources :sessions, :only => [:new, :create, :destroy]

  root 'checks#index'

  match '/signup',  to: 'users#new',            via: 'get'
  match '/signin',  to: 'sessions#new',         via: 'get'
  match '/signout', to: 'sessions#destroy',     via: 'delete'

  mount StripeEvent::Engine => '/stripe-callbacks'
end
