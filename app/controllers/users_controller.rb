class UsersController < ApplicationController
  before_action :signed_in_user, only: [:index, :edit, :update]

  # Nothing useful, at the moment
  def index
    render status: 404
  end

  # Sign up new user
  def new
    @user = User.new
    @user.build_user_detail
  end

  # Create a new user and pre-fill empty user details
  def create
    user = User.new(user_params)

    if user.save
      if Settings.multi_application == 'false'
        flash[:success] = "Welcome to #{Settings.single_application_mode_name}! Your login details are successfully stored and in a few minutes you'll find a confirmation email in your inbox: please approve your registration as soon as possible. In the meantime, please provide other useful information for billing and contact you."
      else
        flash[:success] = "Welcome to #{Application.find(application_id).name}! Your login details are successfully stored and in a few minutes you'll find a confirmation email in your inbox: please approve your registration as soon as possible. In the meantime, please provide other useful information for billing and contact you."
      end
      # if all is correct, send confirmation email...
      UserMailer.token_email(user).deliver

      # ...sign-in user...
      sign_in(user)

      # ...and redirect to user page, to request invoice data
      redirect_to edit_user_user_details_path(user)
    else
      render 'new'

    end
  end

  # Edit user data form
  def edit
    @user = User.find(params[:id])
    unless @user.data_complete?
      redirect_to edit_user_user_details_path(@user)
    end
  end

  # Update user data
  def update
    @user = User.find(params[:id])
    if @user.update_attributes(user_params)
      flash[:success] = "Your password has successfully updated"

      #sign_in(user)

      # ...and redirect to user page, to request invoice data
      redirect_to edit_user_user_details_path(@user)
    else
      flash.now[:error] = "Error updating your password"
      render 'edit'

    end
  end

  # Destroy a user
  def destroy
  end

  def validate_token
    @user=User.find(params[:id])
    if @user.confirmed?
      if @user.data_complete?
        redirect_to root_path
      else
        redirect_to edit_user_user_details_path(@user)
      end
    end
  end

  def validate_token_do
    @user=User.find(params[:id])
    unless @user.confirmed?
      if @user.confirm_token == params[:user][:tk]
        @user.update_attribute(:confirmed, true)
        UserMailer.welcome(@user).deliver
      end
    end

    if @user.confirmed?
      if @user.data_complete?
        redirect_to root_path
      else
        redirect_to edit_user_user_details_path(@user)
      end
    else
      flash.now[:error] = 'Invalid token'
      render :validate_token
    end
  end

  def resend_confirm_email
    UserMailer.token_email(User.find(params[:id])).deliver
    flash[:success] = 'We have send you another mail with your token'
    redirect_to root_path
  end

  private

  # Strong params: permit only email, password and password confirmation
  def user_params
    params.require(:user).permit(:email, :password,
                                 :password_confirmation,
                                 :user_detail_attributes => [ :name ]
    )
  end


end
