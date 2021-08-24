module LtiUtils
  module Token
    class << self
      def exists?(params)
        !get_token_param(params).nil?
      end

      def invalid?(params)
        # check if token is invalid
        token = LtiUtils.decrypt_json_token(get_token_param(params))
        token.empty?
      end

      def exists_and_valid?(params)
        exists?(params) && !invalid?(params)
      end

      def exists_and_invalid?(params)
        exists?(params) && invalid?(params)
      end

      ## Raise 3

      def raise_if_invalid(params)
        # raise if it contains token and is invalid
        raise LtiLaunch::Error, :invalid_lti_token if exists_and_invalid?(params)
      end

      def raise_if_missing(params)
        # raise if token missing
        raise LtiLaunch::Error, :missing_lti_token unless exists?(params)
      end

      def raise_if_exists(params)
        # raise if token exists
        raise LtiLaunch::Error, :invalid_lti_user if exists?(params)
      end
    end
  end
end
