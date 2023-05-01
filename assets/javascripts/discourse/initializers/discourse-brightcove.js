import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";
import { renderIcon } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { next } from "@ember/runloop";
import getURL from "discourse-common/lib/get-url";

function initializeBrightcove(api) {
  const siteSettings = api.container.lookup("site-settings:main");
  const site = api.container.lookup("site:main");

  function renderVideo($container, video_id) {
    $container.removeAttr("data-video-id");
    const $videoElem = $("<iframe/>").attr({
      src: getURL(`/brightcove/video/${video_id}`),
      class: "brightcove_video",
    });
    $container.html($videoElem);
  }

  const placeholders = {
    pending: {
      iconHtml: "<div class='spinner'></div>",
      string: I18n.t("brightcove.state.pending"),
    },
    errored: {
      iconHtml: renderIcon("string", "exclamation-triangle"),
      string: I18n.t("brightcove.state.errored"),
    },
    unknown: {
      iconHtml: renderIcon("string", "question-circle"),
      string: I18n.t("brightcove.state.unknown"),
    },
  };

  function renderPlaceholder($container, type) {
    $container.html(
      `<div class='icon-container'><span class='brightcove-message'>${placeholders[type].iconHtml} ${placeholders[type].string}</span></div>`
    );
  }

  function renderVideos($elem, post) {
    $("div[data-video-id]", $elem).each((index, container) => {
      const $container = $(container);
      const video_id = $container.data("video-id").toString();
      if (!post.brightcove_videos) {
        return;
      }

      const video_string = post.brightcove_videos.find((v) => {
        return v.indexOf(`${video_id}:`) === 0;
      });
      if (video_string) {
        const status = video_string.replace(`${video_id}:`, "");

        if (status === "ready") {
          renderVideo($container, video_id);
        } else if (status === "errored") {
          renderPlaceholder($container, "errored");
        } else {
          renderPlaceholder($container, "pending");
        }
      } else {
        renderPlaceholder($container, "unknown");
      }
    });
  }

  api.decorateCooked(
    ($elem, helper) => {
      if (helper) {
        const post = helper.getModel();
        renderVideos($elem, post);
      } else {
        $("div[data-video-id]", $elem).html(
          `<div class='icon-container'>${renderIcon("string", "film")}</div>`
        );
      }
    },
    { id: "discourse-brightcove" }
  );

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

  api.addComposerUploadHandler(
    siteSettings.brightcove_file_extensions.split("|"),
    (files) => {
      let file;
      if (Array.isArray(files)) {
        file = files[0];
      } else {
        file = files;
      }

      next(() => {
        const user = api.getCurrentUser();
        if (
          user.trust_level >= siteSettings.brightcove_min_trust_level ||
          user.staff
        ) {
          showModal("brightcove-upload-modal").setProperties({
            file,
          });
        } else {
          const dialog = api.container.lookup("service:dialog");
          dialog.alert(
            I18n.t("brightcove.not_allowed", {
              trust_level: siteSettings.brightcove_min_trust_level,
              trust_level_description: site.trustLevels
                .findBy("id", siteSettings.brightcove_min_trust_level)
                .get("name"),
            })
          );
        }
      });
    }
  );

  api.onToolbarCreate((toolbar) => {
    const user = api.getCurrentUser();
    if (
      user.trust_level >= siteSettings.brightcove_min_trust_level ||
      user.staff
    ) {
      toolbar.addButton({
        id: "brightcove-upload",
        group: "insertions",
        icon: "film",
        title: "brightcove.upload_toolbar_title",
        perform: () => {
          showModal("brightcove-upload-modal");
        },
      });
    }
  });
}

export default {
  name: "discourse-brightcove",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.brightcove_enabled) {
      withPluginApi("0.8.24", initializeBrightcove);
    }
  },
};
