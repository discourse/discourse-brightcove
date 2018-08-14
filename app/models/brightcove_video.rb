class BrightcoveVideo < PluginStoreRow
  KEY_PREFIX = "video_"
  PLUGIN_NAME = Brightcove::PLUGIN_NAME

  ERRORED = "errored"
  READY = "ready"
  PENDING = "pending"

  after_initialize :init_model

  store_accessor :data, :state, :secret_access_key, :api_request_url, :callback_key

  validates :state, inclusion: { in: %w(pending ready errored),
                                 message: "%{value} is not a valid state" }

  default_scope do
    where(plugin_name: PLUGIN_NAME, type_name: "JSONB")
      .where("key LIKE ?", "#{KEY_PREFIX}%")
  end

  scope :with_video_id, ->(video_id) { where(key: "#{KEY_PREFIX}#{video_id}") }

  def self.find_by_video_id(video_id)
    self.with_video_id(video_id).take
  end

  def video_id=(video_id)
    self.key = "#{KEY_PREFIX}#{video_id}"
  end

  def video_id
    self.key.sub(KEY_PREFIX, "").to_i
  end

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

  private

  def init_model
    self.type_name ||= 'JSONB'
    self.plugin_name ||= PLUGIN_NAME
  end
end
