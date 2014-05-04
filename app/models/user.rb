
class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include ActiveModel::SecurePassword

  before_save { self.email = email.downcase }

  field :email, type: String
  field :password_digest, type: String
  field :last_login_date, :type => DateTime
  field :last_login_ip, type: String

  # attr_accessor :old_password, :password, :password_confirmation

  has_many :applications

  validates :email, :presence => true,
            uniqueness: { case_sensitive: false }

  validates :password, length: { minimum: Settings.minimum_password_length }

  has_secure_password

  def touch_login(ip)
    self.update_attribute(:last_login_date, DateTime.now)
    self.update_attribute(:last_login_ip, ip)

    self
  end

  def store_user_session_in_redis(secret)
    remember_token = JWT.encode(self.to_json,secret)
    $redis_user.set(remember_token,self.id.to_s)
    $redis_user.expire(remember_token, Settings.session_expire)

    remember_token
  end

end
