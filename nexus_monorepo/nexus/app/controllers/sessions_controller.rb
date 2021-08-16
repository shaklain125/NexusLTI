class SessionsController < Devise::SessionsController
  def create
    if LtiUtils::Session.invalidate_devise_non_admin_login(params)
      flash[:info] = 'Invalid email or password.'
      redirect_to new_user_session_path
      return
    end
    super
  end
end
