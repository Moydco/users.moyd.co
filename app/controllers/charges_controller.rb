class ChargesController < ApplicationController

  def index
    customer = Stripe::Customer.retrieve(current_user.stripe_id)
    @subscription = customer.subscription
    @invoices = @customer.invoices
    @upcoming_invoices = @customer.upcoming_invoices
  end

  def create
    if current_user.stripe_id.nil?
      customer = Stripe::Customer.create(
          :email => current_user.email,
          :card  => params[:stripeToken],
          :plan  => params[:plan]
      )
    else
      customer = Stripe::Customer.retrieve(current_user.stripe_id)
      customer.update_subscription(:plan => params[:plan])
    end

    current_user.update_attributes(:plan => params[:plan], :stripe_id => customer.id)
    flash[:notice] = 'Welcome to plan ' + params[:plan]
    redirect_to plan_path

  rescue Stripe::CardError => e
    flash[:error] = e.message
    redirect_to plan_path
  end

end
