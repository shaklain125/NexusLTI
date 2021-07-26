class LtiRegistrationController < ApplicationController
  include LtiHelper

  before_filter :registration_request, only: :register
  protect_from_forgery except: :save_capabilities
  after_filter :disable_xframe_header

  def register
    tcp = @registration.tool_consumer_profile
    tcp_url = tcp.id || @registration.registration_request.tc_profile_url

    exclude_cap = [
      IMS::LTI::Models::Messages::BasicLTILaunchRequest::MESSAGE_TYPE,
      IMS::LTI::Models::Messages::ToolProxyReregistrationRequest::MESSAGE_TYPE
    ]

    @capabilities = tcp.capability_offered.each_with_object({ placements: [], parameters: [] }) do |cap, hash|
      hash[:parameters] << cap unless exclude_cap.include? cap
    end

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
      actions = [*JSON.parse("{\"a\":#{v['actions']}}")['a']]
      IMS::LTI::Models::RestServiceProfile.new(service: v['id'], action: actions)
    end

    tool_proxy = registration.tool_proxy
    tool_profile = tool_proxy.tool_profile
    tool_proxy.security_contract.tool_service = tool_services if tool_services.present?
    tool_proxy.custom = nil

    rh = tool_profile.resource_handler.first
    mh = rh.message.first
    mh.parameter = parameters.map { |var, val| IMS::LTI::Models::Parameter.new(name: val['name'], variable: var) }
    rh.ext_placements = placements.keys
    mh.enabled_capability = placements.keys

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

  def show; end
end
