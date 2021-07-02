# frozen_string_literal: true
require 'rails_helper'

require_relative '../../app/jobs/scheduled/clean_up_brightcove_videos'

describe Jobs::CleanUpBrightcoveVideos do

  let!(:auth_stub) {
    stub_request(:post, "https://oauth.brightcove.com/v4/access_token").
      to_return(status: 200, body: { access_token: "letmein", expires_in: 300 }.to_json, headers: {})
  }

  let!(:post) { Fabricate(:post) }
  let!(:pending_video) { Brightcove::Video.create!(video_id: "0001", state: "pending", created_at: 2.weeks.ago) }
  let!(:errored_video) { Brightcove::Video.create!(video_id: "0002", state: "errored", created_at: 2.weeks.ago) }
  let!(:used_video) { Brightcove::Video.create!(video_id: "0003", state: "ready", created_at: 2.weeks.ago) }
  let!(:unused_video) { Brightcove::Video.create!(video_id: "0004", state: "ready", created_at: 2.weeks.ago) }
  let!(:new_video) { Brightcove::Video.create!(video_id: "0005", state: "ready", created_at: 1.minute.ago) }

  before do
    SiteSetting.brightcove_enabled = true
    SiteSetting.brightcove_account_id = 1234
    PostCustomField.create!([pending_video, errored_video, used_video].map { |vid|
      { post_id: post.id,
        name: Brightcove::POST_CUSTOM_FIELD_NAME,
        value: vid.post_custom_field_value
      }
    })
  end

  it "cleans up the correct videos" do
    delete_stub = stub_request(:delete, /cms.api.brightcove.com\/v1\/accounts\/1234\/videos\/[0-9]+/).to_return(status: 204)

    expect(Brightcove::Video.all.pluck(:video_id)). to contain_exactly("0001", "0002", "0003", "0004", "0005")
    described_class.new.execute(nil)
    expect(delete_stub).to have_been_requested.times(3)
    expect(Brightcove::Video.all.pluck(:video_id)). to contain_exactly("0003", "0005")
  end

  it "stops and reschedules when rate limited" do
    delete_stub = stub_request(:delete, /cms.api.brightcove.com\/v1\/accounts\/1234\/videos\/[0-9]+/).
      to_return(status: 204).then.to_return(status: 429)

    expect(Brightcove::Video.all.pluck(:video_id)). to contain_exactly("0001", "0002", "0003", "0004", "0005")

    expect { described_class.new.execute(nil) }.
      to change { Brightcove::Video.count }.by(-1) &
      change { described_class.jobs.size }.by(1)

    expect(delete_stub).to have_been_requested.times(2)
  end

end
