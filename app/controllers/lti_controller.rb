class LtiController < ApplicationController
  include Oauth

  before_action :authenticate_user!

  skip_before_action :authenticate_user!, only: [:xml, :endpoint, :add_content, :item]

  OAUTH1_KEY_ITEM = 'item_tool'
  OAUTH1_SECRET_ITEM = 'item_tool_secret'

  OAUTH1_KEY_ADD_CONTENT = 'content'
  OAUTH1_SECRET_ADD_CONTENT = 'content_secret'

  def register
    tcp_url = params['tc_profile_url']
    tcp = begin
      Oj.load RestClient.get tcp_url
    rescue RestClient::ExceptionWithResponse => e
      nil
    end

    registration_failure_redirect unless required_capabilities?(tcp)
    tp_endpoint = tool_proxy_service_endpoint(tcp)

    add_content_url = url_for(controller: :lti, action: :add_content)
    tool_proxy = ToolProxy.new(tcp_url: tcp_url, base_url: request.base_url)

    content_body = { '@context' => add_content_url }.to_json
    headers = SimpleOAuth::Header.new(:post, tp_endpoint, {}, {
      consumer_key: params['reg_key'],
      oauth_body_hash: URI.encode_www_form_component(Digest::SHA1.base64digest(content_body)),
      consumer_secret: params['reg_password']
    })

    pp params
    add_content_url = url_for(controller: :lti, action: :add_content)
    reg_result = RestClient.post tp_endpoint.to_s, content_body,
                                 'Content-Type' => 'application/vnd.ims.lti.v2.toolproxy+json',
                                 'Authorization' => headers.to_s

    pp params
    #
    # tp_response = tool_proxy_request(tp_endpoint, access_token, tool_proxy)
    #
    # # 3. Make the tool proxy available (See section 6.1.4)
    # #    - Check for success and redirect to the tool consumer with proper
    # #      query parameters (See section 6.1.4 and 4.4).
    # registration_failure_redirect unless tp_response.code == 201
    #
    # #    - Get the tool proxy guid from the tool proxy create response
    # tool_proxy_guid = JSON.parse(tp_response.body)['tool_proxy_guid']
    #
    # #    - Get the tool consumer half of the shared split secret and construct
    # #      the complete shared secret (See section 5.6).
    # tc_half_shared_secret = JSON.parse(tp_response.body)['tc_half_shared_secret']
    # shared_secret = tc_half_shared_secret + tool_proxy.tp_half_shared_secret
    #
    # #    - Persist the tool proxy
    # tool_proxy.update_attributes(guid: tool_proxy_guid,
    #                              shared_secret: shared_secret)

    url_params = {
      status: 'success', # or failure
      tool_proxy_guid: params[:ext_tool_consumer_instance_guid] #create_tool_result['id']
    }
    redirect_url = "#{lti_launch_url}?#{url_params.to_query}"

    redirect_to redirect_url
  end

  def register_editor_button
    course_id = 2

    tokens = current_user.oauth_token
    access_token = tokens.access_token
    refresh_token = tokens.refresh_token

    return unless api_call_wrapper(access_token, refresh_token) do |access_token_real|
      create_external_tool OAUTH_BASE_URL, course_id, OAUTH1_KEY_ADD_CONTENT, OAUTH1_SECRET_ADD_CONTENT,
                           access_token_real, additional_params = {
          url: url_for(controller: :lti, action: :add_content),
          name: "Ereserve_Plus",
          editor_button: {
            url: url_for(controller: :lti, action: :add_content),
            enabled: true,
            icon_url: '',
            message_type: 'ContentItemSelectionRequest'
          },
        }
    end
  end

  def add_content
    #binding.pry
    #check_lti_auth OAUTH1_SECRET_ADD_CONTENT
    authenticate_user!
    @params_inner = params.select { |k, v| not [:controller, :action].include? k.to_sym }
    @readings = [[1, 'First'], [2, 'Second'], [3, 'Third']]
  end

  def send_choosen_objects
    id = SecureRandom.uuid

    Reading.create uid: id, readings: params['readings'].to_json

    tokens = current_user.oauth_token
    access_token = tokens.access_token
    refresh_token = tokens.refresh_token

    course_id = 2 # Extract by youself

    item_tool = nil
    launch_items_url = url_for(controller: :lti, action: :item, id: id)

    unless item_tool
      return unless api_call_wrapper(access_token, refresh_token) do |access_token_real|
        item_tool = create_external_tool OAUTH_BASE_URL, course_id, OAUTH1_KEY_ITEM, OAUTH1_SECRET_ITEM,
                                         access_token_real, additional_params = {
            url: launch_items_url = url_for(controller: :lti, action: :item, id: id),
            name: "Item Tool #{id}",
            course_navigation: {
              enabled: true,
              text: "Ereserve plus #{id}",
              visibility: 'admins',
              windowTarget: '_blank',
              default: false
            },
          }
      end

      return unless api_call_wrapper(access_token, refresh_token) do |access_token_real|
        delete_external_tool OAUTH_BASE_URL, item_tool['id'], course_id, access_token_real
      end
    end

    launch_url = "/courses/#{course_id}/external_tools/#{item_tool['id']}?display=borderless"
    url_params = { return_type: 'iframe', url: launch_url,
                   title: 'Item test' }
    redirect_url = "#{params['content_item_return_url']}?#{url_params.to_query}"

    redirect_to redirect_url
  end

  def item
    check_lti_auth OAUTH1_SECRET_ITEM
    readings = Reading.find_by_uid params['id']
    @readings = JSON.parse readings.readings rescue []
  end

  # return here from lms with code or error
  def oauth
    oauth_back
  end

  protected

  def required_capabilities?(tcp)
    (ToolProxy::ENABLED_CAPABILITY - tcp['capability_offered']).blank?
  end

  def registration_failure_redirect
    redirect_url = "#{params[:launch_presentation_return_url]}?status=failure"
    redirect redirect_url
  end

  def tool_proxy_service_endpoint(tcp)
    tp_services = tcp['service_offered'].find do |s|
      s['format'] == [ToolProxy::TOOL_PROXY_FORMAT]
    end

    # Retrieve and return the endpoint of the ToolProxy.collection service
    URI.parse(tp_services['endpoint']) unless tp_services.blank?
  end

  def create_external_tool(base_url, course_id, key, secret, access_token, additional_params = {})
    tool_params = {
      privacy_level: 'public',
      consumer_key: key,
      shared_secret: secret
    }.merge additional_params

    response = RestClient.post "#{base_url}/api/v1/courses/#{course_id}/external_tools", tool_params,
                               'Authorization' => " Bearer #{access_token}"
    Oj.load response.body
  end

  def get_external_tools_list(base_url, access_token, course_id)
    Oj.load RestClient.get("#{base_url}/api/v1/courses/#{course_id}/external_tools",
                           oauth2_header(access_token)).body
  end

  def delete_external_tool(base_url, id, course_id, access_token)
    Oj.load RestClient.delete("#{base_url}/api/v1/courses/#{course_id}/external_tools/#{id}",
                              oauth2_header(access_token)).body
  end

  def session_less_url_external_tool(base_url, access_token, course_id, id)
    Oj.load RestClient.get("#{base_url}/api/v1/courses/#{course_id}/external_tools/sessionless_launch?#{ { id: id }.to_query }",
                           oauth2_header(access_token)).body
  end

  def oauth_redirect_url
    url_for(controller: :lti, action: :oauth)
  end

  def check_lti_auth(secret)
    lti_auth = IMS::LTI::Services::MessageAuthenticator.new(request.url,
                                                            request.request_parameters,
                                                            secret)

    lti_auth.valid_signature?

    raise ActionController::RoutingError.new('Not Authrorised') unless lti_auth.valid_signature?
  end

  def oauth1_signature(method, url, post_params, secret)
    post_params = post_params.sort.map { |i| "#{i[0]}=#{i[1]}" }.join '&'
    data = "#{method}&#{URI.encode_www_form_component url}&#{URI.encode_www_form_component post_params }"
    Base64.encode64(OpenSSL::HMAC.digest('SHA1', secret, data)).strip()
  end
end
