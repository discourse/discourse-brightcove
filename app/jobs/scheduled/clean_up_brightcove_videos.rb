module Jobs
  class CleanUpBrightcoveVideos < Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.brightcove_enabled

      orphaned_videos = Brightcove::Video.\
        where("brightcove_videos.created_at < ?", 7.days.ago).
        where(<<~SQL
          brightcove_videos.state <> 'ready'
          OR NOT EXISTS
            (SELECT 1 FROM post_custom_fields pcf
              WHERE pcf.name = '#{Brightcove::POST_CUSTOM_FIELD_NAME}'
              AND pcf.value LIKE CONCAT(brightcove_videos.video_id, ':%')
            )
        SQL
        )

      orphaned_videos.find_each do |video|
        api = Brightcove::API.new(video.video_id)
        begin
          api.delete
          video.destroy!
        rescue Brightcove::ApiError => e
          if e.code == 429
            # Rate limit, stop and run the job later
            Jobs.enqueue_in(1.minute, :clean_up_brightcove_videos)
            return
          end
        end

      end
    end

  end
end
