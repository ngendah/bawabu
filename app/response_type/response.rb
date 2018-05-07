require 'token_generator.rb'
require 'uri'


class Response

  def to_json(options)
    raise NotImplementedError
  end

  def to_text
    raise NotImplementedError
  end
end


class AuthorizeResponse < Response

  def initialize(request, grant_type)
    @request = request
    @grant_type = grant_type
  end

  def to_text
    params = @request.params
    @grant_type.authorize params[:client_id], params[:redirect_url]
  end

  def to_json(options)
    params = @request.params
    @grant_type.authorize params[:client_id], params[:redirect_url]
  end
end


class AccessTokenResponse < Response

  def initialize(request, grant_type)
    @request = request
    @grant_type = grant_type
  end

  def to_json(options)
    params = @request.params
    if params.key?(:refresh_token)
      token = @grant_type.renew_token params[:refresh_token], true
    else
      token = @grant_type.token params[:code], true
    end
    token[:token_type] = 'bearer'
    token.to_s
  end
end