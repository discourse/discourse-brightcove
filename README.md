# discourse-brightcove

A plugin to integrate Discourse with [Brightcove](https://www.brightcove.com/). Users can upload videos from the composer, directly to Brightcove. This requires you to have a Brightcove account with full API access. Configuration options available are:

- brightcove_enabled: Enable the discourse-brightcove plugin
- brightcove_account_id: Brightcove account ID
- brightcove_client_id: Brightcove client ID for this application
- brightcove_client_secret: Brightcove client secret for this application
- brightcove_application_id: Brightcove application ID. Used to differentiate this application in video analytics
- brightcove_folder_id: The folder ID for uploaded videos. Can be left blank to leave videos without a folder.
- brightcove_player: Brightcove player ID
- brightcove_embed: Brightcove embed ID
- brightcove_min_trust_level: Minimum required trust level for uploading videos to Brightcove
- brightcove_file_extensions: A list of file extensions which can be uploaded to Brightcove
- brightcove_uploads_per_day_per_user: Maximum number of videos that a user can upload per day

The advanced embed API is used, so that the brightcove player can be restricted to the forum's domain name. Note that this does not make the video 'secure' - if someone has the direct video link, they could still access it without a forum account. This is the same for all brightcove videos.
