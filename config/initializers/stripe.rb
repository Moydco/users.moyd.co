Rails.configuration.stripe = {
    :publishable_key => 'pk_test_jMvILwSZKuWbVUn6Su0ZznaM',
    :secret_key      => 'sk_test_ub2Kg8Da9rD13k7vtR7wC6k9'
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]


StripeEvent.setup do
  all BillingEventLogger.new(Rails.logger)
end