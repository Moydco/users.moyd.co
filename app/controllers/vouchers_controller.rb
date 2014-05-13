class VouchersController < ApplicationController
  before_action :signed_in_user

  def create
    if signed_in?
      @user = User.find(current_user["_id"]["$oid"])
      @voucher = Voucher.find(params[:voucher][:voucher_code])
      if @voucher.nil?
        flash[:error] = 'Incorreect voucher code'
      else
        if @voucher.activated?
          flash[:error] = 'Voucher already used'
        else
          if @voucher.expired?
            flash[:error] = 'Voucher expired'
          else
            # if here, the voucher is correct
            activity = @user.activities.create(kind: 'voucher', amount: @voucher.amount)
            @voucher.activity = activity
            @voucher.save
            flash[:success] = "Your voucher of #{(@voucher.amount.to_f/100).to_s} UKP was successfully applied."
          end
        end
      end
    else
      flash[:error] = 'User not logged in'
    end

    redirect_to root_path
  end

  def new_voucher
    if signed_in?
      user = User.find(current_user["_id"]["$oid"])
      if user.is_admin?
        @voucher = Voucher.create(voucher_params)
        flash[:success] = "Your voucher of #{(@voucher.amount.to_f/100).to_s} UKP was successfully created. The voucher code is #{@voucher.id.to_s}"
      end
    end
    redirect_to root_path
  end

  def destroy
    if signed_in?
      user = User.find(current_user["_id"]["$oid"])
      if user.is_admin?
        if Voucher.find(params[:id]).destroy
          flash[:success] = "Voucher deleted"
        else
          flash[:success] = "Error deleting voucher"
        end
      end
    end
    redirect_to root_path
  end

  # Strong params: permit only email, password and password confirmation
  def voucher_params
    params.require(:voucher).permit(:expire, :amount )
  end
end