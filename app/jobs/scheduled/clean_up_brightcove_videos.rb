# frozen_string_literal: true
module Jobs
  class CleanUpBrightcoveVideos < ::Jobs::Scheduled
    every 1.hour

    TOMBSTONE_DURATION = 7.days

    POSTS_WITH_VIDEO_SQL = <<~SQL
      SELECT 1 FROM post_custom_fields pcf
        JOIN posts p on pcf.post_id = p.id
        JOIN topics t on p.topic_id = t.id
        WHERE pcf.name = '#{Brightcove::POST_CUSTOM_FIELD_NAME}'
        AND pcf.value LIKE CONCAT(brightcove_videos.video_id, ':%')
        AND (t.deleted_at IS NULL OR t.deleted_at > :deleted_threshold)
        AND (p.deleted_at IS NULL OR p.deleted_at > :deleted_threshold)
    SQL

    def execute(args)
      return unless SiteSetting.brightcove_enabled

      # Tombstone any orphaned videos
      orphaned_videos =
        Brightcove::Video
          .where("brightcove_videos.created_at < ?", 7.days.ago)
          .where(tombstoned_at: nil)
          .where(<<~SQL, deleted_threshold: 1.day.ago)
          brightcove_videos.state <> 'ready'
          OR NOT EXISTS (#{POSTS_WITH_VIDEO_SQL})
        SQL
      orphaned_videos.update_all(tombstoned_at: Time.zone.now)

      # Un-tombstone any videos which now have associated posts
      restorable_videos =
        Brightcove::Video.where("tombstoned_at IS NOT NULL").where(
          <<~SQL,
          brightcove_videos.state = 'ready'
          AND EXISTS (#{POSTS_WITH_VIDEO_SQL})
        SQL
          deleted_threshold: 1.day.ago,
        )
      restorable_videos.update_all(tombstoned_at: nil)

      # Delete tombstoned videos from brightcove after duration
      tombstoned = Brightcove::Video.where("tombstoned_at < ?", TOMBSTONE_DURATION.ago)
      tombstoned.find_each do |video|
        api = Brightcove::API.new(video.video_id)
        begin
          api.delete
          video.destroy!
        rescue Brightcove::ApiError => e
          if e.status == 429
            # Rate limit, stop and run the job later
            Jobs.enqueue_in(1.minute, :clean_up_brightcove_videos)
            break
          end
        end
      end
    end
  end
end
