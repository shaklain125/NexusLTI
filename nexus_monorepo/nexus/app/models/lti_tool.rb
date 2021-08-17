class LtiTool < ActiveRecord::Base
  validates_presence_of :shared_secret, :uuid, :tool_settings, :lti_version
  serialize :tool_settings
  has_many :lti_launches, dependent: :destroy
  has_many :lti_registrations, dependent: :destroy
  has_many :lti_sessions, dependent: :destroy

  def tool_proxy
    LtiUtils.models.get_tool_proxy_from_json(tool_settings)
  end

  def self.clean_up!
    all.each do |tool|
      tc_profile_url = tool.tool_proxy.tool_consumer_profile
      tc_profile_exists = LtiUtils.services.tc_profile_exists?(tc_profile_url)
      tool.destroy unless tc_profile_exists
    end
  end
end
