function addVideo(buffer, matches, state) {
  const video_id = matches[1];

  let settings = state.md.options.discourse;

  let token = new state.Token("div_open", "div", 1);
  token.attrs = [["class", "brightcove-container"]];
  buffer.push(token);
  token = new state.Token("video_open", "video", 1);
  token.attrs = [
    ["class", "video-js"],
    ["data-video-id", video_id],
    ["data-account", settings.brightcoveAccountId],
    ["data-player", settings.brightcovePlayer],
    ["data-application-id", settings.brightcoveApplicationId],
    ["data-embed", settings.brightcoveEmbed],
    ["controls", ""]
  ];
  buffer.push(token);
  token = new state.Token("video_close", "video", -1);
  buffer.push(token);
  token = new state.Token("div_close", "div", -1);
  buffer.push(token);
}

export function setup(helper) {
  helper.whiteList([
    "div.brightcove-container",
    "video.video-js",
    "video[data-video-id]",
    "video[data-account]",
    "video[data-player]",
    "video[data-application-id]",
    "video[controls]",
    "video[data-embed]"
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features["discourse-brightcove"] = !!siteSettings.brightcove_enabled;
    opts.brightcoveAccountId = siteSettings.brightcove_account_id;
    opts.brightcoveApplicationId = siteSettings.brightcove_application_id;
    opts.brightcovePlayer = siteSettings.brightcove_player;
    opts.brightcoveEmbed = siteSettings.brightcove_embed;
  });

  helper.registerPlugin(md => {
    const rule = {
      matcher: /\[video=([0-9]+)\]/,
      onMatch: addVideo
    };

    md.core.textPostProcess.ruler.push("discourse-brightcove", rule);
  });
}
