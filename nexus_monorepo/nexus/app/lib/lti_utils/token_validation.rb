module LtiUtils
  class << self
    def _get_token_param(params)
      params[:lti_token]
    end

    def contains_token_param(params)
      !_get_token_param(params).nil?
    end

    def contains_token_param_raise(params)
      # raise if token missing
      raise LtiLaunch::Unauthorized, :invalid unless contains_token_param(params)
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

    def get_tool_id(params)
      get_token(params)[:tool_id]
    end

    def get_user_id(params)
      get_token(params)[:user_id]
    end

    def get_token_ip(params)
      get_token(params)[:ip_addr]
    end

    def get_config(params)
      get_token(params)[:config]
    end

    def get_submission_token(params)
      get_token(params)[:submission]
    end

    def from_generator(params)
      !get_token(params)[:generator].nil?
    end

    def from_manage_assignment(params)
      !get_config(params).nil?
    end

    def from_submission(params)
      !get_submission_token(params).nil?
    end

    def update_user_id(params, id)
      get_token(params).merge({ user_id: id })
    end

    def update_merge_token(params, json)
      get_token(params).merge(json)
    end

    def update_and_set_token(params, cookies, session, json)
      params[:lti_token] = encrypt_json(update_merge_token(params, json))
      set_cookie_token(cookies, session, params[:lti_token])
    end

    def get_token(params)
      _token = _get_token_param(params)
      token = decrypt_json(_token)
      return {} if token.empty?
      token
    end

    def get_cookie_token(cookies, session)
      if session[:session_id] && cookies[:lti_token].nil?
        session[:lti_token]
      else
        cookies[:lti_token]
      end
    end

    def cookie_token_exists(cookies, session)
      !get_cookie_token(cookies, session).nil?
    end

    def delete_cookie_token(cookies, session)
      delete_lti_cookie(cookies, :lti_token) if cookie_token_exists(cookies, session)
    end

    def delete_cookie_token_not_session(cookies)
      delete_lti_cookie(cookies, :lti_token) unless cookies[:lti_token].nil?
    end

    def set_cookie_token(cookies, session, token_encrypted)
      if session[:session_id] && cookies[:lti_token].nil?
        session[:lti_token] = token_encrypted
      else
        set_lti_cookie(cookies, :lti_token, token_encrypted)
      end
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

    private :_get_token_param
  end
end
