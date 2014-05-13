class Invoice
  include Mongoid::Document
  include Mongoid::Timestamps

  mount_uploader :doc, InvoiceUploader

  belongs_to :activity
end