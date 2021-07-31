require 'ims/lti'
require 'ims/lis'
class LtiController < ApplicationController
  include LtiHelper

  before_filter :contains_token_param, except: [:launch]
  before_filter :lti_authentication, only: [:launch]
  skip_before_filter :verify_authenticity_token, only: [:launch, :login_post]

  def contains_token_param
    LtiUtils.contains_token_param_raise(params)
  end

  def launch
    tool = LtiTool.find(@lti_launch.lti_tool_id)
    @secret = "&#{tool.shared_secret}"
    @message = (@lti_launch && @lti_launch.message) || IMS::LTI::Models::Messages::Message.generate(request.request_parameters)
    @header = SimpleOAuth::Header.new(:post, request.url, @message.post_params, consumer_key: @message.oauth_consumer_key, consumer_secret: 'secret', callback: 'about:blank')

    # render json: JSON.pretty_generate({ 'launch' => { 'message' => @message, 'secret' => @secret, 'header' => @header } })
    # render json: JSON.pretty_generate({ 'launch' => {
    #                                     'params' => params,
    #                                     'lti_launch' => @lti_launch.as_json,
    #                                     'lti_tool' => tool.as_json
    #                                   } })
    # render json: JSON.pretty_generate({ launch: params })

    @launch_id = @lti_launch.id
    @tool_id = @lti_launch.lti_tool_id

    token_data = {
      tool_id: @tool_id,
      role: LtiUtils::LtiRole.new(@message.custom_params).as_json[:role]
    }

    params[:lti_token] = LtiUtils.encrypt_json(token_data)

    is_student = LtiUtils.verify_student(params)

    user = create_user('student2@student.com', 'Student2') if is_student

    params[:lti_token] = LtiUtils.encrypt_json(token_data.merge({ user_id: user.nil? ? nil : user.id }))

    create_session(user)  if is_student

    LtiUtils.set_cookie_token(cookies, params[:lti_token]) # if is_ref_page && !LtiUtils.invalid_token(params)

    # redirect_to root_path if current_user

    # redirect_to lti_home_path unless current_user

    if LtiUtils.verify_student(params)
      redirect_to new_submission_path(aid: 5)
      return
    end

    redirect_to lti_home_path
  end

  def launch2
    # LtiUtils.set_lti_cookie(cookies, :foo, 'bar')
    redirect_to lti_launch3_path
  end

  def launch3
    # render json: JSON.pretty_generate({ foo: cookies[:foo] })
  end

  def login
    redirect_to lti_home_path if current_user
  end

  def create_user(email, name)
    u = User.find_by_email(email)
    u ||= User.create(email: email,
                      password: '12345678',
                      password_confirmation: '12345678',
                      name: name)
    u
  end

  def create_session(user)
    session_exists = LtiSession.where({ user: user.id })
    session_exists.delete_all if session_exists.any?
    LtiSession.create(lti_tool: LtiTool.find(LtiUtils.get_tool_id(params)), user: user)
  end

  def login_post
    u = User.find_by_email(params[:user][:email])
    valid_user = u.valid_password?(params[:user][:password])

    validate_login = !valid_user || LtiUtils.invalid_token(params) || !@is_teacher

    if validate_login
      redirect_to lti_login_path
      return
    end

    create_session(u)

    params[:lti_token] = LtiUtils.encrypt_json(LtiUtils.update_user_id(params, u.id))

    LtiUtils.set_cookie_token(cookies, params[:lti_token])

    redirect_to lti_home_path
  end

  def logout
    unless LtiUtils.invalid_token(params)
      lti_session = LtiSession.find_by_lti_tool_id(LtiUtils.get_tool_id(params))

      lti_session.delete if lti_session && @is_teacher

      params[:lti_token] = LtiUtils.encrypt_json(LtiUtils.update_user_id(params, nil))

      LtiUtils.set_cookie_token(cookies, params[:lti_token])
    end

    redirect_to lti_home_path
  end

  def index; end

  def configure; end

  def manage_assignment; end
end
