Brightcove::Engine.routes.draw do
  post "/create" => 'upload#create'
  get "/sign/:video_id" => 'upload#sign'
  post "/ingest/:video_id" => 'upload#ingest'
end
