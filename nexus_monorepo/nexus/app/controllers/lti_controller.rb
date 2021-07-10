require 'ims/lti'
class LtiController < ApplicationController
  include LtiControllerHelpers

  skip_before_action :verify_authenticity_token, only: [:launch]
  before_filter :lti_authentication
  after_filter :disable_xframe_header

  rescue_from LtiLaunch::Unauthorized do |ex|
    @error = "Authentication failed with: #{case ex.error
                                            when :invalid_signature
                                              'The OAuth Signature was Invalid'
                                            when :invalid_nonce
                                              'The nonce has already been used'
                                            when :request_to_old
                                              'The request is to old'
                                            else
                                              'Unknown Error'
                                            end}"
    @message = IMS::LTI::Models::Messages::Message.generate(request.request_parameters)
    @header = SimpleOAuth::Header.new(:post, request.url, @message.post_params, consumer_key: @message.oauth_consumer_key, consumer_secret: 'secret', callback: 'about:blank')
    render :launch_error, status: 200
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
    render json: JSON.pretty_generate({ launch: params })
  end
end
