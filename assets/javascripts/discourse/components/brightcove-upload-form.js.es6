import { default as computed } from "ember-addons/ember-computed-decorators";
import { ajax } from "discourse/lib/ajax";

const Evaporate = window.Evaporate;
const AWS = window.AWS;

export default Ember.Component.extend({
  file: null,

  @computed("file")
  fileName(file) {
    return file.name;
  },

  @computed("file")
  fileSize(file) {
    return this.humanFilesize(file.size);
  },

  humanFilesize(size) {
    var i = size === 0 ? 0 : Math.floor(Math.log(size) / Math.log(1024));
    return (
      (size / Math.pow(1024, i)).toFixed(2) * 1 +
      " " +
      ["B", "kB", "MB", "GB", "TB"][i]
    );
  },

  setProgress(key, args) {
    this.set(
      "uploadProgress",
      I18n.t(`brightcove.upload_progress.${key}`, args)
    );
  },

  createVideoObject() {
    this.set("uploading", true);
    this.setProgress("preparing");
    ajax("/brightcove/create", {
      type: "POST",
      data: { name: this.get("videoName"), filename: this.get("fileName") }
    })
      .then(videoInfo => {
        this.setupEvaporate(videoInfo);
      })
      .catch(reason => {
        console.error("Could not create brightcove video.", reason);
        this.setProgress("error");
      });
  },

  setupEvaporate(videoInfo) {
    this.setProgress("starting");

    this.set("videoInfo", videoInfo);
    const config = {
      bucket: videoInfo["bucket"],
      aws_key: videoInfo["access_key_id"],
      signerUrl: `/brightcove/sign/${videoInfo["video_id"]}.json`,
      computeContentMd5: true,
      cryptoMd5Method: function(data) {
        return AWS.util.crypto.md5(data, "base64");
      },
      cryptoHexEncodedHash256: function(data) {
        return AWS.util.crypto.sha256(data, "hex");
      }
    };

    Evaporate.create(config)
      .then(evaporate => {
        this.startEvaporateUpload(evaporate);
      })
      .catch(reason => {
        console.error("Brightcove failed to initialize. Reason: ", reason);
        this.setProgress("error");
      });
  },

  startEvaporateUpload(evaporate) {
    this.setProgress("uploading");

    const videoInfo = this.get("videoInfo");

    const headers = {
      "X-Amz-Security-Token": videoInfo["session_token"]
    };

    const add_config = {
      name: videoInfo["object_key"],
      file: this.get("file"),
      progress: progressValue => {
        this.setProgress("uploading", {
          progress: (progressValue * 100).toFixed(1)
        });
      },
      xAmzHeadersAtInitiate: headers,
      xAmzHeadersCommon: headers
    };

    evaporate
      .add(add_config)
      .then(() => {
        this.ingestVideo();
      })
      .catch(reason => {
        console.error("Brightcove upload failed. Reason: ", reason);
        this.setProgress("error");
      });
  },

  ingestVideo() {
    this.setProgress("finishing");
    const videoInfo = this.get("videoInfo");
    ajax(`/brightcove/ingest/${videoInfo["video_id"]}`, {
      type: "POST"
    })
      .then(() => {
        this.ingestComplete();
      })
      .catch(error => {
        console.error("Failed to ingest. Reason: ", error);
        this.setProgress("error");
      });
  },

  ingestComplete() {
    const videoInfo = this.get("videoInfo");
    this.setProgress("complete", { info: `[video=${videoInfo["video_id"]}]` });
    this.get("toolbarEvent").addText(`[video=${videoInfo["video_id"]}]`);
    const composer = Discourse.__container__.lookup("controller:composer");
    composer.send("closeModal");
  },

  @computed("file", "videoName")
  uploadDisabled(file, videoName) {
    return !(file && videoName);
  },

  actions: {
    fileChanged(event) {
      console.log("File Changed", event.target.files[0]);
      const file = event.target.files[0];
      this.set("file", file);
    },

    upload() {
      this.createVideoObject();
    }
  }
});
