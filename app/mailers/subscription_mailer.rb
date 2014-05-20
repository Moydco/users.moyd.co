class SubscriptionMailer < ActionMailer::Base
  default from: Settings.default_from_address

  def renew_in_next_days(subscription)
    @user = subscription.user
    @subscription = subscription
    @recharge_url = root_url
    if Settings.multi_application == 'false'
      @url=Settings.single_application_mode_url
    else
      @url = App.find(application_id).url
    end
    mail(to: @user.email, subject: 'Your subscription will be renewed in next days')
  end

  def subscription_renewed(subscription)
    @user = subscription.user
    @subscription = subscription
    if Settings.multi_application == 'false'
      @url=Settings.single_application_mode_url
    else
      @url = App.find(application_id).url
    end

    mail(to: @user.email, subject: 'Your subscription was renewed')
  end

  def subscription_error_will_retry(subscription)
    @user = subscription.user
    @subscription = subscription
    @recharge_url = root_url
    if Settings.multi_application == 'false'
      @url=Settings.single_application_mode_url
    else
      @url = App.find(application_id).url
    end

    mail(to: @user.email, subject: 'There is a problem in subscription renewal: I\'ll retry in next days')
  end

  def subscription_error_will_not_retry(subscription)
    @user = subscription.user
    @subscription = subscription
    @recharge_url = root_url
    if Settings.multi_application == 'false'
      @url=Settings.single_application_mode_url
    else
      @url = App.find(application_id).url
    end

    mail(to: @user.email, subject: 'Your subscription was disabled')
  end
end
