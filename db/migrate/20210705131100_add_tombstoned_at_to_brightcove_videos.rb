# frozen_string_literal: true
class AddTombstonedAtToBrightcoveVideos < ActiveRecord::Migration[6.1]
  def change
    add_column :brightcove_videos, :tombstoned_at, :timestamp
  end
end
