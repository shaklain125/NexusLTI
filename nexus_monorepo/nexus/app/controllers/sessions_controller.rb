class SessionsController < Devise::SessionsController
  def create
    if LTI_DISABLE_DEVISE_NON_ADMIN_LOGIN
      u  = LtiUtils.invalidate_devise_non_admin_login(params)
      if u
        flash[:info] = 'Invalid email or password.'
        redirect_to new_user_session_path
        return
      end
    end
    super
  end
end
