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
    if session_exists?
      session[:lti_reg_token] = LtiUtils.encrypt_json({ reg_params: params })
      @registration = LtiUtils.create_reg_obj(params, self)
    else
      @registration = LtiUtils.create_and_save_reg_obj(params, self)
    end
    caps = LtiUtils.get_services_and_params(@registration)
    @capabilities = caps[:capabilities]
    @services_offered = caps[:services]
  end

  def auto_register
    reg = LtiUtils.create_reg_obj(params, self)
    caps = LtiUtils.get_services_and_params(reg)
    caps = LtiUtils.auto_reg_format_caps(caps[:services], caps[:capabilities][:parameters])
    LtiUtils.save_services_and_params(reg, caps[:services], caps[:parameters])
    register_proxy(reg)
  end

  def save_capabilities
    reg_token = session[:lti_reg_token]

    if reg_token
      reg_params = LtiUtils.decrypt_json(reg_token)[:reg_params]
      reg_params = LtiUtils::HashHelper.stringify(reg_params)
      @registration = LtiUtils.create_and_save_reg_obj(reg_params, self)
    end

    @registration = if reg_token
                      session.delete(:lti_reg_token)
                      @registration
                    else
                      params["reg_id"].empty? ? nil : LtiRegistration.find(params["reg_id"])
                    end

    raise LtiRegistration::Error, :invalid unless  @registration

    parameters = params['variable_parameters'] ? params['variable_parameters'].select { |_, v| v['enabled'] } : {}
    services = params['service'] ? params['service'].select { |_, v| v['enabled'] } : {}

    LtiUtils.save_services_and_params(@registration, services, parameters)

    redirect_to(lti_submit_proxy_path(@registration.id))
  end

  def submit_proxy
    register_proxy(LtiRegistration.find(params[:registration_uuid]))
  end

  def show; end
end
