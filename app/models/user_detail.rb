class UserDetail
  include Mongoid::Document

  field :name,     type: String, default: ''
  field :address1, type: String, default: ''
  field :address2, type: String, default: ''
  field :zip,      type: String, default: ''
  field :city,     type: String, default: ''
  field :state,    type: String, default: ''
  field :country,  type: String, default: ''
  field :phone,    type: String, default: ''
  field :vat_id,   type: String, default: ''
  field :minimum,  type: Integer, default: 500

  attr_accessor :advise_me_at

  embedded_in :user

  after_validation :set_minimum

  def set_minimum
    puts "Inside set minimum: #{self.advise_me_at}"
    self.minimum = self.advise_me_at.to_i * 100
  end

  validates_presence_of :name, :address1, :zip, :city, :state, :country, on: :update
end