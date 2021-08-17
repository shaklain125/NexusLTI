module LtiUtils
  class ToolProxyReg
    def initialize(reg_request, controller)
      @controller = controller
      @tool_consumer_profile = LtiUtils.services.get_tc_profile_from_tp_reg_service(reg_request)
    end

    def includes_split_secret?
      @tool_consumer_profile.capabilities_offered.include?('OAuth.splitSecret')
    end

    def tool_proxy
      unless @tool_proxy
        @tool_proxy ||= LtiUtils.models.all::ToolProxy.new(
          id: 'defined_by_tool_consumer',
          lti_version: LtiUtils.version,
          security_contract: security_contract,
          tool_consumer_profile: @tool_consumer_profile.id,
          tool_profile: tool_profile
        )
        @tool_proxy.enabled_capability ||= ['OAuth.splitSecret'] if includes_split_secret?
      end
      @tool_proxy
    end

    def security_contract
      return @security_contract if @security_contract
      p_attr = includes_split_secret? ? 'tp_half_shared_secret' : 'shared_secret'
      shared_secret = SecureRandom.hex(64)
      @security_contract = LtiUtils.models.all::SecurityContract.new("#{p_attr}": shared_secret)
    end

    def tool_profile
      @tool_profile ||= LtiUtils.models.all::ToolProfile.new(
        lti_version: LtiUtils.version,
        product_instance: product_instance,
        resource_handler: resource_handlers,
        base_url_choice: base_url_choice
      )
    end

    def product_instance
      return @product_instance if @product_instance
      product_instance_config = Rails.root.join('config', 'lti', 'product_instance.json')
      raise LtiRegistration::Error, :missing_product_instance unless File.exist? product_instance_config
      pr_json = File.read(product_instance_config)
      pr_json = JSON.parse(pr_json)
      pr_json.delete('$schema') if pr_json['$schema']
      @product_instance = LtiUtils.models.all::ProductInstance.new.from_json(pr_json)
    end

    def resource_handlers
      @resource_handlers ||= LTI_RESOURCE_HANDLERS.map do |rh|
        LtiUtils.models.all::ResourceHandler.from_json(
          {
            resource_type: { code: rh['code'] },
            resource_name: rh['name'],
            message: messages(rh['messages'])
          }
        )
      end
    end

    def base_url_choice
      [LtiUtils.models.all::BaseUrlChoice.new(default_base_url: @controller.request.base_url)]
    end

    def self.register(reg_obj, controller)
      tool_proxy = reg_obj.tool_proxy
      reg_req = reg_obj.registration_request

      registered_proxy = LtiUtils.services.register_tool_proxy(reg_req, tool_proxy)
      tool_proxy_guid = registered_proxy.tool_proxy_guid

      tool_proxy.id = controller.lti_show_tool_url(tool_proxy_guid)
      tool_proxy.tool_proxy_guid = tool_proxy_guid

      tp_sc = tool_proxy.security_contract
      tc_half_secret = registered_proxy.tc_half_shared_secret
      tp_sc_half_secret = tp_sc.tp_half_shared_secret
      tp_sc_secret = tp_sc.shared_secret

      shared_secret = tc_half_secret ? tc_half_secret + tp_sc_half_secret : tp_sc_secret

      tp = LtiTool.create!(
        uuid: tool_proxy_guid,
        shared_secret: shared_secret,
        tool_settings: tool_proxy.as_json,
        lti_version: tool_proxy.lti_version
      )

      reg_obj.update(lti_tool: tp)
    end

    def messages(messages)
      messages.map do |m|
        {
          message_type: m['type'],
          path: Rails.application.routes.url_for(
            only_path: true,
            host: @controller.request.host_with_port,
            controller: m['route']['controller'],
            action: m['route']['action']
          ),
          parameter: parameters(m['parameters'])
        }
      end
    end

    def parameters(params)
      (params || []).map do |p|
        LtiUtils.models.all::Parameter.new(p.symbolize_keys)
      end
    end

    private :messages, :parameters, :includes_split_secret?
  end
end
