class LtiRegistration < ActiveRecord::Base
  validates :correlation_id, uniqueness: true, allow_nil: true
  serialize :tool_proxy_json, JSON
  serialize :registration_request_params, JSON
  belongs_to :lti_tool

  def register; end

  def registration_request
    @registration_request ||= IMS::LTI::Models::Messages::Message.generate(registration_request_params)
  end

  def tool_proxy
    IMS::LTI::Models::ToolProxy.from_json(tool_proxy_json)
  end

  def tool_consumer_profile
    @tool_consumer_profile ||= IMS::LTI::Services::ToolProxyRegistrationService.new(registration_request).tool_consumer_profile
  end
end
