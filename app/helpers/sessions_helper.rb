# In SessionHelper there are all methods for Views and Controllers (check the include in application_helper.rb)
# useful for User Autentication
module SessionsHelper

  # Sign in the user
  def sign_in(user)
    # update timestamp, IP address, refresh token data
    user = user.touch_login(request.remote_ip)
    # create the token and in store it on our Redis DB
    if Settings.multi_application == 'true' or self.application_id == Settings.single_application_mode_id
      auto_renew = Settings.single_application_mode_auto_renew
    else
      auto_renew = App.find(self.application_id).auto_renew
    end
    remember_token = user.store_user_session_in_redis(self.application_id, auto_renew)
    logger.debug "Token saved on redis while sign_in: #{remember_token}"
    # set a cookie on client browser with the user token, so he can browse "logged in" views on this site
    cookies.permanent[:remember_token] = remember_token
    # set a variable "token" for this app
    self.token = remember_token
    # if the bloom filter is enabled, store token also in it
    if Settings.use_bloom_filter.downcase == 'true'
      # add the user token to bloom filter
      $bf_user.add(remember_token)
    end
    # set a variable "current_user" with the hash of the user
    self.current_user = user
  end

  # set a variable "current_user" with the hash of the user
  def current_user_hash=(user)
    @current_user_hash = user
  end

  # retrieve current_user hash variable
  def current_user_hash
    remember_token = cookies[:remember_token] || token
    @current_user_hash ||= user_authenticated?(remember_token)
  end

  # retrieve current_user hash variable
  def current_user
    @current_user ||= User.find(current_user_hash["_id"]["$oid"]) unless current_user_hash.nil?
  end

  def current_user=(user)
    @current_user = user
  end

  # check if user is signed in
  def signed_in?
    !self.current_user.nil?
  end

  # set a variable "token" with the token
  def token=(t)
    @token=t
  end

  # get the token passed by remote web interface from request in header or in parameters
  def token
    @token = request.headers[:Authorization] || params[:Authorization] if @token.nil?
    @token = @token.split[1] if @token.start_with?('Bearer ') unless @token.nil?
    @token
  end

  # check if user is authenticated using the token provided: if the token is correct, return the user hash
  # else return nil
  def user_authenticated?(remember_token)
    logger.debug("Application id: #{self.application_id}")
    logger.debug("Application id from session: #{session[:client_id]}")
    logger.debug("Remember token: #{remember_token}")
    checked_user = nil
    # first check if the token is correct and, if true, set the user hash in local variable "user_from_token"
    begin
      user_from_token = JSON.parse(JWT.decode(remember_token, self.application_id))
    rescue
      logger.debug('Token not correct')
      cookies.delete(:remember_token)
      user_from_token = nil
    end
    logger.debug("user_from_token: #{user_from_token}")
    # if the token syntax is correct, check if user is authenticated in bloom filter (in enabled)
    # then on Redis DB
    unless user_from_token.nil?
      if Settings.use_bloom_filter.downcase == 'true'
        logger.debug('Using bloom filter')
        # Code for the bloom filter
        if $bf_user.include?(remember_token)
          logger.debug('Bloom filter true')
          # we check the token on redis only if bloom filter return true, else the token is definitely incorrect
          checked_user = user_present_on_redis?(remember_token, user_from_token)
        end
      else
        logger.debug('Direct query on redis')
        # At the end, check if the token is valid on redis server
        checked_user = user_present_on_redis?(remember_token, user_from_token)
      end
    end

    checked_user
  end

  # check if a user is present (authenticated) on our redis server
  def user_present_on_redis?(remember_token, user_from_token)
    checked_user = nil
    # first we get the user id from redis server: if not present return nil
    user_id_from_redis = JSON.parse($redis_user.get(remember_token)) unless $redis_user.get(remember_token).nil?

    logger.debug("User_id from redis: #{user_id_from_redis}")
    logger.debug("User_from_token: #{user_from_token}")
    if user_from_token.nil? or user_from_token["_id"].nil? or user_from_token["_id"]["$oid"].nil? or user_from_token.blank? or user_from_token["_id"].blank? or user_from_token["_id"]["$oid"].blank?
      logger.error "User token params invalid: #{user_from_token.to_yaml}"
    else
      # check if the user id stored on redis is the same of the one in passed token
      if user_id_from_redis && user_from_token["_id"]["$oid"] == user_id_from_redis[0]
        checked_user = user_from_token
        if user_id_from_redis[1]
          $redis_user.expire(remember_token, Settings.token_expire)
        end
      end
    end
    checked_user
  end


  # Sign out the logged in user
  def sign_out
    current_user.delete_refresh_token
    $redis_user.del(:remember_token)
    cookies.delete(:remember_token)

    self.current_user = nil
  end

  # check if passed user is current user
  def current_user?(user)
    user == current_user
  end

  # if the user isn't signed in, store the requested page and redirect to login page
  def signed_in_user
    unless signed_in?
      # store the actual location in a session variable
      store_location
      redirect_to signin_url, notice: 'Please sign in.'
    end
  end

  # redirect back to page stored on session after a succesful login, if the user tried to visit a locked page without
  # a successful authentication first
  def redirect_back_or(default)
    redirect_to(session[:return_to] || default)
    session.delete(:return_to)
  end

  # store the actual location in a session variable
  def store_location
    session[:return_to] = request.url if request.get?
  end

  # store the application (external web interface) secret in a global variable
  def application_secret=(secret)
    @application_secret = secret
  end

  # get the application secret
  def application_secret
    if @application_secret.nil?
      if Settings.multi_application == 'false'
        @application_secret = Settings.single_application_mode_secret
      else
        @application_secret = App.find(self.application_id).secret
      end
    end

    @application_secret
  end

  # store the application id
  def application_id=(id)
    @application_id = id
  end

  # get the application id
  def application_id
    # If we are a multi_application
    if @application_id.nil?
      if Settings.multi_application.downcase == 'false'
        @application_id = Settings.single_application_mode_id
      else
        if session[:client_id].nil?
          if params[:client_id].nil? or params[:client_id].blank?
            @application_id = local_app_id
          else
            @application_id = params[:client_id]
          end
        else
          @application_id = session[:client_id]
        end
      end
    end

    @application_id
  end

  def local_app_id=(id)
    @local_app_id = id
  end

  def local_app_id
    if @local_app_id.nil?
      @local_app_id = App.where(name: Settings.local_app_name).first.id.to_s
    end
  end
end
