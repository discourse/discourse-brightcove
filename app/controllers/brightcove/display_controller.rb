# frozen_string_literal: true
module Brightcove
  class DisplayController < ApplicationController
    skip_before_action :check_xhr
    requires_plugin Brightcove::PLUGIN_NAME

    def show
      @video_id = params.require(:video_id)
      render layout: false
    end
  end
end
