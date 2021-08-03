module LtiUtils
  require_dependency "lti_utils/hash_helper"
  require_dependency "lti_utils/crypto_tool"
  require_dependency "lti_utils/lti_role"
  require_dependency 'lti_utils/token_validation'
  require_dependency 'lti_utils/cookie_helper'
  require_dependency 'lti_utils/uri_helper'
  require_dependency 'lti_utils/origin_checker'
  require_dependency 'lti_utils/token_io'
  require_dependency 'lti_utils/ims_helper'

  class << self
    def version
      'lti2p0'
    end

    def https_session_enabled
      LTI_HTTPS_SESSION
    end

    def http_session_enabled
      LTI_HTTP_SESSION
    end
  end
end
