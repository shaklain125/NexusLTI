class LtiLaunch < ActiveRecord::Base
  validates_presence_of :lti_tool_id, :nonce
  belongs_to :lti_tool
  serialize :message

  class << self
    def launch_validation(lti_message)
      LtiUtils::LaunchHelper.validate_launch(lti_message)
    end

    def check_launch!(lti_message)
      tool, msg = launch_validation(lti_message)
      raise Error, msg if msg != :valid
      tool.lti_launches.where('created_at > ?', 1.day.ago).delete_all
      tool.lti_launches.create(nonce: lti_message.oauth_nonce, message: lti_message.post_params)
    end

    def launch_valid?(lti_message)
      launch_validation(lti_message)[1] == :valid
    end

    private :launch_validation
  end

  def message
    LtiUtils.models.generate_message(read_attribute(:message))
  end

  class Error < StandardError
    attr_reader :error

    def initialize(error = :unknown)
      super
      @error = error
    end
  end
end
