# Attributes
# - name: the name of application
# - client_secret: the salt secret used to encrypt JWT
# - url: the application base URL
# - path: the application path to redirect after a successfully signin
# - scope: the list of user permission (Array)
# - state: An arbitrary string of your choosing that will be included in the response to your application.
#          We recommends that you use an anti-forgery state token to prevent CSRF attacks to your users
#
# Relations:
# belongs_to User
#
# Application model store all information for an external application (web interface) in case of a multi-application
# environment

require 'bcrypt'

class App
  include Mongoid::Document
  include Mongoid::Timestamps
  include BCrypt


  field :name,                        type: String
  field :client_secret,               type: String
  field :url,                         type: String
  field :path,                        type: String
  field :enable_code,                 type: Boolean, default: true
  field :enable_implicit,             type: Boolean, default: false
  field :enable_password,             type: Boolean, default: false
  field :auto_renew,                  type: Boolean, default: false

  attr_accessor :state

  has_many :renew_tokens

  validates :url,  :presence => true, :uniqueness => true
  validates :path, :presence => true

  def users
    User.in(id: renew_tokens.map(&:user_id))
  end

  def client_id
    self.id.to_s
  end

  def redirect_uri
    self.url + self.path
  end

  # auto generate a secure secret and store encrypted
  def update_secret
    o = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map { |i| i.to_a }.flatten
    secret = (0...64).map{ o[rand(o.length)] }.join
    self.client_secret = Password.create(secret)
    self.save

    secret
  end

  def password_correct?(password)
    Password.new(self.client_secret) == password
  end

end
