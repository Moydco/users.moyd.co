class Consume
  include Mongoid::Document
  include Mongoid::Timestamps

  field :description, type: String, default: 'Use of our services'

  belongs_to :activity
end