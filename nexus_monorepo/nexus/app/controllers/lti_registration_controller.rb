class LtiRegistrationController < ApplicationController
  include LtiRegHelper

  before_action :lti_reg_before
  skip_before_action :verify_authenticity_token, only: [:register, :save_capabilities], if: :session_exists?
  protect_from_forgery only: [:auto_register]
  after_action :disable_xframe_header

  def register
    if session_exists?
      session[:lti_reg_token] = LtiUtils.encrypt_json({ reg_params: params })
      @registration = LtiUtils::RegHelper.create_reg_obj(params, self)
    else
      @registration = LtiUtils::RegHelper.create_and_save_reg_obj(params, self)
    end
    caps = LtiUtils::RegHelper.get_services_and_params(@registration)
    @capabilities = caps[:capabilities]
    @services_offered = caps[:services]
  end

  def auto_register
    reg = LtiUtils::RegHelper.create_reg_obj(params, self)
    caps = LtiUtils::RegHelper.get_services_and_params(reg)
    caps = LtiUtils::RegHelper.auto_reg_format_caps(caps[:services], caps[:capabilities][:parameters])
    LtiUtils::RegHelper.save_services_and_params(reg, caps[:services], caps[:parameters])
    register_proxy(reg)
  end

  def save_capabilities
    reg_token = session[:lti_reg_token]

    if reg_token
      reg_params = LtiUtils.decrypt_json(reg_token)[:reg_params]
      reg_params = LtiUtils::HashHelper.stringify(reg_params)
      @registration = LtiUtils::RegHelper.create_and_save_reg_obj(reg_params, self)
    end

    @registration = if reg_token
                      session.delete(:lti_reg_token)
                      @registration
                    else
                      params['reg_id'].empty? ? nil : LtiRegistration.find(params['reg_id'])
                    end

    raise LtiRegistration::Error, :failed_to_save_capabilities unless @registration

    parameters = params['variable_parameters'] ? params['variable_parameters'].select { |_, v| v['enabled'] } : {}
    services = params['service'] ? params['service'].select { |_, v| v['enabled'] } : {}

    LtiUtils::RegHelper.save_services_and_params(@registration, services, parameters)

    redirect_to(lti_submit_proxy_path(@registration.id))
  end

  def submit_proxy
    register_proxy(LtiRegistration.find(params[:reg_id]))
  end

  def show; end
end
