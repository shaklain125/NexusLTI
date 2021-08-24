module LtiUtils
  class << self
    def token_exists?(params)
      !get_token_param(params).nil?
    end

    def invalid_token?(params)
      # check if token is invalid
      token = decrypt_json_token(get_token_param(params))
      return true if token.empty?
      false
    end

    def token_exists_and_valid?(params)
      token_exists?(params) && !invalid_token?(params)
    end

    def token_exists_and_invalid?(params)
      token_exists?(params) && invalid_token?(params)
    end

    ## Raise 3

    def raise_if_invalid_token(params)
      # raise if it contains token and is invalid
      raise LtiLaunch::Error, :invalid_lti_token if token_exists_and_invalid?(params)
      false
    end

    def raise_if_token_missing(params)
      # raise if token missing
      raise LtiLaunch::Error, :missing_lti_token unless token_exists?(params)
    end

    def raise_if_contains_token(params)
      # raise if token exists
      raise LtiLaunch::Error, :invalid_lti_user if token_exists?(params)
    end
  end
end
