class ConsumesController < ApplicationController
  before_action :signed_in_user

  # Debit user with "amount". Amount is in pence (UKP * 100)
  def create
    @amount = params[:amount]
    @user = User.find(params[:user_id])
    logger.debug "User id #{@user.id.to_s}"
    logger.debug "User id from token #{current_user.id.to_s}"

    if @user != current_user
      render text: 'User not correct', status: 500
    else
      if @user.balance < params[:amount].to_i
        render text: 'User has not enough money', status: 403
      else
        activity = @user.activities.create(kind: 'consume', amount: @amount)
        c = Consume.create(description: params[:description])
        activity.consume = c
        activity.save

        render text: 'User billed', status: 200
      end
    end
  end
end