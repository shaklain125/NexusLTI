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
    @tool_consumer_profile ||= LtiUtils.services.get_tc_profile!(registration_request)
  end

  def self.clean_up!
    all.each do |reg|
      reg.destroy if reg.lti_tool.nil?
    end
  end

  class Error < StandardError
    attr_reader :error

    def initialize(error = :unknown)
      super
      @error = error
    end
  end
end
