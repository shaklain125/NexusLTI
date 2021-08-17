require 'ims/lti'
require 'ims/lis'

module LtiUtils
  class << self
    def services
      Services
    end

    def models
      Models
    end

    def errors
      Errors
    end

    def version
      models.all::LTIModel::LTI_VERSION_2P0
    end
  end

  LTI = IMS::LTI
  LIS = IMS::LIS

  class Errors
    class << self
      def all
        LTI::Errors
      end
    end
  end

  class Roles
    class << self
      def roles_json
        roles = LIS::Roles::Context::Handles
        constants = roles.constants.map { |c| [c, roles.const_get(c)]  }
        HashHelper.snake_case_symbolize(constants)
      end

      def system_roles_json
        prefix = 'http://purl.imsglobal.org/vocab/lis/v2/person'
        roles = {
          SysAdmin: "#{prefix}#SysAdmin",
          SysSupport: "#{prefix}#SysSupport",
          Creator: "#{prefix}#Creator",
          AccountAdmin: "#{prefix}#AccountAdmin",
          User: "#{prefix}#User",
          Administrator: "#{prefix}#Administrator",
          None: "#{prefix}#None"
        }
        HashHelper.snake_case_symbolize(roles)
      end
    end
  end

  class Services
    class << self
      def all
        LTI::Services
      end

      def authenticate_message(launch_url, post_params, shared_secret)
        all::MessageAuthenticator.new(launch_url, post_params, shared_secret)
      end

      def new_tp_reg_service(registration_request)
        all::ToolProxyRegistrationService.new(registration_request)
      end

      def get_tc_profile_from_tp_reg_service(registration_request)
        new_tp_reg_service(registration_request).tool_consumer_profile
      end

      def register_tool_proxy(registration_request, tool_proxy)
        new_tp_reg_service(registration_request).register_tool_proxy(tool_proxy)
      end

      def tc_profile_exists?(tc_profile_url)
        !Faraday.new.get(tc_profile_url).body.empty?
      rescue StandardError
        false
      end
    end
  end

  class Models
    class << self
      def all
        LTI::Models
      end

      def generate_message(request_parameters)
        all::Messages::Message.generate(request_parameters)
      end

      def parsed_lti_message(request)
        lti_message = generate_message(request.request_parameters)
        lti_message.launch_url = request.url
        lti_message
      end

      def get_tool_proxy_from_json(json)
        all::ToolProxy.from_json(json)
      end
    end
  end

  private_constant :LTI, :LIS, :Services, :Models, :Errors
end
