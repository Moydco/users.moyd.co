class UserMailer < ActionMailer::Base
  default from: Settings.default_from_address

  def token_email(user)
    @user = user
    @token_url  = Settings.my_url + '/users/' + @user.id.to_s + '/validate_token?tk=' + @user.confirm_token

    if Settings.multi_application == 'false'
      @application = Settings.single_application_mode_name
      @url=Settings.single_application_mode_url
    else
      @application = Application.find(application_id).name
      @url = Application.find(application_id).url
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
      @application = Application.find(application_id).name
      @url = Application.find(application_id).url
    end

    mail(to: @user.email, subject: "Welcome to #{@application}")
  end

  def update_details(user)
    @user = user

    if Settings.multi_application == 'false'
      @application = Settings.single_application_mode_name
      @url=Settings.single_application_mode_url
    else
      @application = Application.find(application_id).name
      @url = Application.find(application_id).url
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
      @application = Application.find(application_id).name
      @url = Application.find(application_id).url
    end

    mail(to: @user.email, subject: 'Your balance is below minimum')
  end
end
