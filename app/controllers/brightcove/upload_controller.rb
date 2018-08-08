module Brightcove
  class UploadController < ApplicationController
    requires_plugin Brightcove::PLUGIN_NAME

    def create
      name = params.require(:name)
      filename = params.require(:filename)

      # Contacting brightcove API, so hijack request
      # hijack do
      video_info = {
        created_at: DateTime.now
      }
      video = Brightcove::Video.create(name)
      begin
        ingest_info = video.get_ingest_url(filename)
        video_info[:secret_access_key] = ingest_info[:secret_access_key]
        video_info[:api_request_url] = ingest_info[:api_request_url]
      ensure
        PluginStore.set(Brightcove::PLUGIN_NAME, "video_#{video.id}", video_info)
      end

      render json: {
        video_id: video.id,
        bucket: ingest_info[:bucket],
        object_key: ingest_info[:object_key],
        access_key_id: ingest_info[:access_key_id],
        session_token: ingest_info[:session_token]
      }
    end
    # end

    def sign
      video_id = params.require(:video_id)
      to_sign = params.require(:to_sign)
      datetime = params.require(:datetime)

      video_info = PluginStore.get(Brightcove::PLUGIN_NAME, "video_#{video_id}")
      raise Discourse::NotFound if video_info.nil? || video_info["secret_access_key"].nil?

      secret = video_info["secret_access_key"]
      aws_region = "us-east-1"
      date = datetime[0, 8]

      k_date = hmac("AWS4" + secret, date)
      k_region = hmac(k_date, aws_region)
      k_service = hmac(k_region, 's3')
      k_credentials = hmac(k_service, 'aws4_request')
      signature = hexhmac(k_credentials, to_sign)

      render plain: signature
    end

    def ingest
      video_id = params.require(:video_id)

      video_info = PluginStore.get(Brightcove::PLUGIN_NAME, "video_#{video_id}")
      raise Discourse::NotFound if video_info.nil? || video_info["api_request_url"].nil?

      hijack do
        video = Brightcove::Video.new(video_id)
        video.request_ingest(video_info["api_request_url"])
        render json: success_json
      end
    end

    private

    def hmac(key, value)
      OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, value)
    end

    def hexhmac(key, value)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), key, value)
    end
  end
end
