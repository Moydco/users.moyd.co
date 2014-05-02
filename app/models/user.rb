class User
  include Mongoid::Document

  rolify

  before_save :ensure_authentication_token

  #before_update :moyd_update_free_ddns, :if => Proc.new {|a| a.free_third_level.present? and a.free_ip_address.present?}

  #after_create :moyd_add_free_ddns, :if => Proc.new {|a| a.free_third_level.present? and a.free_ip_address.present?}

  #before_destroy :moyd_delete_free_ddns, :moyd_delete_customer

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable
  # :lockable, :timeoutable and :omniauthable

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  ## Database authenticatable
  field :email,              :type => String, :default => ""
  field :encrypted_password, :type => String, :default => ""
  
  ## Recoverable
  field :reset_password_token,   :type => String
  field :reset_password_sent_at, :type => Time

  ## Rememberable
  field :remember_created_at, :type => Time

  ## Trackable
  field :sign_in_count,      :type => Integer, :default => 0
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at,    :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip,    :type => String

  ## Confirmable
  # field :confirmation_token,   :type => String
  # field :confirmed_at,         :type => Time
  # field :confirmation_sent_at, :type => Time
  # field :unconfirmed_email,    :type => String # Only if using reconfirmable

  ## Lockable
  # field :failed_attempts, :type => Integer, :default => 0 # Only if lock strategy is :failed_attempts
  # field :unlock_token,    :type => String # Only if unlock strategy is :email or :both
  # field :locked_at,       :type => Time

  ## Token authenticatable
  field :authentication_token, :type => String

  ## Extra fields
  field :first_name, :type => String, :default => 'Unknown'
  field :last_name, :type => String, :default => 'Name'
  field :company, :type => String, :default => nil
  field :notes, :type => String, :default => nil
  field :vat, :type => String, :default => nil
  field :stripe_id, :type => String, :default => nil
  field :plan, :type => String, :default => 'FREE'

  attr_accessor :stripe_token

  validates_presence_of :email

  def name
    unless self.first_name.nil?
      self.first_name.to_s + ' ' + self.last_name.to_s
    else
      nil
    end
  end

  def ensure_authentication_token
    if authentication_token.blank?
      self.authentication_token = generate_authentication_token
    end
  end

  private
  def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
  end

end
