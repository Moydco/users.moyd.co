class RenewToken
  include Mongoid::Document
  include Mongoid::Timestamps

  field :expirable_created_at, type: Time

  belongs_to :app
  belongs_to :user

  index({expirable_created_at: 1}, {expire_after_seconds: (Settings.renew_token_expire).to_i.days})

  before_create :set_expire

  def set_expire
    self.expirable_created_at = Time.now unless self.app.name == Settings.local_app_name
    true
  end

  def create_code_token(renew_token)
    o = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map { |i| i.to_a }.flatten
    secret = (0...64).map{ o[rand(o.length)] }.join
    $redis_code.set(secret,renew_token)
    $redis_code.expire(secret, Settings.code_expire)

    secret
  end

end
