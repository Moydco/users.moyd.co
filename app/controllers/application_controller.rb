class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  # This is our new function that comes before Devise's one
  before_filter :authenticate_user_from_token!

  # This is Devise's authentication
  before_filter :authenticate_user!, :if => :protected_controller?
  before_filter :set_user_api_token, :if => :protected_controller?

  before_action :configure_devise_permitted_parameters, :if => :devise_controller?

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, :alert => exception.message
  end

  protected

  def configure_devise_permitted_parameters
    registration_params = [:email, :password, :password_confirmation, :first_name, :last_name, :company, :vat, :notes]

    if params[:action] == 'update'
      devise_parameter_sanitizer.for(:account_update) {
          |u| u.permit(registration_params << :current_password)
      }
    elsif params[:action] == 'create'
      devise_parameter_sanitizer.for(:sign_up) {
          |u| u.permit(registration_params)
      }
    end
  end

  def authenticate_user_from_token!
    user_token = params[:user_token].presence
    user = user_token && User.where(authentication_token: user_token.to_s).first

    # Notice how we use Devise.secure_compare to compare the token
    # in the database with the token given in the params, mitigating
    # timing attacks.
    if user && Devise.secure_compare(user.authentication_token, params[:user_token])
      puts "RequestStore Token: #{RequestStore.store[:api_token]}"
      sign_in user, store: false
    end
  end

  def protected_controller?
    controller_name == 'charges'
  end

  def set_user_api_token
    if user_signed_in?
      puts "Dentro a set_user_api_token: #{current_user}"
      RequestStore.store[:api_token] = current_user.authentication_token
    end
  end
end
