class Oauth2Controller < ApplicationController
  before_action :signed_in_user, only: [:index, :destroy]

  def index
    @renew_tokens=RenewToken.where(user: current_user)
  end

  def destroy
    token=RenewToken.find(params[:id])
    if token.app.name == Settings.local_app_name
      flash[:error] = 'You can\'t destroy local link'
    else
      if token.user == current_user
        token.destroy
        flash[:success] = 'Application authorization removed'
      else
        flash[:error] = 'You don\'t belongs this object'
      end
    end
    redirect_to user_oauth2_index_path(current_user)
  end

  def authorize
    # Store params in session, if I haven't do it before
    session[:response_type] ||= params[:response_type]
    session[:client_id]     ||= params[:client_id]
    session[:client_secret] ||= params[:client_secret]
    session[:state]         ||= params[:state]
    logger.debug "Session response_type: #{session[:response_type]}"
    logger.debug "Session client_id: #{session[:client_id]}"
    logger.debug "Session client_secret: #{session[:client_secret]}"
    logger.debug "Session state: #{session[:state]}"

    @app = App.where(id: session[:client_id]).first
    # Check if the App exists
    if @app.nil?
      destroy_session
      flash[:error] = 'App not found'
      redirect_to root_path
    else
      if session[:response_type] == 'code' and !@app.password_correct?(session[:client_secret])
        flash[:error] = "App secret incorrect"
        destroy_session
        redirect_to root_path
      else
        if signed_in?
          # If the user has already authorized the app, reply, else request the authorization
          renew_token = RenewToken.where(app: @app, user: current_user).first
          unless renew_token.nil?
            user_token = current_user.generate_token(session[:client_id])

            reply_authorize(session[:response_type], @app, session[:state], user_token, renew_token)
          end
        else
          redirect_to signin_path
        end
      end
    end
  end


  def deny_authorize
    logger.debug "Session response_type: #{session[:response_type]}"
    logger.debug "Session client_id: #{session[:client_id]}"
    logger.debug "Session client_secret: #{session[:client_secret]}"
    logger.debug "Session state: #{session[:state]}"
    app = App.where(id: session[:client_id]).first
    # Clear the session
    destroy_session
    # Redirect with error
    redirect_to app.redirect_uri + '?error=access_denied'
  end

  def allow_authorize
    if signed_in?
      logger.debug "Session response_type: #{session[:response_type]}"
      logger.debug "Session client_id: #{session[:client_id]}"
      logger.debug "Session state: #{session[:state]}"
      logger.debug "access token: #{token}"
      app = App.where(id: session[:client_id]).first
      if app.nil?
        destroy_session
        flash[:error] = 'App not found in allow_authorize'
        redirect_to root_path
      else
        if session[:response_type] == 'code' and !app.password_correct?(session[:client_secret])
          destroy_session
          flash[:error] = 'App secret incorrect in allow authorize'
          redirect_to root_path
        else
          renew_token = RenewToken.new(app: app, user: current_user)
          if renew_token.save
            response_type = session[:response_type]
            token = current_user.generate_token(session[:client_id])
            state = session[:state]
            destroy_session
            reply_authorize(response_type, app, state, token, renew_token)
          else
            destroy_session
            # Redirect with error
            redirect_to app.redirect_uri + '?error=server_error'
          end
        end
      end
    else
      redirect_to root_path
    end
  end

  def token_request
    app = App.where(id: params[:client_id]).first
    if app.nil?
      error = {
          error: 'server_error',
          error_description: 'App not found'
      }
      render json: error.to_json, status: 400
    else

      if params[:grant_type] == 'password'
        if app.enable_password
          user = User.where(email: params[:username].downcase).first
          # check if the password is correct
          if !user.nil? && user.authenticate(params[:password])
            # Sign in user definitively
            sign_in user

            # generate the refresh token, if tere isn't one
            renew_token = RenewToken.where(app: app, user: current_user).first
            renew_token = RenewToken.new(app: app, user: current_user) unless renew_token.nil?

            output = {
                access_token: current_user.generate_token(params[:client_id]),
                expires_in: Settings.token_expire,
                restricted_to: [],
                token_type: 'bearer',
                refresh_token: renew_token
            }
            render json: output.to_json, status: 200
          else
            error = {
                error: 'invalid_grant',
                error_description: 'Invalid user credentials'
            }
            render json: error.to_json, status: 400
          end
        else
          error = {
              error: 'unauthorized_client',
              error_description: 'Password grant not allowed'
          }
          render json: error.to_json, status: 400
        end
      elsif params[:grant_type] == 'refresh_token'
        if app.enable_code or app.enable_implicit
          renew_token = RenewToken.where(id: params[:refresh_token]).first
          if renew_token.nil?
            error = {
                error: 'invalid_request',
                error_description: 'Refresh token not valid'
            }
            render json: error.to_json, status: 400
          else
            if renew_token.app.id.to_s == params[:client_id] && renew_token.app.password_correct?(params[:client_secret])
              user = renew_token.user
              app  = renew_token.app

              sign_in user
              # generate the refresh token, if tere isn't one
              renew_token.destroy
              renew_token = RenewToken.new(app: app, user: current_user)
              renew_token.save
              output = {
                  access_token: current_user.generate_token(params[:client_id]),
                  expires_in: Settings.token_expire,
                  restricted_to: [],
                  token_type: 'bearer',
                  refresh_token: renew_token.id.to_s
              }
              render json: output.to_json, status: 200
            end
          end
        else
          error = {
              error: 'unauthorized_client',
              error_description: 'Client grant not allowed'
          }
          render json: error.to_json, status: 400
        end
      elsif params[:grant_type] == 'authorization_code'
        code = params[:code]
        if app.password_correct?(params[:client_secret])
          renew_token_id = $redis_code.get(code)
          if renew_token_id.nil?
            error = {
                error: 'invalid_grant',
                error_description: 'Grant type not valid'
            }
            render json: error.to_json, status: 400
          else
            user=RenewToken.find(renew_token_id).user
            sign_in(user)

            output = {
                access_token: current_user.generate_token(params[:client_id]),
                expires_in: Settings.token_expire,
                restricted_to: [],
                token_type: 'bearer',
                refresh_token: renew_token_id
            }
            render json: output.to_json, status: 200
          end
        else
          error = {
              error: 'invalid_grant',
              error_description: 'Wrong client secret'
          }
          render json: error.to_json, status: 400
        end

      else
        error = {
            error: 'invalid_request',
            error_description: 'Grant type not valid in token request'
        }
        render json: error.to_json, status: 400
      end
    end
  end

  def revoke
    token = params[:token]
    client_id = params[:client_id]
    client_secret = params[:client_secret]

    if token.nil? or token.blank? or client_id.nil? or client_id.blank? or client_secret.nil? or client_secret.blank?
      error = {
          error: 'invalid_request',
          error_description: 'Missing required parameters'
      }
      render json: error.to_json, status: 400
    else
      begin
        user_from_token = JSON.parse(JWT.decode(token, client_id))
        if !(user_from_token.nil? or user_from_token["_id"].nil? or user_from_token["_id"]["$oid"].nil? or user_from_token.blank? or user_from_token["_id"].blank? or user_from_token["_id"]["$oid"].blank?)
          user = User.where(id: user_from_token["_id"]["$oid"]).first
          app = App.where(id: client_id).first
          if !(user.nil? or app.nil? or !(app.password_correct?(client_secret)))
            sign_in(user)
            renew_token = RenewToken.where(app: app, user: user).first
            renew_token.destroy unless renew_token.nil?
            sign_out
            render text: 'Logged out'
          else
            error = {
                error: 'invalid_grant',
                error_description: 'Invalid client credentials'
            }
            render json: error.to_json, status: 400
          end

        else
          error = {
              error: 'invalid_grant',
              error_description: 'User token not found'
          }
          render json: error.to_json, status: 400
        end
      rescue
        renew_token = RenewToken.where(id: params[:token]).first
        unless renew_token.nil?
          user = renew_token.user
          app = renew_token.app
          if app.id.to_s == client_id and app..password_correct?(client_secret)
            renew_token.destroy
            sign_in(user)
            sign_out
            render text: 'Logged out'
          else
            error = {
                error: 'invalid_grant',
                error_description: 'Invalid client credentials'
            }
            render json: error.to_json, status: 400
          end
        else
          error = {
              error: 'invalid_grant',
              error_description: 'Renew token not found'
          }
          render json: error.to_json, status: 400
        end
      end
    end
  end


  private

  def reply_authorize(response_type, app, state, access_token, renew_token)
    session[:response_type] = nil
    session[:client_id] = nil
    session[:state] = nil
    if response_type == 'token'
      if app.enable_implicit
        url = generate_url(app.redirect_uri, access_token: access_token, renew_token: renew_token.id.to_s, state:state)
        logger.debug "Redirect to #{url}"
      else
        url = generate_url(app.redirect_uri, error: 'unsupported_response_type', state:state)
        logger.debug "Redirect to #{url}"
      end
      redirect_to url
    elsif response_type == 'code'
      if app.enable_implicit
        code = renew_token.create_code_token(renew_token.id.to_s)
        url = generate_url(app.redirect_uri, code: code, state:state)
        logger.debug "Redirect to #{url}"
      else
        url = generate_url(app.redirect_uri, error: 'unsupported_response_type', state:state)
        logger.debug "Redirect to #{url}"
      end
      redirect_to url
    else
      url = generate_url(app.redirect_uri, error: 'unsupported_response_type')
      redirect_to url
    end
  end

  def generate_url(url, params = {})
    uri = URI(url)
    uri.query = params.to_query
    uri.to_s
  end

  def destroy_session
    session[:response_type] = nil
    session[:client_id]     = nil
    session[:client_secret] = nil
    session[:state]         = nil
  end
end
