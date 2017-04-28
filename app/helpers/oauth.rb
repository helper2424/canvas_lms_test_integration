module Oauth
  OAUTH_ID = '10000000000001'
  OAUTH_KEY = 'XjhoGp0gbMV8ZR4IctiZvUCaN6AgPIr0E9Y6ZQSbBpsmKXwT6YmtBHM2K1Q3jFLf'
  OAUTH_BASE_URL = 'http://localhost:3000/'

  protected

  # return here from lms with code or error
  def oauth_back
    code = params['code']
    error = params['error']

    if error
      # make something
      return
    end

    access_token, refresh_token = oauth_create_access_token code

    tokens = current_user.oauth_token
    if tokens.present?
      tokens.access_token = access_token
      tokens.refresh_token = refresh_token unless tokens.refresh_token == refresh_token
      tokens.save
    else
      OauthToken.create(user: current_user, refresh_token: refresh_token, access_token: access_token)
    end

    redirect_to session[:return_to_url]
    session.delete :return_to_url
  end

  def oauth_start_auth
    url_params = { client_id: OAUTH_ID, response_type: 'code',
                   redirect_uri: oauth_redirect_url }
    redirect_url = "#{OAUTH_BASE_URL}/login/oauth2/auth?#{url_params.to_query}"
    redirect_to redirect_url
  end

  def oauth_create_access_token(code)
    oauth_params = {
      grant_type: 'authorization_code',
      client_id: OAUTH_ID,
      client_secret: OAUTH_KEY,
      redirect_uri: oauth_redirect_url,
      code: code
    }
    begin
      get_token_response = RestClient.post "#{OAUTH_BASE_URL}/login/oauth2/token", oauth_params
      get_token_response = Oj.load get_token_response
    rescue RestClient::ExceptionWithResponse => e
      # TODO: handle this situation
      pp e
      return
    end

    access_token = get_token_response['access_token']
    refresh_token = get_token_response['refresh_token']

    [access_token, refresh_token]
  end

  def oauth_refresh_token(refresh_token)
    oauth_params = {
      grant_type: 'refresh_token',
      client_id: OAUTH_ID,
      client_secret: OAUTH_KEY,
      refresh_token: refresh_token
    }
    begin
      get_token_response = RestClient.post "#{OAUTH_BASE_URL}/login/oauth2/token", oauth_params
      get_token_response = Oj.load get_token_response
    rescue RestClient::ExceptionWithResponse => e
      # TODO: handle this situation
      pp e
      return
    end

    access_token = get_token_response['access_token']
    access_token
  end

  def save_params_to_session(params_list = [])
    params_list.each { |i| session[i] = params[i] }
  end

  def remove_saved_params(params_list = [])
    params_list.each { |i| session.delete i }
  end
end
