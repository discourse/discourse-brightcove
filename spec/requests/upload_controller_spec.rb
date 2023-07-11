# frozen_string_literal: true
require "rails_helper"

RSpec.describe Brightcove::UploadController do
  let!(:auth_stub) do
    stub_request(:post, "https://oauth.brightcove.com/v4/access_token").to_return(
      status: 200,
      body: { access_token: "letmein", expires_in: 300 }.to_json,
      headers: {
      },
    )
  end

  let!(:creation_stub) do
    stub_request(:post, "https://cms.api.brightcove.com/v1/accounts/987654321/videos").to_return(
      status: 200,
      body: { id: 12 }.to_json,
      headers: {
      },
    )
  end

  let!(:upload_request_stub) do
    stub_request(
      :get,
      "https://ingest.api.brightcove.com/v1/accounts/987654321/videos/12/upload-urls/discourse_12_filename.mp4",
    ).to_return(
      status: 200,
      body: {
        secret_access_key: "secret",
        api_request_url: "https://my.domain/video.mp4",
        bucket: "Bucket",
      }.to_json,
      headers: {
      },
    )
  end

  let!(:ingest_request_stub) do
    stub_request(
      :post,
      "https://ingest.api.brightcove.com/v1/accounts/987654321/videos/12/ingest-requests",
    ).to_return(status: 204)
  end

  before do
    SiteSetting.brightcove_enabled = true
    SiteSetting.brightcove_account_id = "987654321"
    SiteSetting.brightcove_client_id = 123
    SiteSetting.brightcove_client_secret = "abc"
  end

  let(:user) { Fabricate(:user) }

  it "doesn't allow anon" do
    post "/brightcove/create.json", params: { name: "Test Name", filename: "filename.mp4" }
    expect(response.status).to eq(403)
  end

  context "while logged in" do
    before { sign_in(user) }

    it "blocks access when trust level restricted" do
      SiteSetting.brightcove_min_trust_level = 3
      post "/brightcove/create.json", params: { name: "Test Name", filename: "filename.mp4" }
      expect(response.status).to eq(403)
    end

    it "allows creation" do
      post "/brightcove/create.json", params: { name: "Test Name", filename: "filename.mp4" }
      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["video_id"]).to eq("12")
      expect(json["bucket"]).to eq("Bucket")
      expect(creation_stub).to have_been_requested.once
      expect(upload_request_stub).to have_been_requested.once
    end

    context "with rate limiter" do
      before { RateLimiter.enable }

      use_redis_snapshotting

      it "rate limits creation" do
        SiteSetting.brightcove_uploads_per_day_per_user = 1

        post "/brightcove/create.json", params: { name: "Test Name", filename: "filename.mp4" }
        expect(response.status).to eq(200)

        post "/brightcove/create.json", params: { name: "Test Name", filename: "filename.mp4" }
        expect(response.status).to eq(429)
      end
    end

    it "allows signing" do
      v = Brightcove::Video.create!(video_id: 12, secret_access_key: "abcd", state: "pending")
      get "/brightcove/sign/12.json",
          params: {
            to_sign: "some string",
            datetime: "20180512T12:00Z",
          }
      expect(response.status).to eq(200)
      expect(response.body).to eq(
        "36e5f9fa782ba7a7932fd8e21a4343a1c462e4f98aaa81674ea72fd8d0596edc",
      )
    end

    it "allows ingest" do
      v =
        Brightcove::Video.create!(
          video_id: "12",
          secret_access_key: "abcd",
          state: "pending",
          api_request_url: "https://hello.world/video.mp4",
        )
      post "/brightcove/ingest/12.json"
      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["success"]).to eq("OK")
    end
  end

  context "with login_required" do
    before { SiteSetting.login_required = true }
    let!(:video) do
      Brightcove::Video.create!(
        video_id: "12",
        secret_access_key: "abcd",
        state: "pending",
        api_request_url: "https://hello.world/video.mp4",
        callback_key: SecureRandom.hex,
      )
    end
    it "updates status upon callback" do
      post "/brightcove/callback/#{video.video_id}/#{video.callback_key}",
           params: { entityType: "TITLE", action: "SOMETHINGELSE", status: "SUCCESS" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }
      expect(response.status).to eq(200)
      video.reload
      expect(video.state).to eq("pending")

      post "/brightcove/callback/#{video.video_id}/#{video.callback_key}",
           params: { entityType: "TITLE", action: "CREATE", status: "ERROR" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }
      expect(response.status).to eq(200)
      video.reload
      expect(video.state).to eq("errored")

      post "/brightcove/callback/#{video.video_id}/#{video.callback_key}",
           params: { entityType: "TITLE", action: "CREATE", status: "SUCCESS" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }
      expect(response.status).to eq(200)
      video.reload
      expect(video.state).to eq("ready")
    end
  end
end
