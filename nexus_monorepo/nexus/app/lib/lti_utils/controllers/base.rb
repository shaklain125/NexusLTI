module LtiUtils::Controllers
  class Base < ActionController::Base
    include LtiHelper

    protect_from_forgery with: :null_session

    before_action :lti_auth
    skip_before_action :verify_authenticity_token, if: :lti_request?
    after_action :disable_xframe_header_lti
    rescue_from LtiLaunch::Error, with: :handle_lti_error
    rescue_from LtiRegistration::Error, with: :handle_lti_reg_error

    def redirect_to(*args, **kwargs)
      LtiUtils::Session.http_flash(self)
      super(*args, **kwargs)
    end

    protected

    def authenticate_user!
      return if current_user && LtiUtils.token_exists?(params)
      super
    end

    def devise_current_user
      @devise_current_user ||= warden.authenticate(scope: :user)
    end

    def current_user
      return LtiUtils::Session.get_current_user(params) unless LtiUtils.invalid_token?(params)
      if devise_current_user && (@is_lti_reg || @is_lti_reg_error)
        sign_out(devise_current_user)
        return nil
      end
      devise_current_user
    end
  end
end
