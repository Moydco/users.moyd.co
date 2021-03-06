class UserMailer < ActionMailer::Base
  default from: Settings.default_from_address

  def token_email(user)
    @user = user
    @token_url  = Settings.my_url + '/users/' + @user.id.to_s + '/validate_token?tk=' + @user.confirm_token

    if Settings.multi_application == 'false'
      @application = Settings.single_application_mode_name
      @url=Settings.single_application_mode_url
    else
      @application = App.find(application_id).name
      @url = App.find(application_id).url
    end

    mail(to: @user.email, subject: 'Please confirm your email')
  end

  def welcome(user)
    @user = user
    @detail_url = edit_user_user_details_url(@user)

    if Settings.multi_application == 'false'
      @application = Settings.single_application_mode_name
      @url=Settings.single_application_mode_url
    else
      @application = App.find(application_id).name
      @url = App.find(application_id).url
    end

    mail(to: @user.email, subject: "Welcome to #{@application}")
  end

  def update_details(user)
    @user = user

    if Settings.multi_application == 'false'
      @application = Settings.single_application_mode_name
      @url=Settings.single_application_mode_url
    else
      @application = App.find(application_id).name
      @url = App.find(application_id).url
    end

    mail(to: @user.email, subject: 'Thank you to update your data')
  end

  def advise_minimum(user)
    @user = user
    @recharge_url = root_url

    if Settings.multi_application == 'false'
      @application = Settings.single_application_mode_name
      @url=Settings.single_application_mode_url
    else
      @application = App.find(application_id).name
      @url = App.find(application_id).url
    end

    mail(to: @user.email, subject: 'Your balance is below minimum')
  end

  def password_lost(user)
    @user = user
    @password_lost_url = get_token_password_lost_sessions_url(password_lost_token: user.password_lost_token)

    if Settings.multi_application == 'false'
      @application = Settings.single_application_mode_name
      @url=Settings.single_application_mode_url
    else
      @application = App.find(application_id).name
      @url = App.find(application_id).url
    end

    mail(to: @user.email, subject: 'Do you lost your password?')
  end

  def send_app_secret(user,app,secret)
    @user = user
    @app = app
    @secret = secret

    mail(to: @user.email, subject: 'Here it is your app auth data')
  end
end
