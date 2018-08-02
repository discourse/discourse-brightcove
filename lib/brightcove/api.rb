module Brightcove
  class ApiError < StandardError; end

  class API
    REDIS_KEY = 'brightcove_access_token'
    OAUTH_ENDPOINT = "https://oauth.brightcove.com/v4/access_token"
    TOKEN_TTL_MARGIN = 5

    CMS_BASE_URL = "https://cms.api.brightcove.com/v1/accounts/"
    INGEST_BASE_URL = "https://ingest.api.brightcove.com/v1/accounts/"

    def self.cms_request(method, path, body = {})
      request(method, "#{CMS_BASE_URL}#{SiteSetting.brightcove_account_id}/#{path}", body)
    end

    def self.ingest_request(method, path, body = {})
      request(method, "#{INGEST_BASE_URL}#{SiteSetting.brightcove_account_id}/#{path}", body)
    end

    def self.request(method, url, body = {})
      connection = Excon.new(url)
      response = connection.request(
        method: method,
        headers: {
          'Authorization' => "Bearer #{access_token}"
        },
        body: body.to_json
      )
      return true if response.status == 204

      return JSON.parse(response.body, symbolize_names: true) if [200, 201].include?(response.status)

      raise ApiError, "Brightcove Error #{response.status}"
    end

    private
    def self.access_token
      $redis.get(REDIS_KEY) || acquire_token
    end

    def self.acquire_token
      response = Excon.post(
        OAUTH_ENDPOINT,
        headers: {
          "Authorization" => "Basic #{Base64.strict_encode64("#{SiteSetting.brightcove_client_id}:#{SiteSetting.brightcove_client_secret}")}",
          "Content-Type" => "application/x-www-form-urlencoded"
        },
        body: URI.encode_www_form(grant_type: "client_credentials")
      )

      if response.status != 200
        raise ApiError, "Error acquiring access token: #{response.status}"
      end
      data = JSON.parse(response.body, symbolize_names: true)

      access_token = data[:access_token]
      ttl = data[:expires_in] - TOKEN_TTL_MARGIN
      $redis.setex(REDIS_KEY, ttl, access_token)

      access_token
    end
  end
end
