module LtiUtils
  require_dependency 'lti_utils/controllers'

  require_dependency 'lti_utils/utils/hash_helper'
  require_dependency 'lti_utils/utils/uri_helper'
  require_dependency 'lti_utils/utils/cookie_helper'
  require_dependency 'lti_utils/utils/crypto_tool'

  require_dependency 'lti_utils/session/launch_helper'
  require_dependency 'lti_utils/session/lti_role'
  require_dependency 'lti_utils/session/session'
  require_dependency 'lti_utils/session/origin'
  require_dependency 'lti_utils/session/token'

  require_dependency 'lti_utils/shared/ims'
  require_dependency 'lti_utils/shared/rh_helper'
  require_dependency 'lti_utils/shared/error_handlers'

  require_dependency 'lti_utils/registration/reg_helper'
  require_dependency 'lti_utils/registration/tool_proxy_reg'
end
