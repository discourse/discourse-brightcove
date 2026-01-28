# frozen_string_literal: true

require_relative "../../app/jobs/scheduled/clean_up_brightcove_videos"

describe Jobs::CleanUpBrightcoveVideos do
  let!(:auth_stub) do
    stub_request(:post, "https://oauth.brightcove.com/v4/access_token").to_return(
      status: 200,
      body: { access_token: "letmein", expires_in: 300 }.to_json,
      headers: {
      },
    )
  end

  let!(:post) { Fabricate(:post) }
  let!(:deleted_post) { Fabricate(:post, deleted_at: 2.days.ago) }
  let!(:deleted_topic_post) { Fabricate(:post).tap { |p| p.topic.update(deleted_at: 2.days.ago) } }
  let!(:pending_video) do
    Brightcove::Video.create!(video_id: "0001", state: "pending", created_at: 2.weeks.ago)
  end
  let!(:errored_video) do
    Brightcove::Video.create!(video_id: "0002", state: "errored", created_at: 2.weeks.ago)
  end
  let!(:used_video) do
    Brightcove::Video.create!(video_id: "0003", state: "ready", created_at: 2.weeks.ago)
  end
  let!(:unused_video) do
    Brightcove::Video.create!(video_id: "0004", state: "ready", created_at: 2.weeks.ago)
  end
  let!(:new_video) do
    Brightcove::Video.create!(video_id: "0005", state: "ready", created_at: 1.minute.ago)
  end
  let!(:deleted_post_video) do
    Brightcove::Video.create!(video_id: "0006", state: "ready", created_at: 1.week.ago)
  end
  let!(:deleted_topic_video) do
    Brightcove::Video.create!(video_id: "0007", state: "ready", created_at: 1.week.ago)
  end

  before do
    SiteSetting.brightcove_enabled = true
    SiteSetting.brightcove_account_id = 1234
    PostCustomField.create!(
      [pending_video, errored_video, used_video].map do |vid|
        {
          post_id: post.id,
          name: Brightcove::POST_CUSTOM_FIELD_NAME,
          value: vid.post_custom_field_value,
        }
      end,
    )
    PostCustomField.create!(
      post: deleted_post,
      name: Brightcove::POST_CUSTOM_FIELD_NAME,
      value: deleted_post_video.post_custom_field_value,
    )
    PostCustomField.create!(
      post: deleted_topic_post,
      name: Brightcove::POST_CUSTOM_FIELD_NAME,
      value: deleted_topic_video.post_custom_field_value,
    )
  end

  it "tombstones, then deletes the correct videos" do
    described_class.new.execute(nil)
    expect(Brightcove::Video.where.not(tombstoned_at: nil).pluck(:video_id)).to contain_exactly(
      "0001",
      "0002",
      "0004",
      "0006",
      "0007",
    )
    expect(Brightcove::Video.where(tombstoned_at: nil).pluck(:video_id)).to contain_exactly(
      "0003",
      "0005",
    )

    freeze_time 2.weeks.from_now do
      delete_stub =
        stub_request(:delete, %r{cms.api.brightcove.com/v1/accounts/1234/videos/[0-9]+}).to_return(
          status: 204,
        )
      described_class.new.execute(nil)
      expect(delete_stub).to have_been_requested.times(5)
      expect(Brightcove::Video.all.pluck(:video_id)).to contain_exactly("0003", "0005")
    end
  end

  it "stops and reschedules when rate limited" do
    delete_stub =
      stub_request(:delete, %r{cms.api.brightcove.com/v1/accounts/1234/videos/[0-9]+})
        .to_return(status: 204)
        .then
        .to_return(status: 429)

    pending_video.update(tombstoned_at: 2.weeks.ago)
    errored_video.update(tombstoned_at: 2.weeks.ago)

    expect { described_class.new.execute(nil) }.to change { Brightcove::Video.count }.by(-1) &
      change { described_class.jobs.size }.by(1)

    expect(delete_stub).to have_been_requested.times(2)
  end
end
