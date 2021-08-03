module LtiUtils
  class << self
    def services
      Services
    end

    def models
      Models
    end

    def services_all
      IMS::LTI::Services
    end

    def models_all
      IMS::LTI::Models
    end
  end

  class Services
    class << self
      def authenticate_message(launch_url, post_params, shared_secret)
        LtiUtils.services_all::MessageAuthenticator.new(launch_url, post_params, shared_secret)
      end

      def new_tp_reg_service(registration_request)
        LtiUtils.services_all::ToolProxyRegistrationService.new(registration_request)
      end
    end
  end

  class Models
    class << self
      def generate_message(request_parameters)
        LtiUtils.models_all::Messages::Message.generate(request_parameters)
      end
    end
  end
end
