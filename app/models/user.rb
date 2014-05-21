# Attributes:
# - email: the user email
# - password_digest: user password encrypted with bcrypt
# - last_login_date: the timestamp of last login
# - admin: boolean, if the user is an admin
# - last_login_ip: the IP address of user's client used in last login
# Last two field is useful to have a unique token every time
# - password, password_confirmation: volatile attributes for singup and edit_user views
# - admin: boolean, if the user is a local admin
# - balance: user balance in pence (UKP x 100)
# - stripe_id: user id on Stripe
# - paypal_id: user id on Paypal
# - confirmed: boolean, if the user email was confirmed
# - confirm_token: email confirmation token
# - password_lost_token: the token to reset password
# - password_lost_token_expire: the token to reset password expiration
# - refresh_token: the token to request a new volatile token
# - refresh_token_expire: the expiration date of refresh token
#
# Relations:
# embeds_one UserDetail: all other information useful for invoicing services.
# embeds_many UserSocial: the link to social networks to provide a faster authentication (TODO)
# has_many App: the Application authorized by the user
#
# This class contains basic user data for authentication



class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include ActiveModel::SecurePassword

  before_create :create_confirm_token
  after_create  :add_local_app
  before_save   { self.email = email.downcase }

  field :email,                 type: String
  field :password_digest,       type: String
  field :last_login_date,       type: DateTime
  field :last_login_ip,         type: String
  field :admin,                 type: Boolean, default: false
  field :balance,               type: Integer, default: 0
  field :stripe_id,             type: String,  default: nil
  field :paypal_id,             type: String,  default: nil
  field :confirmed,             type: Boolean, default: false
  field :confirm_token,         type: String
  field :password_lost_token,   type: String
  field :password_lost_expire,  type: DateTime
  field :refresh_token,         type: String
  field :refresh_token_expire,  type: DateTime

  attr_accessor :stripe_token, :tk

  has_many :renew_tokens
  has_many :activities
  has_many :subscriptions

  embeds_one :user_detail

  validates :email, :presence => true,
            uniqueness: { case_sensitive: false }

  validates :password, length: { minimum: Settings.minimum_password_length }, :allow_nil => true

  validates_associated :user_detail #, on: :update

  accepts_nested_attributes_for :user_detail

  # All methods for password verification are in this helper
  has_secure_password

  # Emulate has_many :trough
  def apps
    App.in(id: renew_tokens.map(&:app_id))
  end

  # update :last_login_date and :last_login_ip
  def touch_login(ip)
    self.update_attribute(:last_login_date, DateTime.now)
    self.update_attribute(:last_login_ip, ip)
    self.save
    self
  end

  # Generate the access_token in JWT format
  def generate_token(secret)
    JWT.encode(self.to_json,secret)
  end

  # store the access_token in a separate Redis Database
  def store_user_session_in_redis(secret, auto_renew)
    remember_token = generate_token(secret)
    $redis_user.set(remember_token,[self.id.to_s,auto_renew].to_json)
    $redis_user.expire(remember_token, Settings.token_expire)

    remember_token
  end

  # check if the user
  def is_admin?
    self.admin
  end

  # check if extra user data is complete
  def data_complete?
    if user_detail.nil?
      self.build_user_detail
      self.save
      false
    else
      if user_detail.name.blank? or user_detail.address1.blank? or user_detail.zip.blank? or user_detail.city.blank? or user_detail.state.blank? or user_detail.country.blank?
        false
      else
        true
      end
    end
  end

  # check if the user has confirmed his email
  def confirmed?
    self.confirmed
  end

  def create_password_lost_token
    o = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map { |i| i.to_a }.flatten
    self.password_lost_token = (0...64).map{ o[rand(o.length)] }.join
    self.password_lost_expire = DateTime.now + 2.hours
    self.save
  end

  def set_refresh_tokens
    o = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map { |i| i.to_a }.flatten
    self.refresh_token = (0...64).map{ o[rand(o.length)] }.join
    self.refresh_token_expire = DateTime.now + (Settings.renew_token_expire).to_i.days
    self.save
    self
  end

  def delete_refresh_token
    self.refresh_token = nil
    self.refresh_token_expire = DateTime.now
    self.save
  end

  private

  def create_confirm_token
    o = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map { |i| i.to_a }.flatten
    self.confirm_token = (0...64).map{ o[rand(o.length)] }.join
  end

  def add_local_app
    if Settings.multi_application == 'false'
      RenewToken.create(user: self, app: nil)
    else
      RenewToken.create(user: self, app: App.where(name: Settings.local_app_name).first)
    end
  end
end
