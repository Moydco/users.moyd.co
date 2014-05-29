class Oauth2Controller < ApplicationController
  before_action :signed_in_user, only: [:index, :destroy]

  # Show the authorized application
  def index
    @renew_tokens=RenewToken.where(user: current_user)
  end

  # Unauthorize an application
  def destroy
    token=RenewToken.find(params[:id])
    if !token.app.nil? and token.app.name == Settings.local_app_name
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

  # Authorize an application: if the user is logged in and already as authorized the application, return directly the token, else request to sign_in or to authorize
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

    unless check_app_auth(session[:client_id], session[:client_secret], session[:response_type], session[:state])
      if signed_in?
        logger.debug "Signed in"
        if Settings.multi_application == 'true'
          app = App.where(id: session[:client_id]).first
          # If the user has already authorized the app, reply, else request the authorization
          renew_token = RenewToken.where(app: app, user: current_user).first
          uri = app.redirect_uri
          @name = app.name
        else
          renew_token = RenewToken.where(app: nil, user: current_user).first
          uri = Settings.single_application_mode_url + Settings.single_application_mode_path
          @name = Settings.single_application_mode_name
        end
        logger.debug("Renew token: #{renew_token}")
        unless renew_token.nil?
          user_token = current_user.generate_token(session[:client_id])
          reply_authorize(session[:response_type], uri, session[:state], user_token, renew_token)
        end
      else
        logger.debug "Not signed in"
        redirect_to signin_path
      end
    end
  end

  # The user deny the authorization
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

  # The user approved the authorization
  def allow_authorize
    if signed_in?
      logger.debug "Session response_type: #{session[:response_type]}"
      logger.debug "Session client_id: #{session[:client_id]}"
      logger.debug "Session state: #{session[:state]}"
      logger.debug "access token: #{token}"
      unless check_app_auth(session[:client_id], session[:client_secret], session[:response_type], session[:state])
        if Settings.multi_application == 'true'
          app = App.where(id: session[:client_id]).first
          uri = app.redirect_uri
          renew_token = RenewToken.new(app: app, user: current_user)
        else
          uri = Settings.single_application_mode_url + Settings.single_application_mode_path
          renew_token = RenewToken.new(app: nil, user: current_user)
        end
        if renew_token.save
          response_type = session[:response_type]
          token = current_user.generate_token(session[:client_id])
          state = session[:state]
          destroy_session
          reply_authorize(response_type, uri, state, token, renew_token)
        else
          destroy_session
          # Redirect with error
          redirect_to app.redirect_uri + '?error=server_error'
        end
      end
    else
      redirect_to root_path
    end
  end

  def token_request
    unless check_app_token(params[:client_id], params[:client_secret], params[:grant_type])

      # Password
      if params[:grant_type] == 'password'

        if Settings.multi_application == 'true'
          app = App.where(id: params[:client_id]).first
          auto_renew = app.auto_renew
        else
          app = nil
          auto_renew = Settings.single_application_mode_auto_renew == 'true'
        end
        # check if the password is correct
        user = User.where(email: params[:username].downcase).first
        if !user.nil? && user.authenticate(params[:password])
          # Sign in user definitively
          sign_in user

          if auto_renew
            output = {
                access_token: current_user.generate_token(params[:client_id]),
                expires_in: Settings.token_expire,
                restricted_to: [],
                token_type: 'bearer'
            }
          else
            # generate the refresh token, if there isn't one
            renew_token = RenewToken.where(app: app, user: current_user).first
            if renew_token.nil?
              renew_token = RenewToken.new(app: app, user: current_user)
              renew_token.save
            end

            output = {
                access_token: current_user.generate_token(params[:client_id]),
                expires_in: Settings.token_expire,
                restricted_to: [],
                token_type: 'bearer',
                refresh_token: renew_token.id.to_s
            }
          end


          render json: output.to_json, status: 200
        else
          error = {
              error: 'invalid_grant',
              error_description: 'Invalid user credentials'
          }
          render json: error.to_json, status: 400
        end

      # Refresh Token
      elsif params[:grant_type] == 'refresh_token'
        renew_token = RenewToken.where(id: params[:refresh_token]).first
        if renew_token.nil?
          error = {
              error: 'invalid_request',
              error_description: 'Refresh token not valid'
          }
          render json: error.to_json, status: 400
        else
          if Settings.multi_application == 'true'
            if renew_token.app.id.to_s == params[:client_id] && renew_token.app.password_correct?(params[:client_secret])
              app  = renew_token.app
              e = true
            else
              e = false
              error = {
                  error: 'invalid_grant',
                  error_description: 'Wrong client secret'
              }
              render json: error.to_json, status: 400
            end
          else
            if Settings.single_application_mode_id == params[:client_id] && Settings.single_application_mode_secret == params[:client_secret]
              app =nil
              e = true
            else
              e = false
              error = {
                  error: 'invalid_grant',
                  error_description: 'Wrong client secret'
              }
              render json: error.to_json, status: 400
            end
          end
          if e
            user = renew_token.user

            sign_in user
            # generate the refresh token, if there isn't one
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

      # Authorization Code
      elsif params[:grant_type] == 'authorization_code'
        code = params[:code]
        renew_token_id = $redis_code.get(code)

        if renew_token_id.nil?
          error = {
              error: 'invalid_grant',
              error_description: 'Grant type not valid'
          }
          render json: error.to_json, status: 400
        else
          rt =RenewToken.find(renew_token_id)
          user = rt.user

          sign_in(user)
          if Settings.multi_application == 'true'
            auto_renew = rt.app.auto_renew
          else
            auto_renew = Settings.single_application_mode_auto_renew == 'true'
          end

          if auto_renew
            output = {
                access_token: current_user.generate_token(params[:client_id]),
                expires_in: Settings.token_expire,
                restricted_to: [],
                token_type: 'bearer'
            }
          else
            output = {
                access_token: current_user.generate_token(params[:client_id]),
                expires_in: Settings.token_expire,
                restricted_to: [],
                token_type: 'bearer',
                refresh_token: renew_token_id
            }

          end
          render json: output.to_json, status: 200
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
          e = true
          if Settings.multi_application == 'true'
            app = App.where(id: client_id).first
            if app.nil? or !(app.password_correct?(client_secret))
              e = false
              error = {
                  error: 'invalid_grant',
                  error_description: 'Invalid client credentials'
              }
              render json: error.to_json, status: 400
            end
          else
            app = nil
            if Settings.single_application_mode_id != client_id or Settings.single_application_mode_secret != client_secret
              e = false
              error = {
                  error: 'invalid_grant',
                  error_description: 'Invalid client credentials'
              }
              render json: error.to_json, status: 400
            end
          end

          if e
            sign_in(user)
            renew_token = RenewToken.where(app: app, user: user).first
            renew_token.destroy unless renew_token.nil?
            sign_out
            render text: 'Logged out'
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
        if renew_token.nil?
          error = {
              error: 'invalid_grant',
              error_description: 'Renew token not found'
          }
          render json: error.to_json, status: 400
        else
          user = renew_token.user
          app = renew_token.app
          if (Settings.multi_application == 'true' and app.id.to_s == client_id and app..password_correct?(client_secret)) or
              (Settings.multi_application == 'false' and Settings.single_application_mode_id != client_id or Settings.single_application_mode_secret != client_secret)
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
        end
      end
    end
  end

  private

  # Reply to an authorization request
  def reply_authorize(response_type, uri, state, access_token, renew_token)
    destroy_session

    if response_type == 'token'
      url = generate_url(uri, callback: 'x', access_token: access_token, renew_token: renew_token.id.to_s, exprires_in: Settings.token_expire, state:state)
      redirect_to url
    elsif response_type == 'code'
      code = renew_token.create_code_token(renew_token.id.to_s)
      url = generate_url(uri, code: code, state:state)
      redirect_to url
    else
      url = generate_url(app.redirect_uri, error: 'unsupported_response_type')
      redirect_to url
    end
  end

  # Generate the URL to redirect
  def generate_url(url, params = {})
    uri = URI(url)
    if Settings.get_params_char == '#'
      uri.fragment = params.to_query
    else
      uri.query = params.to_query
    end
    uri.to_s
  end

  # Clear session variables
  def destroy_session
    session[:response_type] = nil
    session[:client_id]     = nil
    session[:client_secret] = nil
    session[:state]         = nil
  end

  # Internal method to check the syntax of an auth request
  def check_app_auth(client_id, client_secret, response_type, state)
    error = false

    if Settings.multi_application == 'true'
      app = App.where(id: client_id).first
      if app.nil?
        flash[:error] = 'App not found'
        error = true
        redirect_to root_path
      else
        if response_type == 'code'
          if !app.enable_code
            error = true
            url = generate_url(app.redirect_uri, error: 'unsupported_response_type', error_description: 'Code response type not allowed', state:state)
            redirect_to url
          elsif !app.password_correct?(client_secret)
            error = true
            url = generate_url(app.redirect_uri, error: 'access_denied', error_description: "App secret #{client_secret} for app #{client_id} incorrect", state:state)
            redirect_to url
          end
        elsif !app.enable_implicit and response_type == 'token'
          error = true
          url = generate_url(app.redirect_uri, error: 'unsupported_response_type', error_description: 'Token (implicit) response type not allowed', state:state)
          redirect_to url
        elsif response_type != 'code' and response_type != 'token'
          error = true
          url = generate_url(app.redirect_uri, error: 'unsupported_response_type', error_description: 'Response type not supported', state:state)
          redirect_to url
        end
      end
    else
      if Settings.single_application_mode_id != client_id
        error = true
        url = generate_url(Settings.single_application_mode_url + Settings.single_application_mode_path, error: 'access_denied', error_description: 'App id and/or secret incorrect', state:state)
        redirect_to url
      elsif response_type == 'code'
        if  Settings.single_application_mode_enable_code == 'false'
          error = true
          url = generate_url(Settings.single_application_mode_url + Settings.single_application_mode_path, error: 'unsupported_response_type', error_description: 'Code response type not allowed', state:state)
          redirect_to url
        elsif Settings.single_application_mode_secret != client_secret
          error = true
          url = generate_url(Settings.single_application_mode_url + Settings.single_application_mode_path, error: 'access_denied', error_description: 'App id and/or secret incorrect', state:state)
          redirect_to url
        end
      elsif Settings.single_application_mode_enable_implicit == 'false' and response_type == 'token'
        error = true
        url = generate_url(Settings.single_application_mode_url + Settings.single_application_mode_path, error: 'unsupported_response_type', error_description: 'Token (implicit) response type not allowed', state:state)
        redirect_to url
      elsif response_type != 'code' and response_type != 'token'
        error = true
        url = generate_url(Settings.single_application_mode_url + Settings.single_application_mode_path, error: 'unsupported_response_type', error_description: 'Response type not supported', state:state)
        redirect_to url
      end
    end
    destroy_session if error

    error
  end

  # Internal method to check the syntax of a token request
  def check_app_token(client_id, client_secret, grant_type)
    e = false

    if Settings.multi_application == 'true'
      app = App.where(id: params[:client_id]).first
      if app.nil?
        e = true
        error = {
            error: 'server_error',
            error_description: 'App not found'
        }
        render json: error.to_json, status: 400
      else
        if grant_type == 'password' and !app.enable_password
          e = true
          error = {
              error: 'unauthorized_client',
              error_description: 'Password grant not allowed'
          }
          render json: error.to_json, status: 400
        elsif grant_type == 'refresh_token'
          if !app.enable_code and !app.enable_implicit
            e = true
            error = {
                error: 'unauthorized_client',
                error_description: 'Client grant not allowed'
            }
            render json: error.to_json, status: 400
          elsif !app.password_correct?(client_secret)
            e = true
            error = {
                error: 'server_error',
                error_description: 'wrong secret'
            }
            render json: error.to_json, status: 400
          end
        elsif grant_type == 'authorization_code' and !app.enable_code
          e = true
          error = {
              error: 'unauthorized_client',
              error_description: 'Client grant not allowed'
          }
          render json: error.to_json, status: 400
        elsif grant_type == 'authorization_code' and !app.password_correct?(client_secret)
          e = true
          error = {
              error: 'server_error',
              error_description: 'wrong secret'
          }
          render json: error.to_json, status: 400
        end
      end
    else
      if Settings.single_application_mode_id != client_id
        e = true
        error = {
            error: 'server_error',
            error_description: 'App not found'
        }
        render json: error.to_json, status: 400
      else
        if Settings.single_application_mode_enable_password == 'false' and grant_type == 'password'
          e = true
          error = {
              error: 'unauthorized_client',
              error_description: 'Password grant not allowed'
          }
          render json: error.to_json, status: 400
        elsif grant_type == 'refresh_token'
          if Settings.single_application_mode_enable_code == 'false' or Settings.single_application_mode_enable_implicit == 'false'
            e = true
            error = {
                error: 'unauthorized_client',
                error_description: 'Client grant not allowed'
            }
            render json: error.to_json, status: 400
          elsif Settings.single_application_mode_secret != client_secret
            e = true
            error = {
                error: 'server_error',
                error_description: 'wrong secret'
            }
            render json: error.to_json, status: 400
          end
        elsif grant_type == 'authorization_code'
          if Settings.single_application_mode_enable_code == 'false'
            e = true
            error = {
                error: 'unauthorized_client',
                error_description: 'Client grant not allowed'
            }
            render json: error.to_json, status: 400
          elsif Settings.single_application_mode_secret != client_secret
            e = true
            error = {
                error: 'server_error',
                error_description: 'wrong secret'
            }
            render json: error.to_json, status: 400
          end

        end

      end
    end
    destroy_session if e

    e

  end

end
