module LtiUtils
  class LaunchHelper
    class << self
      def validate_launch(lti_message)
        tool = LtiTool.find_by_uuid(lti_message.oauth_consumer_key)

        return [nil, :invalid_request] unless tool

        auth_msg = LtiUtils.services.authenticate_message(
          lti_message.launch_url,
          lti_message.post_params,
          tool.shared_secret
        )
        return [tool, :invalid_signature] unless auth_msg

        return [tool, :invalid_nonce] if tool.lti_launches.where(nonce: lti_message.oauth_nonce).any?

        return [tool, :request_to_old] if DateTime.strptime(lti_message.oauth_timestamp, '%s') < 5.minutes.ago

        [tool, :valid]
      end

      def no_prefix_custom(params)
        prefix = 'custom_'
        params = params.map { |k, v| [k.starts_with?(prefix) ? k[prefix.length, k.length - 1] : k, v] }
        HashHelper.snake_case_symbolize(params)
      end

      def keys_in_custom?(custom, keys)
        keys.all? { |k| custom.key? k }
      end

      def required_custom_params(request)
        RHHelper.get_rh_caps_sym(request.url)
      end
    end
  end
end
