if Settings.billing_provider == 'stripe'
  Stripe.api_key    = Settings.billing_provider_api_key
  STRIPE_PUBLIC_KEY = Settings.billing_provider_public_key
end