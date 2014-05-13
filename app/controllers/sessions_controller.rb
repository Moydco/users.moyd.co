class SessionsController < ApplicationController

  # Log in form
  def new
    if signed_in?
      render text: "Already authenticated with #{@current_user[:email]}"
    end
  end

  # sign in the user
  def create
    # find the user in persistend DB
    user = User.where(email: params[:session][:email]).first
    # check if the password is correct
    if !user.nil? && user.authenticate(params[:session][:password])
      # check the authority to log in tho this application
      if Settings.multi_application.downcase == 'false' or
          (Settings.multi_application.downcase == 'true' and !user.applications.find(application_id).nil?) or
          (Settings.multi_application.downcase == 'true' and user.applications.find(application_id).nil? and Settings.multi_application_login.downcase == 'true')
        # Sign in user definitively
        sign_in user
        if user.is_admin?
          redirect_to root_path
        else
          # Redirect to user page if the user have not full invoice data, else redirect to application
          if user.data_complete? and user.confirmed?
            if Settings.multi_application.downcase == 'false'
              redirect_to Settings.single_application_mode_url + Settings.single_application_mode_path
            else
              redirect_to application.url + application.path
            end
          else
            redirect_to edit_user_user_details_path(user)
          end
        end
      else
        # Error: application isn't correct
        flash.now[:error] = 'Invalid application for this user'
        render 'new'
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
    if Settings.multi_application.downcase == 'false'
      redirect_to Settings.single_application_mode_url
    else
      redirect_to application.url
    end
  end

end
