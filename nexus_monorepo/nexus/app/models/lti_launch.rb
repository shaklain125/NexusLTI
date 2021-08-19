class LtiLaunch < ActiveRecord::Base
  validates_presence_of :lti_tool_id, :nonce
  belongs_to :lti_tool
  serialize :message

  def self.check_launch!(lti_message)
    tool, msg = LtiUtils.check_launch(lti_message)
    raise Error, msg if msg != :valid
    tool.lti_launches.where('created_at > ?', 1.day.ago).delete_all
    tool.lti_launches.create(nonce: lti_message.oauth_nonce, message: lti_message.post_params)
  end

  def self.check_launch?(lti_message)
    LtiUtils.check_launch(lti_message)[1] == :valid
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
