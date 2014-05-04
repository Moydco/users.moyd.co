module SessionsHelper
  def sign_in(user)
    user = user.touch_login(request.remote_ip)
    remember_token = user.store_user_session_in_redis(self.application_secret)

    cookies.permanent[:remember_token] = remember_token
    self.token = remember_token

    if Settings.use_bloom_filter.downcase == 'true'
      # add the user token to bloom filter
      $bf_user.add(remember_token)
    end
    self.current_user = user
  end

  def current_user=(user)
    @current_user = user
  end

  def current_user
    remember_token = cookies[:remember_token] || token
    @current_user ||= auth_user(remember_token)
  end

  def signed_in?
    !self.current_user.nil?
  end

  def token=(t)
    @token=t
  end

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

  def auth_user(remember_token)
    logger.debug("Application secret: #{self.application_secret}")
    logger.debug("Remember token: #{remember_token}")
    checked_user = nil

    begin
      user_from_token = JSON.parse(JWT.decode(remember_token, self.application_secret))
    rescue
      cookies.delete(:remember_token)
      user_from_token = nil
    end
    logger.debug("user_from_token: #{user_from_token}")
    unless user_from_token.nil?
      if Settings.use_bloom_filter.downcase == 'true'
        logger.debug("Using bloom filter")
        # Code for the bloom filter
        if $bf_user.include?(remember_token)
          logger.debug('Bloom filter true')
          # we check the token on redis only if bloom filter return true, else the token is definitely incorrect
          checked_user = check_token_on_redis(remember_token, user_from_token)
        end
      else
        logger.debug("Direct query on redis")
        # At the end, check if the token is valid on redis server
        checked_user = check_token_on_redis(remember_token, user_from_token)
      end
    end

    checked_user
  end

  def check_token_on_redis(remember_token, user_from_token)

    checked_user = nil

    user_id_from_redis = $redis_user.get(remember_token)

    if user_from_token["_id"]["$oid"] == user_id_from_redis
      checked_user = user_from_token
      # Renew the expire in Redis
      $redis_user.expire(token, Settings.session_expire)
    end

    checked_user
  end

  def application_secret=(secret)
    @application_secret = secret
  end

  def application_secret
    if @application_secret.nil?
      # If we are a multi_application
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

  def application_id=(id)
    @application_id = id
  end

  def application_id
    if @application_id.nil?
      if Settings.multi_application.downcase == 'true'
        # check the presence if application_id in header only if we permit that
        @application_id = request.headers[Settings.application_name]
      else
        # If we haven't an application_id header, check in parameters
        @application_id = params[Settings.application_name]
      end
    end

    @application_id
  end

  def sign_out
    $redis_user.del(token)
    cookies.delete(:remember_token)
    self.current_user = nil
  end

end
