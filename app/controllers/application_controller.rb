class ApplicationController < ActionController::Base
  require 'json'
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  # All the helper for User Authentication are here
  include SessionsHelper

end
