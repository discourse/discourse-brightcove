import { on } from "ember-addons/ember-computed-decorators";
import { ajax } from "discourse/lib/ajax";

const Evaporate = window.Evaporate;
const AWS = window.AWS;

export default Ember.Component.extend({
  @on("didInsertElement")
  _initialize() {
    const $upload = this.$();

  fetchAuthInfo(params) {
    console.log("auth info wants", params);
    return new Promise(function(resolve, reject) {
      resolve("computed signature");
    });
  },

  actions: {
    fileChanged(event) {
      console.log("File Changed", event.target.files[0]);
      const file = event.target.files[0];
      ajax("/brightcove/create", {
        type: "POST",
        data: { name: "Test Name", filename: file.name }
      }).then(videoInfo => {
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

        const add_config = {
          name: videoInfo["object_key"],
          file: event.target.files[0],
          xAmzHeadersAtInitiate: {
            "X-Amz-Security-Token": videoInfo["session_token"]
          },
          xAmzHeadersCommon: {
            "X-Amz-Security-Token": videoInfo["session_token"]
          }
        };

        Evaporate.create(config).then(
          evaporate => {
            evaporate.add(add_config).then(
              function(awsKey) {
                console.log("Successfully uploaded:", awsKey);
                ajax(`/brightcove/ingest/${videoInfo["video_id"]}`, {
                  type: "POST"
                }).then(() => {
                  console.log(
                    `Uploaded successfully, use [video=${
                      videoInfo["video_id"]
                    }]`
                  );
                });
              },
              function(reason) {
                console.log("Failed to upload:", reason);
              }
            );
          },
          function(reason) {
            console.log("Evaporate failed to initialize:", reason);
          }
        );
      });
    }
  }
});
