# Attributes
# - name: the name of application
# - secret: the salt secret used to encrypt JWT
# - url: the application base URL
# - path: the application path to redirect after a successfully signin
#
# Relations:
# belongs_to User
#
# Application model store all information for an external application (web interface) in case of a multi-application
# environment

class Application
  include Mongoid::Document
  include Mongoid::Timestamps

  before_create :set_secret

  field :name,                        type: String
  field :secret,                      type: String
  field :url,                         type: String
  field :path,                        type: String

  belongs_to :user

  validates :name, :presence => true, :uniqueness => true

  private

  # auto generate a secure secret on creation
  def set_secret
    o = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map { |i| i.to_a }.flatten
    self.api_secret = (0...64).map{ o[rand(o.length)] }.join
  end
end
