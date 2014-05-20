class Subscription
  include Mongoid::Document
  include Mongoid::Timestamps
  include HTTParty
  include IceCube

  field :description,     type: String
  field :amount,          type: Integer, default: 0
  field :every_value,     type: Integer, default: 1
  field :every_type,      type: String,  default: 'month'
  field :first_drain,     type: Date,    default: Date.today
  field :callback_url,            type: String
  field :callback_deletion_path,  type: String
  field :callback_error_path,     type: String
  field :callback_method,         type: String,  default: 'get'
  field :to_be_retried,           type: Boolean, default: false

  belongs_to :user

  validates_inclusion_of :every_type,      in: %w( day month year )
  validates_inclusion_of :callback_method, in: %w( get post )

  after_destroy :notify_deletion

  def notify_deletion
    if self.callback_method.downcase == 'post'
      self.class.post(self.callback_url + self.callback_deletion_path, body: {id: self.id.to_s})
    else
      self.class.get(self.callback_url + self.callback_deletion_path, body: {id: self.id.to_s})
    end
  end

  def next_payment
    s = Schedule.new(self.first_drain) do |s|
      if self.every_type == 'day'
        s.add_recurrence_rule Rule.daily(self.every_value)
      elsif self.every_type == 'month'
        s.add_recurrence_rule Rule.monthly(self.every_value)
      elsif self.every_type == 'year'
        s.add_recurrence_rule Rule.yearly(self.every_value)
      end
    end

    s.next_occurrence
  end

  def last_payment
    s = Schedule.new(self.first_drain) do |s|
      if self.every_type == 'day'
        s.add_recurrence_rule Rule.daily(self.every_value)
      elsif self.every_type == 'month'
        s.add_recurrence_rule Rule.monthly(self.every_value)
      elsif self.every_type == 'year'
        s.add_recurrence_rule Rule.yearly(self.every_value)
      end
    end

    s.last_occurrence(Date.today)
  end

  def drain_on_next_days
    if self.next_payment == Date.today + Settings.days_before_to_advise.to_i.days
      SubscriptionMailer.renew_in_next_days(self).deliver
    end
  end

  def drain
    if self.next_payment == Date.today
      if self.user.balance > self.amount
        activity = self.user.activities.create(kind: 'consume', amount: self.amount)
        c = Consume.create(description: params[:description])
        activity.consume = c
        activity.save
        SubscriptionMailer.subscription_renewed(self).deliver
      else
        self.to_be_retried = true
        self.save
        SubscriptionMailer.subscription_error_will_retry(self).deliver
      end
    elsif  self.to_be_retried == true and ((self.last_payment + Settings.grey_days.to_i.days) == Date.today)
      if self.user.balance > self.amount
        activity = self.user.activities.create(kind: 'consume', amount: self.amount)
        c = Consume.create(description: params[:description])
        activity.consume = c
        activity.save
        SubscriptionMailer.subscription_renewed(self).deliver
      else
        if self.callback_method.downcase == 'post'
          self.class.post(self.callback_url + self.callback_error_path, body: {id: self.id.to_s})
        else
          self.class.get(self.callback_url + self.callback_error_path, body: {id: self.id.to_s})
        end
        SubscriptionMailer.subscription_error_will_not_retry(self).deliver
      end
    end

  end
end
