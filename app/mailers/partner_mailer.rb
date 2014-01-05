class PartnerMailer < ActionMailer::Base
  default to: "info@alwaysresolve.com"

  def contact_email(partner)
    @partner = partner
    mail(form: @partner.email, subject: 'A possible partner contact us...')
  end
end
