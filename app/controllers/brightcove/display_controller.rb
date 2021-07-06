# frozen_string_literal: true
module Brightcove
  class DisplayController < ApplicationController
    skip_before_action :check_xhr
    requires_plugin Brightcove::PLUGIN_NAME

    def show
      @video_id = params.require(:video_id)
      video = Brightcove::Video.find_by(video_id: @video_id, tombstoned_at: nil)
      raise Discourse::NotFound if video.nil?

      render layout: false
    end
  end
end
