class VouchersController < ApplicationController
  before_action :signed_in_user

  # Show active vouchers
  def index
    if current_user.is_admin?
      @voucher = Voucher.new
      @vouchers = Voucher.or({:expire.gt => Date.today}, {expire: nil })
    else
      redirect_to root_path
    end
  end

  # Credit a voucher
  def create
    if signed_in?
      @user = current_user
      @voucher = Voucher.find(params[:voucher][:voucher_code])
      if @voucher.nil?
        flash[:error] = 'Incorrect voucher code'
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

  # Generate a new voucher
  def new_voucher
    if current_user.is_admin?
      @voucher = Voucher.create(voucher_params)
      flash[:success] = "Your voucher of #{(@voucher.amount.to_f/100).to_s} UKP was successfully created. The voucher code is #{@voucher.id.to_s}"
    end
    redirect_to user_vouchers_path(current_user)
  end

  # Destroy a voucher
  def destroy
    if current_user.is_admin?
      if Voucher.find(params[:id]).destroy
        flash[:success] = "Voucher deleted"
        redirect_to user_vouchers_path(current_user)
      else
        flash[:success] = "Error deleting voucher"
        redirect_to user_vouchers_path(current_user)
      end
    else
      redirect_to root_path
    end
  end

  private

  # Strong params: permit only email, password and password confirmation
  def voucher_params
    params.require(:voucher).permit(:expire, :amount )
  end
end