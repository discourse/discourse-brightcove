import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";
import { renderIcon } from "discourse-common/lib/icon-library";

function initializeBrightcove(api) {
  if (typeof window.bc !== "function") {
    console.error("Brightcove javascript bundle not loaded");
    return;
  }

  const siteSettings = api.container.lookup("site-settings:main");

  function renderVideos($elem, post) {
    $("div[data-video-id]", $elem).each((index, container) => {
      const $container = $(container);
      const video_id = $container.data("video-id").toString();
      if (post.brightcove_videos.includes(`${video_id}:ready`)) {
        $(container).removeClass("brightcove-pending");
        $(container).removeClass("brightcove-unknown");
        $container.removeAttr("data-video-id");
        const $videoElem = $("<video/>").attr({
          "data-video-id": video_id,
          "data-account": siteSettings.brightcove_account_id,
          "data-player": siteSettings.brightcove_player,
          "data-application-id": siteSettings.brightcove_application_id,
          "data-embed": siteSettings.brightcove_embed,
          controls: "",
          class: "video-js"
        });
        $container.html($videoElem);

        window.bc($videoElem[0]);
        window.videojs($(".video-js", container)[0]);
      } else if (post.brightcove_videos.includes(`${video_id}:pending`)) {
        $container.addClass("brightcove-pending");
        $container.html(
          "<div class='icon-container'><div class='spinner'></div></div>"
        );
      } else if (post.brightcove_videos.includes(`${video_id}:errored`)) {
        $container.addClass("brightcove-error");

        $container.html(
          `<div class='icon-container'>${renderIcon(
            "string",
            "exclamation-triangle"
          )}</div>`
        );
      } else {
        $(container).addClass("brightcove-unknown");
      }
    });
  }

  api.decorateCooked(($elem, helper) => {
    if (helper) {
      const post = helper.getModel();
      renderVideos($elem, post);
    } else {
      $("div[data-video-id]", $elem).html(
        `<div class='icon-container'>${renderIcon("string", "film")}</div>`
      );
    }
  });

  api.onToolbarCreate(toolbar => {
    toolbar.addButton({
      id: "brightcove-upload",
      group: "insertions",
      icon: "film",
      title: "brightcove.upload_title",
      perform: e => {
        showModal("brightcove-upload-modal").setProperties({
          toolbarEvent: e
        });
      }
    });
  });

  api.registerCustomPostMessageCallback(
    "brightcove_video_changed",
    (topicController, message) => {
      let stream = topicController.get("model.postStream");
      const post = stream.findLoadedPost(message.id);
      stream.triggerChangedPost(message.id).then(() => {
        const $post = $(`article[data-post-id=${message.id}]`);
        renderVideos($post, post);
      });
    }
  );
}

export default {
  name: "discourse-brightcove",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.brightcove_enabled) {
      withPluginApi("0.8.8", initializeBrightcove);
    }
  }
};
