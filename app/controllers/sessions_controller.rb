class SessionsController < ApplicationController
  def new
    if signed_in?
      render text: "Already authenticated with #{@current_user.email}"
    end
  end

  def create

    user = User.find_by(email: params[:session][:email])
    if !user.nil? && user.authenticate(params[:session][:password])
      if Settings.multi_application.downcase == 'false' or (Settings.multi_application.downcase == 'true' and !user.applications.find(application_id).nil)
        sign_in user
        # redirect_to user
        render text: token
      else
        flash.now[:error] = 'Invalid application for this user' # Not quite right!
        render 'new'
        # render status: 404
      end
    else
      flash.now[:error] = 'Invalid email/password combination' # Not quite right!
      render 'new'
      # render status: 404
    end
  end

  def destroy

    sign_out
    redirect_to root_url
  end

end
