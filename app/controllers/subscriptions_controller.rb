class SubscriptionsController < ApplicationController
  before_action :signed_in_user

  def index
    if current_user.is_admin?
      @subscriptions = Subscription.all
    else
      @subscriptions = current_user.subscriptions
    end
  end

  def create
    subscription = current_user.subscriptions.create(
        description:  params[:description],
        amount:       params[:amount],
        every_value:  params[:every_value],
        every_type:   params[:every_type],
        first_drain:  params[:first_drain],
        callback_url: params[:callback_url]
    )
    if subscription.save
      render json: subscription
    else
      render text: 'Error creating subscription', status: 400
    end
  end

  def show
    if current_user.is_admin?
      @subscription = Subscription.find(params[:id])
    else
      @subscription = current_user.subscriptions.find(params[:id])
    end
    respond_to do |format|
      format.html
      format.json { render json: @subscription.to_json}
    end
  end

  def destroy
    if current_user.is_admin?
      subscription = Subscription.find(params[:id])
    else
      subscription = current_user.subscriptions.find(params[:id])
    end
    if subscription.destroy
      flash[:success] = 'Subscription removed successfully'
    else
      flash[:error] = 'Error removing subscription'
    end

    redirect_to user_subscriptions_path(current_user)
  end
end
