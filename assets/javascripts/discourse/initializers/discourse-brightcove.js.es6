import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";
import { renderIcon } from "discourse-common/lib/icon-library";
import loadScript from "discourse/lib/load-script";

function initializeBrightcove(api) {
  const siteSettings = api.container.lookup("site-settings:main");

  function renderVideo($container, video_id) {
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
    window.videojs($(".video-js", $container[0])[0]);
  }

  const placeholders = {
    pending: {
      iconHtml: "<div class='spinner'></div>",
      string: I18n.t("brightcove.state.pending")
    },
    errored: {
      iconHtml: renderIcon("string", "exclamation-triangle"),
      string: I18n.t("brightcove.state.errored")
    },
    unknown: {
      iconHtml: renderIcon("string", "question-circle"),
      string: I18n.t("brightcove.state.unknown")
    }
  };

  function renderPlaceholder($container, type) {
    $container.html(
      `<div class='icon-container'><span class='brightcove-message'>${
        placeholders[type].iconHtml
      } ${placeholders[type].string}</span></div>`
    );
  }

  function renderVideos($elem, post) {
    $("div[data-video-id]", $elem).each((index, container) => {
      const $container = $(container);
      const video_id = $container.data("video-id").toString();
      if (!post.brightcove_videos) return;

      const video_string = post.brightcove_videos.find(v => {
        return v.indexOf(`${video_id}:`) === 0;
      });
      if (video_string) {
        const status = video_string.replace(`${video_id}:`, "");

        if (status === "ready") {
          loadPlayerJs().then(() => {
            renderVideo($container, video_id);
          });
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

  function loadPlayerJs() {
    return loadScript(
      `https://players.brightcove.net/${siteSettings.brightcove_account_id}/${
        siteSettings.brightcove_player
      }_${siteSettings.brightcove_embed}/index.min.js`,
      { scriptTag: true }
    );
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
    file => {
      Ember.run.next(() => {
        const user = api.getCurrentUser();
        if (
          user.trust_level >= siteSettings.brightcove_min_trust_level ||
          user.staff
        ) {
          showModal("brightcove-upload-modal").setProperties({
            file
          });
        } else {
          bootbox.alert(
            I18n.t("brightcove.not_allowed", {
              trust_level: siteSettings.brightcove_min_trust_level,
              trust_level_description: Discourse.Site.currentProp("trustLevels")
                .findBy("id", siteSettings.brightcove_min_trust_level)
                .get("name")
            })
          );
        }
      });
    }
  );

  api.onToolbarCreate(toolbar => {
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
        }
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
  }
};
