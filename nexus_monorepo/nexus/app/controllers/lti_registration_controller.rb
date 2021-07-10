class LtiRegistrationController < ApplicationController
  include LtiControllerHelpers

  before_filter :registration_request, only: :register
  before_filter :lti_authentication, only: :register, if: :reregistration?
  protect_from_forgery except: :save_capabilities
  after_filter :disable_xframe_header

  def register
    # tool_setting_service = %w(LtiLink.custom.url ToolProxyBinding.custom.url ToolProxy.custom.url)
    filter_out = [
      IMS::LTI::Models::Messages::BasicLTILaunchRequest::MESSAGE_TYPE,
      IMS::LTI::Models::Messages::ToolProxyReregistrationRequest::MESSAGE_TYPE
    ]
    tcp = @registration.tool_consumer_profile
    @capabilities = tcp.capability_offered.each_with_object({ placements: [], parameters: [] }) do |cap, hash|
      hash[:parameters] << cap unless filter_out.include? cap
    end
    tcp_url = tcp.id || @registration.registration_request.tc_profile_url
    @services_offered = tcp.services_offered.each_with_object([]) do |service, col|
      next if service.id.include? 'ToolProxy.collection'
      name = service.id.split(':').last.split('#').last
      col << {
        name: name,
        service: "#{tcp_url}##{name}",
        actions: service.actions
      }
    end
  end

  def save_capabilities
    registration = LtiRegistration.find(params["reg_id"])
    parameters = params['variable_parameters'] ? params['variable_parameters'].select { |_, v| v['enabled'] } : {}
    placements = params['placements'] ? params['placements'].select { |_, v| v['enabled'] } : {}
    services = params['service'] ? params['service'].select { |_, v| v['enabled'] } : {}
    tool_services = services.map do |_, v|
      # The JSON could be a single element or an array, we want to force it to an array
      actions = [*JSON.parse("{\"a\":#{v['actions']}}")['a']]
      IMS::LTI::Models::RestServiceProfile.new(service: v['id'], action: actions)
    end
    tool_settings = (params['tool_settings'].present? && JSON.parse(params['tool_settings'])) || nil
    tool_proxy = registration.tool_proxy
    tool_profile = tool_proxy.tool_profile
    add_reregistration_handler!(registration, tool_profile)
    tool_proxy.security_contract.tool_service = tool_services if tool_services.present?
    rh = tool_profile.resource_handler.first
    mh = rh.message.first
    mh.parameter = parameters.map { |var, val| IMS::LTI::Models::Parameter.new(name: val['name'], variable: var) }
    rh.ext_placements = placements.keys
    mh.enabled_capability = placements.keys
    tool_proxy.custom = tool_settings if tool_settings
    registration.update(tool_proxy_json: tool_proxy.to_json)

    redirect_to(lti_submit_proxy_path(registration.id))
  end

  def submit_proxy
    registration = LtiRegistration.find(params[:registration_uuid])
    redirect_to_consumer(register_proxy(registration))
  rescue IMS::LTI::Errors::ToolProxyRegistrationError => e
    @error = {
      tool_proxy_guid: registration.tool_proxy.tool_proxy_guid,
      response_status: e.response_status,
      response_body: e.response_body
    }
  end

  def add_reregistration_handler!(registration, tool_profile)
    if registration.tool_consumer_profile.capability_offered.include?(IMS::LTI::Models::Messages::ToolProxyReregistrationRequest::MESSAGE_TYPE)
      rereg_mh = IMS::LTI::Models::MessageHandler.new(
        message_type: IMS::LTI::Models::Messages::ToolProxyReregistrationRequest::MESSAGE_TYPE,
        path: lti_reregistration_path
      )
      tool_profile.message = [rereg_mh]
    end
  end

  protected

  def reregistration?
    params[:lti_message_type] == IMS::LTI::Models::Messages::ToolProxyReregistrationRequest::MESSAGE_TYPE
  end

  def show; end

  def apply_rereg
    tool = LtiTool.where(uuid: params[:tool_proxy_guid]).first
    registration = tool.registrations.where(correlation_id: params[:correlation_id]).first
    render status: :not_found and return unless registration
    tool_proxy = tool.tool_proxy
    registered_proxy = registration.tool_proxy
    shared_secret = if tc_secret = registered_proxy.tc_half_shared_secret
                      tc_secret + tool_proxy.security_contract.tp_half_shared_secret
                    else
                      tool_proxy.security_contract.shared_secret
                    end
    tool.transaction do
      tool.shared_secret = shared_secret
      tool.tool_settings = registered_proxy.as_json
      tool.lti_version = registered_proxy.lti_version
      tool.save!
      registration.update!(workflow_state: 'registered')
    end
    render nothing: true
  end

  def delete_rereg
    tool = LtiTool.where(uuid: params[:tool_proxy_guid]).first
    registration = tool.registrations.where(correlation_id: params[:correlation_id]).first
    render status: :not_found and return unless registration
    registration.delete!
  end
end
