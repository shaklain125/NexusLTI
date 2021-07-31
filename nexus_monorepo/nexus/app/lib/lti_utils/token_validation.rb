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

    def raise_if_null_referrer_and_lti(request, params)
      referrer = request.referrer
      raise LtiLaunch::Unauthorized, :invalid if !referrer && contains_token_param(params)
    end

    def raise_if_session_and_lti(session, params)
      id = session[:session_id]
      raise LtiLaunch::Unauthorized, :invalid if id && contains_token_param(params)
    end

    def raise_if_not_cookie_token_present_and_lti(cookies)
      raise LtiLaunch::Unauthorized, :invalid unless LtiUtils.cookie_token_exists(cookies)
    end

    def check_if_referrer_is_not_lms(request, params)
      referrer = request.referrer
      origin = request.headers['origin']
      return false if !referrer || !origin
      valid_referrers = [
        '192.168.1.81'
      ]
      referer_valid = check_host(referrer, valid_referrers)
      origin_valid = check_host(origin, valid_referrers)
      valid = referer_valid && origin_valid
      return false if !valid && contains_token_param(params)
      true
    end

    def http_referer_uri(request)
      request.env["HTTP_REFERER"] && URI.parse(request.env["HTTP_REFERER"])
    end

    def check_host(url, hostnames)
      hostnames.include?(get_host(url))
    end

    def get_host(uri)
      return nil unless uri
      begin
        Uri.parse(uri).host
      rescue StandardError
        nil
      end
    end

    def raise_if_referrer_is_not_lms(request, params)
      raise LtiLaunch::Unauthorized, :invalid if check_if_referrer_is_not_lms(request, params)
    end

    def get_tool_id(params)
      get_token(params)[:tool_id]
    end

    def get_user_id(params)
      get_token(params)[:user_id]
    end

    def update_user_id(params, id)
      get_token(params).merge({ user_id: id })
    end

    def get_token(params)
      _token = _get_token_param(params)
      token = decrypt_json(_token)
      return {} if token.empty?
      token
    end

    def get_cookie_token(cookies)
      cookies[:lti_token]
    end

    def cookie_token_exists(cookies)
      !get_cookie_token(cookies).nil?
    end

    def delete_cookie_token(cookies)
      delete_lti_cookie(cookies, :lti_token) if cookie_token_exists(cookies)
    end

    def set_cookie_token(cookies, token_encrypted)
      set_lti_cookie(cookies, :lti_token, token_encrypted)
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
