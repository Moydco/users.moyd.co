class UserDetailsController < ApplicationController
  before_action :signed_in_user

  # Methods to update user's billing details

  # 
  def edit
    @user = User.find(params[:user_id])
  end

  def update
    @user = User.find(params[:user_id])

    if @user.update_attributes(details_params)
      UserMailer.update_details(@user).deliver

      flash[:success] = 'User additional data successfully updated'
      redirect_to root_path
    else
      flash.now[:error] = 'Error updating billing data'
      render 'edit'
    end
  end


  private

  # Strong params: permit only email, password and password confirmation
  def details_params
    params.require(:user).permit(:user_detail_attributes => [ :name,
                                                   :address1,
                                                   :address2,
                                                   :zip,
                                                   :city,
                                                   :state,
                                                   :country,
                                                   :phone,
                                                   :vat_id,
                                                   :advise_me_at
    ]
    )
  end
end