class BillingEventLogger
  def initialize(logger = nil)
    @logger = logger || begin
      require 'logger'
      Logger.new($stdout)
    end
  end

  def call(event)
    @logger.info "BILLING-EVENT: #{event.type} #{event.id}"
  end
end