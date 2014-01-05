AlwaysResolve20::Application.routes.draw do
  devise_for :users

  resources :semi_static, :only => [:index, :create]
  resources :charges

  get 'how_it_works' => 'semi_static#how_it_works'
  get 'plan' => 'semi_static#plan'
  get 'become_a_partner'  => 'semi_static#become_a_partner'
  post 'check_token' => 'semi_static#check_token'
  put 'update_free_ddns' => 'semi_static#update_free_ddns'
  get 'ddns' => 'semi_static#ddns'
  put 'change_plan' => 'semi_static#change_plan_do'

  root 'semi_static#index'

  mount StripeEvent::Engine => '/stripe-callbacks'
end
