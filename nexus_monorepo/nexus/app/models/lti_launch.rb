class LtiLaunch < ActiveRecord::Base
  validates_presence_of :lti_tool_id, :nonce
  belongs_to :lti_tool
  serialize :message

  def self.check_launch(lti_message)
    tool = LtiTool.find_by_uuid(lti_message.oauth_consumer_key)
    raise Unauthorized, :invalid_request unless tool
    raise Unauthorized, :invalid_signature unless IMS::LTI::Services::MessageAuthenticator.new(lti_message.launch_url, lti_message.post_params, tool.shared_secret)
    raise Unauthorized, :invalid_nonce if tool.lti_launches.where(nonce: lti_message.oauth_nonce).count > 0
    raise Unauthorized, :request_to_old if  DateTime.strptime(lti_message.oauth_timestamp, '%s') < 5.minutes.ago
    tool.lti_launches.where('created_at > ?', 1.day.ago).delete_all
    tool.lti_launches.create(nonce: lti_message.oauth_nonce, message: lti_message.post_params)
  end

  def message
    IMS::LTI::Models::Messages::Message.generate(read_attribute(:message))
  end

  class Unauthorized < StandardError
    attr_reader :error

    def initialize(error = :unknown)
      @error = error
    end
  end
end
