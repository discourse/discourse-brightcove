# frozen_string_literal: true
# name: discourse-brightcove
# about: Enable onebox support for Brightcove player URLs
# version: 0.1
# authors: David Taylor
# url: https://github.com/discourse/discourse-brightcove

enabled_site_setting :brightcove_enabled
register_asset "stylesheets/brightcove.scss"
register_asset "vendor/es6-promise.auto.js"
register_asset "vendor/evaporate.js"
register_asset "vendor/spark-md5.js"

register_svg_icon "film"

require "onebox"
require_relative "lib/brightcove/api"

extend_content_security_policy(
  script_src: %w[https://players.brightcove.net https://vjs.zencdn.net/],
)

after_initialize do
  require_relative "app/jobs/scheduled/clean_up_brightcove_videos"

  register_post_custom_field_type(Brightcove::POST_CUSTOM_FIELD_NAME, :string)
  topic_view_post_custom_fields_allowlister { Brightcove::POST_CUSTOM_FIELD_NAME }

  add_to_serializer(:post, :brightcove_videos, false) do
    Array(post_custom_fields[Brightcove::POST_CUSTOM_FIELD_NAME])
  end

  on(:post_process_cooked) do |doc, post|
    video_ids = []
    doc
      .css("div/@data-video-id")
      .each do |media|
        if video = Brightcove::Video.find_by(video_id: media.value)
          video.update(tombstoned_at: nil) if video.tombstoned_at
          video_ids << video.post_custom_field_value
        end
      end

    post.custom_fields[Brightcove::POST_CUSTOM_FIELD_NAME] = video_ids
    post.save_custom_fields
  end

  add_to_class(:guardian, :can_upload_to_brightcove?) do
    return @user.has_trust_level?(SiteSetting.brightcove_min_trust_level)
  end
end

module ::Brightcove
  PLUGIN_NAME = "discourse-brightcove"
  POST_CUSTOM_FIELD_NAME = "brightcove_video"

  class Engine < ::Rails::Engine
    engine_name Brightcove::PLUGIN_NAME
    isolate_namespace Brightcove
  end
end

Discourse::Application.routes.append { mount ::Brightcove::Engine, at: "/brightcove" }

module ::Onebox
  module Engine
    class BrightcoveOnebox
      include Engine
      always_https

      matches_regexp(%r{^https://players\.brightcove.net/[0-9]+/[^/]+/index\.html\?videoId=[0-9]+$})

      def to_html
        "<iframe src=\"#{@url}\" width=\"100%\" height=\"400\" allowfullscreen></iframe>"
      end

      # def placeholder_html
      #   <<-HTML
      #     <div class='brightcove-onebox-placeholder' style='width:100%;height:400px'>
      #       <div style='text-align:center;'>
      #         <div class="brightcove-onebox-logo"></div>
      #         <p>Brightcove Video</p>
      #       </div>
      #     </div>
      #   HTML
      # end
    end
  end
end
