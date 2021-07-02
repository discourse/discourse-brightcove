# frozen_string_literal: true
class CreateBrightcoveVideos < ActiveRecord::Migration[5.2]
  def change
    create_table :brightcove_videos do |t|
      t.string :video_id, null: false
      t.string :state, null: false
      t.string :secret_access_key
      t.string :api_request_url
      t.string :callback_key
      t.datetime :created_at
    end

    add_index :brightcove_videos, :video_id, unique: true
  end
end
