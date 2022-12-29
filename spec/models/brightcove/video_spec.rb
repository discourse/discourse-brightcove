# frozen_string_literal: true
require "rails_helper"

describe Brightcove::Video do
  it "updates and publishes changes correctly" do
    video = Brightcove::Video.create!(video_id: "1234", state: "pending")
    posts = []
    posts << Fabricate(:post)
    posts << Fabricate(:post)
    posts << Fabricate(:post)

    PostCustomField.create!(
      posts.map do |p|
        {
          post_id: p.id,
          name: Brightcove::POST_CUSTOM_FIELD_NAME,
          value: video.post_custom_field_value,
        }
      end,
    )
    expect(video.post_custom_fields.pluck(:value)).to contain_exactly(*Array.new(3, "1234:pending"))
    video.state = "ready"
    video.update_post_custom_fields!
    expect(video.post_custom_fields.pluck(:value)).to contain_exactly(*Array.new(3, "1234:ready"))

    messages = MessageBus.track_publish { video.publish_change_to_clients! }

    expect(messages.length).to eq(3)
    expect(messages.map { |m| m.data[:id] }).to contain_exactly(*posts.map(&:id))
  end
end
