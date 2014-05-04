# Attributes
# - name: the name of application
# - secret: the salt secret used to encrypt JWT

class Application
  include Mongoid::Document
  include Mongoid::Timestamps

  before_create :set_secret

  field :name, :type => String
  field :secret, :type => String

  belongs_to :user

  validates :name, :presence => true, :uniqueness => true

  private

  def set_secret
    o = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map { |i| i.to_a }.flatten
    self.api_secret = (0...64).map{ o[rand(o.length)] }.join
  end
end
