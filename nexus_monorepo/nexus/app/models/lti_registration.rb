class LtiRegistration < ActiveRecord::Base
  validates :correlation_id, uniqueness: true, allow_nil: true
  serialize :tool_proxy_json, JSON
  serialize :registration_request_params, JSON
  belongs_to :lti_tool

  def registration_request
    @registration_request ||= LtiUtils.models_all::Messages::Message.generate(registration_request_params)
  end

  def tool_proxy
    LtiUtils.models_all::ToolProxy.from_json(tool_proxy_json)
  end

  def tool_consumer_profile
    @tool_consumer_profile ||= LtiUtils.services.new_tp_reg_service(registration_request).tool_consumer_profile
  end

  class Error < StandardError
    attr_reader :error

    def initialize(error = :unknown)
      super
      @error = error
    end
  end
end
