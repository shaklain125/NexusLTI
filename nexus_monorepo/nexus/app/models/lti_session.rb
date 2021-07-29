class LtiSession < ActiveRecord::Base
  belongs_to :lti_tool
  belongs_to :user
end
