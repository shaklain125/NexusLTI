class LtiController < ApplicationController
  include LtiHelper

  before_action :check_lti_session, except: [:launch]
  skip_before_action :verify_authenticity_token, only: [:launch]

  def check_lti_session
    raise LtiLaunch::Error, :missing_lti_session unless user_signed_in?
    LtiUtils::Token.raise_if_missing(params)
  end

  def launch
    @lti_launch = LtiLaunch.check_launch!(LtiUtils.models.parsed_lti_message(request))

    @message = @lti_launch && @lti_launch.message
    raise LtiLaunch::Error, :invalid_lti_launch_message unless @message

    @tool_id = @lti_launch.lti_tool_id

    custom_params = @message.custom_params
    custom = LtiUtils::LaunchHelper.no_prefix_custom(custom_params)
    custom_params_exists = LtiUtils::LaunchHelper.keys_in_custom?(
      custom,
      LtiUtils::LaunchHelper.required_custom_params(request)
    )
    raise LtiLaunch::Error, :missing_arguments unless custom_params_exists

    pres_url = params[:launch_presentation_return_url]
    course_id = LtiUtils::Session.get_course_id_from_pres_url(pres_url).to_s.strip
    course_id = custom[:coursesection_sourcedid].to_s.strip if course_id.empty?
    raise LtiLaunch::Error, 'MSG: Course ID number required. You can set it in the course settings of the LMS.' if course_id.empty?

    config = custom[:lti_config]
    config = LtiUtils.decrypt_json(config)
    person = { email: custom[:person_email_primary], name: custom[:person_name_full] }
    course_params = {
      source_id: course_id,
      title: custom[:coursesection_title],
      description: custom[:coursesection_longdescription]
    }

    token_data = {
      tool_id: @tool_id,
      role: LtiUtils::LtiRole.new(custom_params).as_json[:role],
      ip_addr: request.remote_ip
    }

    params[:lti_token] = LtiUtils::Token.encrypt(token_data)

    is_student = LtiUtils::LtiRole.student?(params)
    is_teacher = LtiUtils::LtiRole.teacher?(params)

    user = LtiUtils::Session.create_student(person[:email], person[:name]) if is_student
    user = LtiUtils::Session.create_teacher(person[:email], person[:name]) if is_teacher

    lti_session = LtiUtils::Session.create_session(user, params)  if is_student || is_teacher
    raise LtiLaunch::Error, :failed_to_create_lti_session unless lti_session

    course = LtiUtils::Session.create_course(user, is_teacher, **course_params)
    raise LtiLaunch::Error, :course_has_not_started unless course

    aid = config[:aid]
    cid = course.id.to_s

    LtiUtils::Token.update_and_set_token(self, LtiUtils::Token.update_user_id(params, user.nil? ? nil : user.id))

    aid_a, aid_valid = LtiUtils::Session.validate_assignment(aid, cid)

    if is_student
      if aid_valid
        if aid_a.started?
          LtiUtils::Token.update_and_set_token(self, { submission: { aid: aid, cid: cid } })
          redirect_to new_submission_path(aid: aid)
        else
          raise LtiLaunch::Error, :assigment_not_started
        end
      else
        raise LtiLaunch::Error, :invalid_aid
      end
      return
    elsif is_teacher
      if aid_valid
        LtiUtils::Token.update_and_set_token(self, { config: { aid: aid, cid: cid } })
        redirect_to action: :manage_assignment
      else
        flash[:error] = "Assignment from LTI configuration does not exist" unless aid.nil?
        LtiUtils::Token.update_and_set_token(self, { generator: { cid: cid } })
        redirect_to action: :configure
      end
      return
    end

    exit_lti

    redirect_to root_path
  end

  def configure; end

  def configure_generate
    aid = params[:assignment]
    aid_a, aid_valid = LtiUtils::Session.validate_assignment(aid, @cid)
    u = current_user
    is_invalid = u.nil? || aid_a.nil? || !aid_valid || !u
    gen = LtiUtils.encrypt_json({ aid: aid, created_at: DateTime.now.strftime('%s').to_i * 1000 })
    render json: { config: is_invalid ? 'Error' : gen }
  rescue StandardError
    render json: { config: 'Unknown error' }
  end

  def manage_assignment
    @assignment, aid_valid = LtiUtils::Session.validate_assignment(@aid, @cid)
    unless aid_valid
      flash[:error] = "Assignment from LTI configuration does not exist"
      LtiUtils::Token.update_and_set_token(self, LtiUtils::Token.gen_data_update(params))
      redirect_to action: :configure
    end
  end
end
