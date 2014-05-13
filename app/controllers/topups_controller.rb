class TopupsController < ApplicationController
  before_action :signed_in_user

  def show
    @user = User.find(params[:user_id])
    @activity = @user.activities.find(params[:id])
    if !@activity.invoice.nil?
      content = @activity.invoice.doc.read
      if stale?(etag: content, last_modified: @activity.invoice.updated_at.utc, public: true)
        send_data content, type: @activity.invoice.doc.file.content_type, disposition: "inline"
        expires_in 0, public: true
      end
    else
      flash[:error] = 'Invoice not generated yet'
      redirect_to root_path
    end
  end

  def create
    @amount = params[:amount]
    @user = User.find(params[:user_id])
    customer = nil
    # retrieve customer object from Stripe, if any
    begin
      customer = Stripe::Customer.retrieve(@user.stripe_id) unless @user.stripe_id.nil?
    end

    if customer.nil?
      # if I haven't found a valid customer in stripe, create a new one and update local stripe_id
      customer = Stripe::Customer.create(
        :email => params[:stripeEmail],
        :card  => params[:stripeToken]
      )
      @user.update_attribute(:stripe_id, customer.id)
    else
      # else update customer card with the one provided
      customer.card = params[:stripeToken]
      customer.save

    end

    begin
      @charge = Stripe::Charge.create(
          :customer    => customer.id,
          :amount      => @amount,
          :description => "TopUp of #{@amount.to_f/100} UKP",
          :currency    => 'gbp'
        )

      if @charge.paid
        activity = @user.activities.create(kind: 'topup', amount: @amount)
        activity.generate_invoice
        flash[:success] = "Thank you for top up #{(@amount.to_f/100).to_s}$ with us."
        redirect_to root_path
      else
        flash.now[:error] = "Credit card declined"
        render new
      end
    rescue Stripe::CardError => e
      flash.now[:error] = e.message
      render new
    end
  end

  def edit
    @user = User.find(params[:user_id])
    @activity = @user.activities.find(params[:id])
    @invoice = Invoice.new
  end

  def update
    @user = User.find(params[:user_id])
    if @user.is_admin?
      @activity = @user.activities.find(params[:id])
      i=Invoice.new
      i.doc.store!(params[:invoice][:doc])
      @activity.invoice = i
      @activity.save
      flash[:success] = 'Invoice uploaded'
    else
      flash[:error] = 'You don\'t have rights to do that!'
    end
    redirect_to root_path

  end
end