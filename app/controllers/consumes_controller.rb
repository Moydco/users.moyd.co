class ConsumesController < ApplicationController
  before_action :signed_in_user

  def create
    @amount = params[:amount]
    @user = User.find(params[:user_id])
    logger.debug "User id #{@user.id.to_s}"
    logger.debug "User id from token #{current_user["_id"]["$oid"]}"

    if @user.id.to_s != current_user["_id"]["$oid"]
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