if Settings.enable_billing.downcase == 'true' and Settings.enable_stripe.downcase == 'true'
  Stripe.api_key    = Settings.stripe_api_key
  STRIPE_PUBLIC_KEY = Settings.stripe_public_key
end