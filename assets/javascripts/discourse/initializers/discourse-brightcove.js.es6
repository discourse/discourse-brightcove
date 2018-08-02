import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializeBrightcove(api) {
  api.decorateCooked($elem => {
    if (typeof window.bc !== "function") {
      console.error("Brightcove javascript bundle not loaded");
      return;
    }

    $(".video-js", $elem).each((index, element) => {
      window.bc(element);
    });

    $(".video-js", $elem).each((index, element) => {
      window.videojs(element);
    });
  });

  api.onToolbarCreate(toolbar => {
    toolbar.addButton({
      id: "brightcove-upload",
      group: "insertions",
      icon: "film",
      title: "brightcove.upload_title",
      perform: e => {
        console.log("Showing modal");
        showModal("brightcove-upload-modal").setProperties({
          toolbarEvent: e
        });
      }
    });
  });
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
