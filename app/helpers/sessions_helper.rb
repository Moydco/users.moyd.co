# In SessionHelper there are all methods for Views and Controllers (check the include in application_helper.rb)
# useful for User Autentication
module SessionsHelper

  # Sign in the user
  def sign_in(user)
    # update timestamp and IP address
    user = user.touch_login(request.remote_ip)
    # create the token and in store it on our Redis DB
    remember_token = user.store_user_session_in_redis(self.application_secret)

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
  def current_user=(user)
    @current_user = user
  end

  # retrieve current_user variable
  def current_user
    remember_token = cookies[:remember_token] || token
    @current_user ||= user_authenticated?(remember_token)
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
    if @token.nil?
      if Settings.parameters_by_header.downcase == 'true'
        @token = request.headers[Settings.token_name]
      else
        @token = params[Settings.token_name]
      end
    end

    @token
  end

  # check if user is authenticated using the token provided: if the token is correct, return the user hash
  # else return nil
  def user_authenticated?(remember_token)
    logger.debug("Application secret: #{self.application_secret}")
    logger.debug("Remember token: #{remember_token}")
    checked_user = nil
    # first check if the token is correct and, if true, set the user hash in local variable "user_from_token"
    begin
      user_from_token = JSON.parse(JWT.decode(remember_token, self.application_secret))
    rescue
      logger.debug("Token not correct")
      cookies.delete(:remember_token)
      user_from_token = nil
    end
    logger.debug("user_from_token: #{user_from_token}")
    # if the token syntax is correct, check if user is authenticated in bloom filter (in enabled)
    # then on Redis DB
    unless user_from_token.nil?
      if Settings.use_bloom_filter.downcase == 'true'
        logger.debug("Using bloom filter")
        # Code for the bloom filter
        if $bf_user.include?(remember_token)
          logger.debug('Bloom filter true')
          # we check the token on redis only if bloom filter return true, else the token is definitely incorrect
          checked_user = user_present_on_redis?(remember_token, user_from_token)
        end
      else
        logger.debug("Direct query on redis")
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
    user_id_from_redis = $redis_user.get(remember_token)

    logger.debug("User_id from redis: #{user_id_from_redis}")
    logger.debug("User_from_token: #{user_from_token}")
    if user_from_token.nil? or user_from_token["_id"].nil? or user_from_token["_id"]["$oid"].nil? or user_from_token.blank? or user_from_token["_id"].blank? or user_from_token["_id"]["$oid"].blank?
      logger.error "User token params invalid: #{user_from_token.to_yaml}"
    else
      # check if the user id stored on redis is the same of the one in passed token
      if user_id_from_redis && user_from_token["_id"]["$oid"] == user_id_from_redis
        # If is correct, return the user hash and update session expiration on redis
        checked_user = user_from_token
        # Renew the expire in Redis
        $redis_user.expire(token, Settings.session_expire)
      end
    end
    checked_user
  end

  # store the application (external web interface) secret in a global variable
  def application_secret=(secret)
    @application_secret = secret
  end

  # get the application secret
  def application_secret
    if @application_secret.nil?
      # If we aren't a multi_application
      if self.application_id.nil? && Settings.multi_application.downcase == 'false'
        @application_secret = Settings.single_application_mode_secret
      else
        # check for an appllication id/secret in Redis cache
        @application_secret = $redis_application.get(self.application_id)
        # If we don't have the data in our Redis Cache check it in persistent DB
        if @application_secret.nil?
          @application_secret = Application.find(self.application_id).secret
          unless @application_secret.nil?
            # if we found the secret, cache it in our Redis DB
            $redis_application.set(self.application_id,@application_secret)
          end
        end
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
    if @application_id.nil? && Settings.multi_application.downcase == 'true'
      if Settings.parameters_by_header.downcase == 'true'
        # check the header
        @application_id = request.headers[Settings.application_name]
      else
        # If we haven't an application_id header, check in parameters
        @application_id = params[Settings.application_name]
      end
    end

    @application_id
  end

  # Sign out the logged in user
  def sign_out
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
      redirect_to signin_url, notice: "Please sign in."
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

end
