module Brightcove
  class Video
    attr_accessor :id

    def initialize(id)
      @id = id
    end

    def delete
      API.cms_request(:delete, "videos/#{@id}")
    end

    def move_to_folder(folder_id)
      API.cms_request(:put, "folders/#{folder_id}/videos/#{@id}")
    end

    def get_ingest_url(filename)
      API.ingest_request(:get, "videos/#{@id}/upload-urls/#{filename}")
    end

    def request_ingest(url)
      API.ingest_request(:post, "videos/#{@id}/ingest-requests", master: { url: url })
    end

    def self.create(name)
      response = API.cms_request(:post, 'videos', name: name)
      self.new(response[:id])
    end

  end
end
