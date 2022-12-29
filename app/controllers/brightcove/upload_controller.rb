# frozen_string_literal: true
module Brightcove
  class UploadController < ApplicationController
    requires_plugin Brightcove::PLUGIN_NAME

    before_action :ensure_logged_in, :check_upload_permission, except: [:callback]

    skip_before_action :check_xhr,
                       :preload_json,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       only: [:callback]

    def create
      name = params.require(:name)
      filename = params.require(:filename)

      unless @guardian.is_admin?
        RateLimiter.new(
          current_user,
          "brightcove_uploads_per_day",
          SiteSetting.brightcove_uploads_per_day_per_user,
          1.day,
        ).performed!
      end

      hijack do
        api = API.create(name)
        video =
          Brightcove::Video.new(
            video_id: api.id,
            state: Brightcove::Video::PENDING,
            user: current_user,
          )
        begin
          unless SiteSetting.brightcove_folder_id.blank?
            api.move_to_folder(SiteSetting.brightcove_folder_id)
          end
          ingest_info = api.get_ingest_url(filename)
          video.secret_access_key = ingest_info[:secret_access_key]
          video.api_request_url = ingest_info[:api_request_url]
        ensure
          video.save!
        end

        render json: {
                 video_id: video.video_id,
                 bucket: ingest_info[:bucket],
                 object_key: ingest_info[:object_key],
                 access_key_id: ingest_info[:access_key_id],
                 session_token: ingest_info[:session_token],
               }
      end
    end

    def sign
      video_id = params.require(:video_id)
      to_sign = params.require(:to_sign)
      datetime = params.require(:datetime)

      video = Brightcove::Video.find_by_video_id(video_id)
      raise Discourse::NotFound if video.nil? || video.secret_access_key.nil?

      secret = video.secret_access_key
      aws_region = "us-east-1"
      date = datetime[0, 8]

      k_date = hmac("AWS4" + secret, date)
      k_region = hmac(k_date, aws_region)
      k_service = hmac(k_region, "s3")
      k_credentials = hmac(k_service, "aws4_request")
      signature = hexhmac(k_credentials, to_sign)

      render plain: signature
    end

    def ingest
      video_id = params.require(:video_id)

      video = Brightcove::Video.find_by_video_id(video_id)
      raise Discourse::NotFound if video.nil? || video.api_request_url.nil?

      video.callback_key = SecureRandom.hex
      video.save!

      hijack do
        api = API.new(video_id)
        callback_url = "#{Discourse.base_url}/brightcove/callback/#{video_id}/#{video.callback_key}"

        api.request_ingest(video.api_request_url, callback_url)
        render json: success_json
      end
    end

    def callback
      data = JSON.parse(request.body.read)
      # Only process if it's a notification we care about
      if data["entityType"] == "TITLE" && data["action"] == "CREATE"
        video_id = params.require(:video_id)
        secret = params.require(:secret)

        video = Brightcove::Video.find_by_video_id(video_id)
        raise Discourse::NotFound if video.nil? || video.callback_key.nil?

        raise Discourse::InvalidAccess unless video.callback_key == secret

        if data["status"] == "SUCCESS"
          video.state = Brightcove::Video::READY
        else
          video.state = Brightcove::Video::ERRORED
        end
        video.save!
        video.update_post_custom_fields!
        video.publish_change_to_clients!
      end

      render json: success_json
    end

    private

    def hmac(key, value)
      OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), key, value)
    end

    def hexhmac(key, value)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), key, value)
    end

    def check_upload_permission
      raise Discourse::InvalidAccess unless guardian.can_upload_to_brightcove?
    end
  end
end
