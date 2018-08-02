# name: discourse-brightcove
# about: Enable onebox support for Brightcove player URLs
# version: 0.1
# authors: David Taylor
# url: https://github.com/discourse/discourse-brightcove

enabled_site_setting :brightcove_enabled
register_asset "stylesheets/brightcove.scss"

require_relative 'lib/brightcove/api'
require_relative 'lib/brightcove/video'

after_initialize do

  register_html_builder('server:before-head-close') do |ctx|
    break unless SiteSetting.brightcove_enabled
    "<script src='https://players.brightcove.net/#{SiteSetting.brightcove_account_id}/#{SiteSetting.brightcove_player}_#{SiteSetting.brightcove_embed}/index.min.js'></script>"
  end

end

Onebox = Onebox

module Onebox
  module Engine
    class BrightcoveOnebox
      include Engine
      always_https

      matches_regexp(/^https:\/\/players\.brightcove.net\/[0-9]+\/[^\/]+\/index\.html\?videoId=[0-9]+$/)

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
