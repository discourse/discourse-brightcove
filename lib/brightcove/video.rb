module Brightcove
  class Video
    def initialize(id)
      @id = id
    end

    def delete
      API.cms_request(:delete, "videos/#{@id}")
    end

    def move_to_folder(folder_id)
      API.cms_request(:put, "folders/#{folder_id}/videos/#{@id}")
    end

    def get_ingest_url
      API.ingest_request(:get, "videos/#{@id}/upload-urls/testfilename.mp4")
    end

    def self.create(name)
      response = API.cms_request(:post, 'videos', name: name)
      self.new(response[:id])
    end

  end
end
