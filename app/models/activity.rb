class Activity
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user

  field :kind, type: String, default: 'topup'
  field :amount, type: Integer

  has_one :voucher
  has_one :consume
  has_one :invoice

  after_create :update_balance

  def update_balance
    puts self
    if kind == 'topup'
      self.user.update_attribute(:balance, self.user.balance + self.amount)
    elsif kind == 'voucher'
      self.user.update_attribute(:balance, self.user.balance + self.amount)
    elsif kind == 'consume'
      self.user.update_attribute(:balance, self.user.balance - self.amount)
      if self.user.balance < self.user.user_detail.minimum
        UserMailer.advise_minimum(self.user).deliver
      end
    end
  end
end