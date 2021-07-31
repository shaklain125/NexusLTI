module LtiUtils
  require_dependency "lti_utils/hash_helper"
  require_dependency "lti_utils/crypto_tool"
  require_dependency "lti_utils/lti_role"
  require_dependency 'lti_utils/token_validation'
  require_dependency 'lti_utils/cookie_helper'

  class << self
    def version
      'lti2p0'
    end
  end
end
