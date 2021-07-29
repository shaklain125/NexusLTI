require 'ims/lti'
class LtiController < ApplicationController
  include LtiHelper

  before_filter :contains_token_param, except: [:launch]
  before_filter :lti_authentication, only: [:launch]

  def contains_token_param
    LtiHelper.contains_token_param_raise(params)
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

    params[:lti_token] = LtiHelper.encrypt_json({ tool_id: @tool_id })

    # redirect_to root_path if current_user

    # redirect_to lti_home_path unless current_user

    redirect_to lti_home_path

    # redirect_to edit_assignment_path(1)
    # redirect_to lti_launch2_path
    # render json: JSON.pretty_generate({
    #                                     signed_in: user_signed_in?,
    #                                     current_user: current_user.as_json
    #                                   })
  end

  def launch2
    # redirect_to lti_launch3_path
    render json: JSON.pretty_generate({ params: params })
    # render json: JSON.pretty_generate({ user: current_user.as_json })
  end

  def launch3
    render json: JSON.pretty_generate({ user: current_user.as_json })
  end

  def login
    redirect_to lti_home_path if current_user
  end

  def login_post
    u = User.find_by_email(params[:user][:email])
    valid_user = u.valid_password?(params[:user][:password])

    session_exists = LtiSession.find_by_user_id(u.id)

    validate_login = !valid_user || LtiHelper.invalid_token(params)

    if validate_login
      redirect_to lti_login_path
      return
    end

    LtiSession.create(lti_tool: LtiTool.find(LtiHelper.get_tool_id(params)), user: u) unless session_exists

    redirect_to lti_home_path
  end

  def logout
    unless LtiHelper.invalid_token(params)
      lti_session = LtiSession.find_by_lti_tool_id(LtiHelper.get_tool_id(params))
      lti_session.delete if lti_session
    end
    redirect_to lti_home_path
  end

  def index; end

  def configure; end

  def manage_assignment; end
end
