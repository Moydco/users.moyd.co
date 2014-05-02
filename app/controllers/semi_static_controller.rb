class SemiStaticController < ApplicationController
  def index
    if user_signed_in?
      @user = current_user
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
end
