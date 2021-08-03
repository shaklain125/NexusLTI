class LtiToolProxyRegistration
  attr_reader :tool_consumer_profile, :registration_state, :return_url

  attr_writer :shared_secret, :tool_proxy, :tool_profile, :security_contract, :product_instance, :resource_handlers

  def initialize(registration_request, controller)
    @controller = controller
    @return_url = registration_request.launch_presentation_return_url
    @registration_service = LtiUtils.services.new_tp_reg_service(registration_request)
    @tool_consumer_profile = @registration_service.tool_consumer_profile
    @registration_state = :not_registered
  end

  def shared_secret
    @shared_secret ||= SecureRandom.hex(64)
  end

  def tool_proxy
    unless @tool_proxy
      @tool_proxy ||= LtiUtils.models_all::ToolProxy.new(
        id: 'defined_by_tool_consumer',
        lti_version: 'LTI-2p0',
        security_contract: security_contract,
        tool_consumer_profile: tool_consumer_profile.id,
        tool_profile: tool_profile
      )
      if @tool_consumer_profile.capabilities_offered.include?('OAuth.splitSecret')
        @tool_proxy.enabled_capability ||= []
        @tool_proxy.enabled_capability << 'OAuth.splitSecret'
      end
    end
    @tool_proxy
  end

  def tool_profile
    @tool_profile ||= LtiUtils.models_all::ToolProfile.new(
      lti_version: 'LTI-2p0',
      product_instance: product_instance,
      resource_handler: resource_handlers,
      base_url_choice: base_url_choice
    )
  end

  def base_url_choice
    [LtiUtils.models_all::BaseUrlChoice.new(default_base_url: @controller.request.base_url)]
  end

  def product_instance
    unless @product_instance
      product_instance_config = Rails.root.join('config', 'lti', 'product_instance.json')
      raise LtiRegistration::Error, :missing_product_instance unless File.exist? product_instance_config
      @product_instance = LtiUtils.models_all::ProductInstance.new.from_json(File.read(product_instance_config))
    end
  end

  def security_contract
    if @security_contract
      @security_contract
    else
      @security_contract = if @tool_consumer_profile.capabilities_offered.include?('OAuth.splitSecret')
                             LtiUtils.models_all::SecurityContract.new(tp_half_shared_secret: shared_secret)
                           else
                             LtiUtils.models_all::SecurityContract.new(shared_secret: shared_secret)
                           end
    end
  end

  def self.register(registration, controller)
    registration_request = registration.registration_request

    raise LtiRegistration::Error, :already_registered if registration.workflow_state == :registered

    registration_service = LtiUtils.services.new_tp_reg_service(registration_request)
    tool_proxy = registration.tool_proxy
    return_url = registration.registration_request.launch_presentation_return_url

    registered_proxy = registration_service.register_tool_proxy(tool_proxy)
    tool_proxy.tool_proxy_guid = registered_proxy.tool_proxy_guid
    tool_proxy.id = controller.lti_show_tool_url(registered_proxy.tool_proxy_guid)

    tc_half_secret = registered_proxy.tc_half_shared_secret
    tp_sc_half_secret = tool_proxy.security_contract.tp_half_shared_secret
    tp_sc_secret = tool_proxy.security_contract.shared_secret

    shared_secret = tc_half_secret ? tc_half_secret + tp_sc_half_secret : tp_sc_secret

    tp = LtiTool.create!(shared_secret: shared_secret, uuid: registered_proxy.tool_proxy_guid, tool_settings: tool_proxy.as_json, lti_version: tool_proxy.lti_version)

    registration.update(workflow_state: 'registered', lti_tool: tp)

    {
      tool_proxy_uuid: tool_proxy.tool_proxy_guid,
      return_url: return_url,
      status: 'success'
    }
  end

  def resource_handlers
    @resource_handlers ||= LTI_RESOURCE_HANDLERS.map do |handler|
      LtiUtils.models_all::ResourceHandler.from_json(
        {
          resource_type: { code: handler['code'] },
          resource_name: handler['name'],
          message: messages(handler['messages'])
        }
      )
    end
  end

  private

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
        parameter: parameters(m['parameters']),
        enabled_capability: capabilities(m)
      }
    end
  end

  def parameters(params)
    (params || []).map do |p|
      LtiUtils.models_all::Parameter.new(p.symbolize_keys)
    end
  end

  def capabilities(message)
    req_capabilities = message['required_capabilities'] || []
    opt_capabilities = message['optional_capabilities'] || []
    raise LtiRegistration::Error, :unsupported_capabilities_error unless (req_capabilities - (tool_consumer_profile.capability_offered || [])).empty?
    req_capabilities + opt_capabilities
  end
end
