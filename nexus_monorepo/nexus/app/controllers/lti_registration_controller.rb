class LtiRegistrationController < ApplicationController
  include LtiRegHelper

  before_action :lti_reg_before
  skip_before_action :verify_authenticity_token, only: [:register, :save_capabilities], if: :session_exists?
  protect_from_forgery only: [:auto_register]
  after_action :disable_xframe_header

  def lti_reg_before
    @is_lti = false
    @is_lti_error = false
    @is_lti_reg = true
  end

  def register
    interactive_registration
  end

  def auto_register
    auto_registration
  end

  def save_capabilities
    reg_token = session[:lti_reg_token]

    if reg_token
      reg_params = LtiUtils.decrypt_json(reg_token)[:reg_params]
      reg_params = LtiUtils::HashHelper.stringify(reg_params)
      reg_request(reg_params)
    end

    registration = if reg_token
                     session.delete(:lti_reg_token)
                     @registration
                   else
                     params["reg_id"].empty? ? nil : LtiRegistration.find(params["reg_id"])
                   end

    raise LtiRegistration::Error, :invalid unless registration

    parameters = params['variable_parameters'] ? params['variable_parameters'].select { |_, v| v['enabled'] } : {}
    services = params['service'] ? params['service'].select { |_, v| v['enabled'] } : {}

    save_caps(registration, services, parameters)

    redirect_to(lti_submit_proxy_path(registration.id))
  end

  def submit_proxy
    registration = LtiRegistration.find(params[:registration_uuid])
    # redirect_to_consumer(register_proxy(registration))
    register_proxy(registration)
    render_nexus_success_msg
  rescue IMS::LTI::Errors::ToolProxyRegistrationError => e
    @error = {
      tool_proxy_guid: registration.tool_proxy.tool_proxy_guid,
      response_status: e.response_status,
      response_body: e.response_body
    }
  end

  def show; end
end
