class LtiTool < ActiveRecord::Base
  validates_presence_of :shared_secret, :uuid, :tool_settings, :lti_version
  serialize :tool_settings
  has_many :lti_launches
  has_many :lti_registrations

  def tool_proxy
    LtiUtils.models_all::ToolProxy.from_json(tool_settings)
  end
end
