module LtiUtils
  class << self
    def contains_token_param(params)
      !_get_token_param(params).nil?
    end

    def contains_token_param_raise(params)
      # raise if token missing
      raise LtiLaunch::Unauthorized, :invalid unless contains_token_param(params)
    end

    def invalid_token(params)
      _token = _get_token_param(params)
      token = decrypt_json(_token)
      return true if token.empty?
      false
    end

    def invalid_token_raise(params)
      # raise if it contains token and is invalid
      contains_token = contains_token_param(params)
      invalid = invalid_token(params)
      raise LtiLaunch::Unauthorized, :invalid if contains_token && invalid
      false
    end

    def raise_if_contains_token(params)
      raise LtiLaunch::Unauthorized, :invalid if contains_token_param(params)
    end

    def raise_if_session_cookie_check_and_lti(cookies, session, request, params)
      id = session[:session_id]
      session_token = session[:lti_token]
      cookies_token = cookies[:lti_token]

      is_https = request.ssl?

      is_https_session = https_session_enabled && is_https
      is_http_session = http_session_enabled && !is_https

      is_https_session_valid = id && !session_token.nil? && cookies_token.nil?
      is_http_session_valid = ((id && session_token.nil?) || !id) && !cookies_token.nil?

      https_valid = (is_https_session && is_https_session_valid)
      http_valid = (is_http_session && is_http_session_valid)

      # raise LtiLaunch::Unauthorized, :invalid if id && contains_token_param(params)

      is_valid_session = (https_valid || http_valid)

      delete_cookie_token_not_session(cookies) if !http_valid || https_valid

      raise LtiLaunch::Unauthorized, :invalid if contains_token_param(params) && !is_valid_session
    end

    def raise_if_not_cookie_token_present_and_lti(cookies, session)
      raise LtiLaunch::Unauthorized, :invalid unless cookie_token_exists(cookies, session)
    end

    def cookie_token_exists(cookies, session)
      !get_cookie_token(cookies, session).nil?
    end
  end
end
