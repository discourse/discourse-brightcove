# frozen_string_literal: true
module Brightcove
  class Video < ActiveRecord::Base
    ERRORED = "errored"
    READY = "ready"
    PENDING = "pending"

    belongs_to :user

    validates :state, inclusion: { in: %w(pending ready errored),
                                   message: "%{value} is not a valid state" }

    def post_custom_fields
      PostCustomField.where(name: Brightcove::POST_CUSTOM_FIELD_NAME).where("value LIKE ?", "#{self.video_id}%")
    end

    def post_custom_field_value
      "#{video_id}:#{state}"
    end

    def update_post_custom_fields!
      post_custom_fields.update_all(value: post_custom_field_value)
    end

    def publish_change_to_clients!
      Post.find(post_custom_fields.pluck(:post_id)).each do |post|
        post.publish_change_to_clients!(:brightcove_video_changed)
      end
    end

  end
end

# == Schema Information
#
# Table name: brightcove_videos
#
#  id                :bigint           not null, primary key
#  video_id          :string           not null
#  state             :string           not null
#  secret_access_key :string
#  api_request_url   :string
#  callback_key      :string
#  created_at        :datetime
#  user_id           :integer
#  tombstoned_at     :datetime
#
# Indexes
#
#  index_brightcove_videos_on_video_id  (video_id) UNIQUE
#
