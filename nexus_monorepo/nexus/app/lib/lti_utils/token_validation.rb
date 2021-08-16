module LtiUtils
  class << self
    def contains_token_param(params)
      !_get_token_param(params).nil?
    end

    def invalid_token(params)
      # check if token is invalid
      _token = _get_token_param(params)
      token = decrypt_json(_token)
      return true if token.empty?
      false
    end

    def cookie_token_exists(cookies, session)
      !get_cookie_token(cookies, session).nil?
    end

    ## Raise 3

    def invalid_token_raise(params)
      # raise if it contains token and is invalid
      contains_token = contains_token_param(params)
      invalid = invalid_token(params)
      raise LtiLaunch::Error, :invalid_lti_token if contains_token && invalid
      false
    end

    def contains_token_param_raise(params)
      # raise if token missing
      raise LtiLaunch::Error, :missing_lti_token unless contains_token_param(params)
    end

    def raise_if_contains_token(params)
      # raise if token exists
      raise LtiLaunch::Error, :invalid_lti_user if contains_token_param(params)
    end
  end
end
