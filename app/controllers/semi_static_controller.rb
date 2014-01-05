class SemiStaticController < ApplicationController
  def index
    if user_signed_in?
      @user = current_user
    end
  end

  def how_it_works

  end

  def plan

  end

  def become_a_partner
    @partner = PartnerContact.new
  end

  def create
    @partner = PartnerContact.new(partner_params)
    if @partner.save
      PartnerMailer.contact_email(@partner).deliver
      redirect_to become_a_partner_path, notice: 'Thank you for your contact: we will respond as soon as possible'
    else
      flash.now[:error] = @partner.errors.full_messages.to_sentence
      render action: :become_a_partner
    end
  end

  def check_token
    if user_signed_in?
      respond_to do |format|
        format.html {render text: current_user.id.to_s}
        format.xml {render xml: current_user}
        format.json {render json: current_user}
      end
    else
      respond_to do |format|
        format.html {render text: 'Unauthorized', status: 404 }
        format.xml {render xml: {error: 'Unauthorized'}, status: 404 }
        format.json {render json: {error: 'Unauthorized'}, status: 404 }
      end
    end
  end

  def update_free_ddns
    if current_user.update_attributes(ddns_params)
      redirect_to root_path, notice: 'DDNS record successfully updated'
    else
      flash.now[:error] = 'Error updating your free DDNS'
      render action: :index
    end
  end

  def ddns
    if user_signed_in?
      current_user.update_attributes(:free_ip_address => request.remote_ip)
      respond_to do |format|
        format.html {render text: current_user.id.to_s}
        format.xml {render xml: current_user}
        format.json {render json: current_user}
      end
    else
      respond_to do |format|
        format.html {render text: 'Unauthorized', status: 404 }
        format.xml {render xml: {error: 'Unauthorized'}, status: 404 }
        format.json {render json: {error: 'Unauthorized'}, status: 404 }
      end
    end
  end

  def change_plan_do

  end

  def partner_params
    params.require(:partner_contact).permit(
        :first_name,
        :last_name,
        :company,
        :email,
        :kind,
        :message
    )
  end

  def ddns_params
    params.require(:user).permit(:free_third_level, :free_ip_address)
  end
end
