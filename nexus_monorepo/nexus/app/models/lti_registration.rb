class LtiRegistration < ActiveRecord::Base
  serialize :tool_proxy_json, JSON
  serialize :registration_request_params, JSON
  belongs_to :lti_tool

  def registration_request
    @registration_request ||= LtiUtils.models.generate_message(registration_request_params)
  end

  def tool_proxy
    LtiUtils.models.get_tool_proxy_from_json(tool_proxy_json)
  end

  def tool_consumer_profile
    @tool_consumer_profile ||= LtiUtils.services.get_tc_profile_from_tp_reg_service(registration_request)
  end

  class Error < StandardError
    attr_reader :error

    def initialize(error = :unknown)
      super
      @error = error
    end
  end
end
