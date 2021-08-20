class LtiRegistrationController < ApplicationController
  include LtiRegHelper

  before_action :lti_reg_before
  skip_before_action :verify_authenticity_token, only: [:register, :save_capabilities]
  protect_from_forgery with: :null_session, only: [:auto_register]

  def register
    if LtiUtils::Session.https_session?(request) && session_exists?
      session[:lti_reg_token] = LtiUtils.encrypt_json({ reg_params: params })
      @registration = LtiUtils::RegHelper.create_reg_obj(params, self)
    else
      @registration = LtiUtils::RegHelper.create_and_save_reg_obj(params, self)
    end
    caps = LtiUtils::RegHelper.get_services_and_params(@registration)
    @capabilities = caps[:capabilities]
    @services_offered = caps[:services]
    @rh_list = LtiUtils::RHHelper.get_rh_name_path_list(@registration, self)
  end

  def auto_register
    reg = LtiUtils::RegHelper.create_reg_obj(params, self)
    LtiUtils::RegHelper.get_and_save_reg_caps(reg)
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
                      params[:reg_id] && !params[:reg_id].empty? ? LtiRegistration.find(params[:reg_id]) : nil
                    end

    raise LtiRegistration::Error, :failed_to_save_capabilities unless @registration

    LtiUtils::RHHelper.filter_out_and_reg_update_rh(params, @registration)

    LtiUtils::RegHelper.get_and_save_reg_caps(@registration)

    redirect_to(lti_submit_proxy_path(@registration.id))
  end

  def submit_proxy
    register_proxy(LtiRegistration.find(params[:reg_id]))
  end

  def show; end
end
