# frozen_string_literal: true
require "rails_helper"

describe CookedPostProcessor do
  before { SiteSetting.brightcove_enabled = true }

  let(:post) do
    raw = <<-RAW.strip_heredoc
    [video=1234]
    [video=12345]
    [video=123456]
    RAW
    post = Fabricate(:post, raw: raw)
  end

  it "updates video custom fields" do
    Brightcove::Video.create!(video_id: "1234", state: Brightcove::Video::PENDING)
    Brightcove::Video.create!(video_id: "123456", state: Brightcove::Video::READY)
    CookedPostProcessor.new(post).post_process
    post.reload
    expect(post.custom_fields[Brightcove::POST_CUSTOM_FIELD_NAME]).to contain_exactly(
      "1234:pending",
      "123456:ready",
    )
  end
end
