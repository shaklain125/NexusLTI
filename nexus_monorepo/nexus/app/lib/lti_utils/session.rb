module LtiUtils
  class Session
    class << self
      def https_session_enabled?
        LTI_HTTPS_SESSION
      end

      def http_session_enabled?
        LTI_HTTP_SESSION
      end

      def http_cookie_enabled?
        return false if LTI_HTTPS_SESSION
        return LTI_ENABLE_COOKIE_TOKEN_WHEN_HTTP if LTI_HTTP_SESSION
      end

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

      def create_course(user, is_teacher, source_id:, title:, description:)
        found_course = LtiCourse.where({ source: source_id })
        if found_course.any?

          found_course = found_course.first.course

          found_course.title = title
          found_course.description = description
          found_course.save!

          if found_course && is_teacher
            teacher_found_in_course = found_course.teachers.include?(user)

            if !teacher_found_in_course && !user.my_courses.include?(found_course)
              found_course.teachers << user
              found_course.save!
              user.courses << found_course
              user.save!
            end
          end

          return found_course
        end

        return nil unless is_teacher

        lti_course = LtiCourse.new(source: source_id)

        course = Course.new(title: title, description: description)
        course.teachers << user
        course.save!

        user.courses << course
        user.save!

        lti_course.course = course
        lti_course.save!

        course
      end

      def create_session(user, params)
        return nil unless user
        session_exists = LtiSession.where({ user: user.id })
        session_exists.delete_all if session_exists.any?
        LtiSession.create(lti_tool: LtiTool.find(LtiUtils.get_tool_id(params)), user: user)
      end

      def get_current_user(params)
        uid = LtiUtils.get_user_id(params)
        return nil unless uid
        lti_session = LtiSession.where({ lti_tool: LtiUtils.get_tool_id(params), user: uid })
        return nil unless lti_session.any?
        lti_session.first.user
      end

      def logout_session(params, cookies, session)
        lti_session = LtiSession.find_by_lti_tool_id(LtiUtils.get_tool_id(params))
        lti_session.delete if lti_session
        LtiUtils.update_and_set_token(params, cookies, session, LtiUtils.update_user_id(params, nil))
      end

      def set_http_flash(flash, request, params, cookies, session)
        # Set lti flashes (inside lti_token) if it's http_session as flashes will not work without session
        # Session flashes works in renders but not redirect_to
        session_nil = session[:session_id].nil?
        is_http_session = http_session?(request) && session_nil
        lti_http_flash = !LtiUtils.invalid_token(params) && is_http_session && !flash.empty?
        LtiUtils.flash(flash, params, cookies, session) if lti_http_flash
      end

      def https_session?(request)
        is_https = request.ssl?
        https_session_enabled? && is_https
      end

      def http_session?(request)
        is_https = request.ssl?
        http_session_enabled? && !is_https
      end

      def my_aid?(aid, params)
        return false unless aid
        a = Assignment.find(aid.to_i)
        return false unless a
        my_cid?(a.course.id, params)
      rescue StandardError
        false
      end

      def my_cid?(cid, params)
        return false unless cid
        c = Course.find(cid.to_i)
        return false unless c
        get_user(params).my_courses.include?(c)
      rescue StandardError
        false
      end

      def my_dex_id?(dex_id, params)
        return false unless dex_id
        d = DeadlineExtension.find(dex_id.to_i)
        return false unless d
        my_aid?(d.assignment.id, params)
      rescue StandardError
        false
      end

      def validate_assignment(aid, cid)
        return [nil, false] if aid.nil? || cid.nil? || !aid || !cid
        aid_find = Assignment.where({ id: aid, course: cid }) unless aid.nil?
        aid_valid = aid.nil? ? false : aid_find.any?
        aid_a = aid_find.first unless aid.nil?
        [aid_a, aid_valid]
      rescue StandardError
        [nil, false]
      end

      def get_course_id_from_pres_url(pres_url)
        uri = URI(pres_url)
        query = URI.decode_www_form(uri.query || '')
        uri.query = URI.encode_www_form(query)
        query = query.to_h
        course_id = query['course'].to_s.strip
        course_id.empty? ? nil : course_id
      rescue StandardError
        nil
      end

      def get_user(params)
        uid = LtiUtils.get_user_id(params)
        return nil unless uid
        User.find(uid)
      rescue StandardError
        nil
      end

      def get_course(params)
        cid = LtiUtils.get_conf(params)[:cid]
        return nil unless cid
        Course.find(cid)
      rescue StandardError
        nil
      end

      ## Raise
      def raise_if_invalid_session(cookies, session, request, params)
        id = session[:session_id]
        session_token = session[:lti_token]
        cookies_token = LtiUtils.get_cookie_token_only(cookies)

        is_https_session_valid = id && !session_token.nil? && cookies_token.nil?
        is_http_session_valid = ((id && session_token.nil?) || !id) && !cookies_token.nil?

        https_valid = (https_session?(request) && is_https_session_valid)
        http_valid = (http_session?(request) && is_http_session_valid)

        is_valid_session = (https_valid || http_valid)

        LtiUtils.delete_cookie_token_not_session(cookies) if !http_valid || https_valid

        raise LtiLaunch::Error, :invalid_lti_session if LtiUtils.contains_token_param(params) && !is_valid_session
      end

      ## Raise
      def raise_if_course_not_found(course)
        raise LtiLaunch::Error, :course_not_found unless course
      end

      def invalidate_devise_non_admin_login(params)
        return nil unless LTI_DISABLE_DEVISE_NON_ADMIN_LOGIN
        if params[:user] && params[:user][:email]
          u = User.find_by_email(params[:user][:email])
          is_admin = u && u.admin?
          return u unless is_admin
        end
        nil
      end
    end
  end
end
