require "rails_helper"

describe Brightcove::API do

  let!(:auth_stub) {
    stub_request(:post, "https://oauth.brightcove.com/v4/access_token").
      with(
           body: { "grant_type" => "client_credentials" },
           headers: {
          'Authorization' => "Basic #{Base64.strict_encode64("123:abc")}",
          'Content-Type' => 'application/x-www-form-urlencoded'
           }).
      to_return(status: 200, body: { access_token: "letmein", expires_in: 300 }.to_json, headers: {})
  }

  before do
    SiteSetting.brightcove_account_id = "987654321"
    SiteSetting.brightcove_client_id = 123
    SiteSetting.brightcove_client_secret = "abc"
  end

  describe "auth token" do
    it 'acquires and saves access token' do
      $redis.del(Brightcove::API::REDIS_KEY)

      # Acquires
      token = described_class.access_token
      expect(token).to eq("letmein")
      expect(auth_stub).to have_been_requested.once

      # Saves
      token = described_class.access_token
      expect(token).to eq("letmein")
      expect(auth_stub).to have_been_requested.once
    end

    it "handles errors" do
      auth_stub.response.status = 403
      expect { described_class.acquire_token }.to raise_exception(Brightcove::ApiError)
    end
  end

  describe "creating video" do
    let!(:creation_stub) do
      stub_request(:post, "https://cms.api.brightcove.com/v1/accounts/987654321/videos").
        with(body: "{\"name\":\"Some Title\"}", headers: { 'Authorization' => 'Bearer letmein' }).
        to_return(status: 200, body: { id: 12 }.to_json, headers: {})
    end

    it "creates successfully" do
      api = described_class.create("Some Title")
      expect(api.id).to eq(12)
      expect(creation_stub).to have_been_requested.once
    end
  end

end
