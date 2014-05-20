class AppsController < ApplicationController
  before_action :signed_in_user

  def index
    if current_user.is_admin?
      @apps = App.all
      @app = App.new
    else
      redirect_to root_path
    end
  end

  def create
    if current_user.is_admin?
      app = App.new(app_params)
      if app.save
        secret = app.update_secret
        UserMailer.send_app_secret(current_user,app,secret).deliver
        flash[:success]="Your app was successfully added to OAuth2 system with client_id #{app.id.to_s}. We send you an email with client_secret: please, maintain this information reserved and use only on server application, not where this information can be readed by the user (ex. no javascript)"
        redirect_to user_apps_path
      else
        flash[:error]= 'There was some errors in App creation'
        redirect_to user_apps_path
      end
    else
      redirect_to root_path
    end
  end

  def edit
    if current_user.is_admin?
      @app = App.find[param[:id]]
    else
      redirect_to root_path
    end
  end

  def update
    if current_user.is_admin?
      app = App.find(params[:id])
      if app.update_attributes(app_params)
        flash[:success]="Your app was successfully updated"
        redirect_to user_apps_path
      else
        flash.now[:error]= 'There are some errors in App update'
        render :edit
      end
    else
      redirect_to root_path
    end
  end

  def destroy
    if current_user.is_admin?
      app = App.find(params[:id])
      if app.destroy
        flash[:success]='Your app was successfully destroyed'
      else
        flash[:error]= 'There are some errors in App update'
      end
      redirect_to user_apps_path
    else
      redirect_to root_path
    end
  end

  def update_secret
    if current_user.is_admin?
      app = App.find(params[:id])
      secret = app.update_secret
      UserMailer.send_app_secret(current_user,app,secret).deliver

      if secret
        flash[:success]='Your new client_secret was sent via email. Please, maintain this information reserved and use only on server application, not where this information can be readed by the user (ex. no javascript)'
        redirect_to user_apps_path
      else
        flash[:error]= 'There are some errors in App update'
        redirect_to user_apps_path
      end
    else
      redirect_to root_path
    end
  end
  private

  def app_params
    params.require(:app).permit(:name, :url, :path, :enable_code, :enable_implicit, :enable_password, :auto_renew )
  end
end
