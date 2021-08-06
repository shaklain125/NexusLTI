module LtiUtils
  class << self
    def create_teacher(email, name)
      u = User.find_by_email(email)
      u ||= User.create(email: email,
                        password: '12345678',
                        password_confirmation: '12345678',
                        name: name,
                        admin: true)
      u
    end

    def create_student(email, name)
      u = User.find_by_email(email)
      u ||= User.create(email: email,
                        password: '12345678',
                        password_confirmation: '12345678',
                        name: name)
      u
    end

    def create_session(user, params)
      return nil unless user
      session_exists = LtiSession.where({ user: user.id })
      session_exists.delete_all if session_exists.any?
      LtiSession.create(lti_tool: LtiTool.find(get_tool_id(params)), user: user)
    end

    def get_current_user(params)
      return nil if verify_teacher(params) && !get_user_id(params)
      lti_session = LtiSession.where({ lti_tool: get_tool_id(params), user: get_user_id(params) })
      return nil unless lti_session.any?
      lti_session.first.user
    end
  end
end
