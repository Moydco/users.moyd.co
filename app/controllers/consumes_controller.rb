class ConsumesController < ApplicationController
  #before_action :signed_in_user

  # Debit user with "amount". Amount is in pence (UKP * 100)
  def create
    @amount = params[:amount]
    @user = User.where(id: params[:user_id]).first

    if params[:client_id] == application_id and params[:client_secret] == application_secret
      if @user.nil?
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
    else
      render text: 'Application authentication failed'
    end
  end
end