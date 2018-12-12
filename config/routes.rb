Brightcove::Engine.routes.draw do
  get "/video/:video_id" => 'display#show'
  post "/create" => 'upload#create'
  get "/sign/:video_id" => 'upload#sign'
  post "/ingest/:video_id" => 'upload#ingest'
  post "/callback/:video_id/:secret" => 'upload#callback'
end
