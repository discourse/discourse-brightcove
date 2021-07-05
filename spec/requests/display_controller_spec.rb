# frozen_string_literal: true
require "rails_helper"

RSpec.describe Brightcove::DisplayController do
  before do
    SiteSetting.brightcove_enabled = true
    SiteSetting.brightcove_account_id = "987654321"
    SiteSetting.brightcove_client_id = 123
    SiteSetting.brightcove_client_secret = "abc"
  end

  let!(:video) { Brightcove::Video.create!(video_id: "12", secret_access_key: "abcd", state: "ready", api_request_url: "https://hello.world/video.mp4", callback_key: SecureRandom.hex) }

  it "works" do
    get "/brightcove/video/#{video.video_id}"
    expect(response.status).to eq(200)
  end

  it "raises 404 for missing video" do
    get "/brightcove/video/123"
    expect(response.status).to eq(404)
  end

  it "raises 404 for tombstoned video" do
    video.update(tombstoned_at: Time.zone.now)
    get "/brightcove/video/#{video.video_id}"
    expect(response.status).to eq(404)
  end

end
