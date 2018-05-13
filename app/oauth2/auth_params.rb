require 'locale'
require 'uri'


class AuthParams
  include Locale

  def initialize(params, headers)
    @params = params
    @headers = headers
  end

  def authorization_code
    @params[:authorization_code]
  end

  def authorization_code=(auth_code)
    @params[:authorization_code] = auth_code
  end

  def action
    @params[:action]
  end

  def endpoint
    {
      token: 'access_tokens',
      authorize: 'authorize'
    }[@params[:controller]]
  end

  def grant_type
    @params[:grant_type]
  end

  def client_id
    basic_auth = @headers['Authorization']
    unless basic_auth.nil?
      client_secret = basic_auth.split(':')
      unless client_secret.length.positive?
        raise StandardError(internal_err(:bad_auth_header))
      end
      return client_secret[0]
    end
    @params[:client_id]
  end

  def secret
    basic_auth = @headers['Authorization']
    client_secret = basic_auth.split(':')
    unless client_secret.length.positive?
      raise StandardError(internal_err(:bad_auth_header))
    end
    client_secret[1]
  end

  def username_password
    [@params[:username], @params[:password]]
  end

  def username=(username)
    @params[:username] = username
  end

  def password=(password)
    @params[:password] = password
  end

  def refresh_token
    @params[:refresh_token]
  end

  def redirect_url
    redirect_url = @params[:redirect_url]
    redirect_url = URI.decode(redirect_url) unless redirect_url.nil?
    redirect_url
  end

  def refresh_token_key_exists?
    @params.key?(:refresh_token)
  end

  def access_token
    bearer = @headers['Authorization']
    if bearer.nil? || basic_auth.split(' ').length == 1
      raise StandardError(internal_err(:bad_auth_header))
    end
    type, token = basic_auth.split(' ')
    unless type == 'Bearer'
      raise StandardError(internal_err(:bad_auth_method_expect_bearer))
    end
    token
  end
end
