class PartnerContact
  include Mongoid::Document

  field :first_name
  field :last_name
  field :company
  field :email
  field :kind
  field :message

  validates_presence_of :first_name, :last_name, :email
end
