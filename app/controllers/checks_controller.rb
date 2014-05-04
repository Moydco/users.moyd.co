class ChecksController < ApplicationController
  def index

  end

  def create
    if signed_in?
      render json: @current_user.to_json, status: 200
    else
      render text: 'User not authenticated', status: 404
    end
  end
end
