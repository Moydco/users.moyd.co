class SessionsController < ApplicationController

  # Log in form
  def new
    if signed_in?
      render text: "Already authenticated with #{@current_user[:email]}"
    end
  end

  # sign in the user locally
  def create
    # find the user in persistent DB
    user = User.where(email: params[:session][:email].downcase).first
    # check if the password is correct
    if !user.nil? && user.authenticate(params[:session][:password])
      # Sign in user definitively
      sign_in user
      if user.is_admin?
        flash[:success] = "Hello my administrator!"
        redirect_to root_path
      else
        if (Settings.multi_application == 'true' and App.find(application_id).name != Settings.local_app_name) or
            (Settings.multi_application == 'false' and !session[:client_id].nil?)
          redirect_to oauth2_authorize_path and return
        else
          # Redirect to user page if the user have not full invoice data, else redirect to application
          if user.data_complete? and user.confirmed?
            flash[:success] = "Welcome #{user.user_detail.name}"
            redirect_to root_path
          else
            flash[:warning] = "Welcome #{user.user_detail.name}, please complete your data."
            redirect_to edit_user_user_details_path(user)
          end
        end
      end
    else
      # Error: wrong user/pass
      flash.now[:error] = 'Invalid email/password combination'
      render 'new'
    end
  end

  # sign out user and redirect to application home
  def destroy
    sign_out
    flash[:success] = 'See you later...'
    redirect_to root_path
  end

  # password lost: insert the email
  def password_lost

  end

  # password lost: send token via email
  def password_lost_do
    user = User.where(email: params[:user][:email].downcase).first
    if user.nil?
      flash[:error] = 'Sorry, email not found'
    else
      user.create_password_lost_token
      UserMailer.password_lost(user).deliver
      flash[:success] = 'We have found your email and send you the instruction to recover your password. If you don\'t find it in a couple of minutes, please check your spam folder.'
    end
  end

  # password lost: get the token
  def get_token_password_lost

  end

  # password lost: check the token and redirect to update password
  def check_token_password_lost
    user = User.where(password_lost_token: params[:user][:password_lost_token]).first
    if user.nil?
      flash[:error]='Token not found'
      redirect_to password_lost_sessions_url
    else
      if DateTime.now > user.password_lost_expire
        flash[:error]='Token expired'
        redirect_to password_lost_sessions_url
      else
        sign_in user
        flash[:notice] = "Hello #{user.user_detail.name}. Please, change your password"
        redirect_to edit_user_path(user)
      end
    end
  end
end
