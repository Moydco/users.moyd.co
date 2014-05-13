class InvoiceUploader < CarrierWave::Uploader::Base
  storage :grid_fs

  def extension_white_list
    %w(jpg pdf png)
  end

end
