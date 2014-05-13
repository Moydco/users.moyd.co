class Voucher
  include Mongoid::Document
  include Mongoid::Timestamps

  field :expire, type: DateTime, default: nil
  field :amount, type: Integer, default: 1


  attr_accessor :voucher_code

  belongs_to :activity

  def activated?
    !self.activity.nil?
  end

  def expired?
    !(self.expire.nil? || Date.today < self.expire)
  end
end