import { default as computed } from "ember-addons/ember-computed-decorators";
import { ajax } from "discourse/lib/ajax";

const Evaporate = window.Evaporate;
const SparkMD5 = window.SparkMD5;

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
        return btoa(SparkMD5.ArrayBuffer.hash(data, true));
      },
      cryptoHexEncodedHash256: function(data) {
        return sha256(data);
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

// SHA256 algorithm from https://github.com/jbt/js-crypto/blob/master/sha256.js
/*eslint-disable */
const sha256 = (function() {
  // Eratosthenes seive to find primes up to 311 for magic constants. This is why SHA256 is better than SHA1
  var i = 1,
    j,
    K = [],
    H = [];

  while (++i < 18) {
    for (j = i * i; j < 312; j += i) {
      K[j] = 1;
    }
  }

  function x(num, root) {
    return ((Math.pow(num, 1 / root) % 1) * 4294967296) | 0;
  }

  for (i = 1, j = 0; i < 313; ) {
    if (!K[++i]) {
      H[j] = x(i, 2);
      K[j++] = x(i, 3);
    }
  }

  function S(X, n) {
    return (X >>> n) | (X << (32 - n));
  }

  function SHA256(b) {
    var HASH = H.slice((i = 0)),
      s = unescape(encodeURI(b)) /* encode as utf8 */,
      W = [],
      l = s.length,
      m = [],
      a,
      y,
      z;
    for (; i < l; )
      m[i >> 2] |= (s.charCodeAt(i) & 0xff) << (8 * (3 - (i++ % 4)));

    l *= 8;

    m[l >> 5] |= 0x80 << (24 - (l % 32));
    m[(z = ((l + 64) >> 5) | 15)] = l;

    for (i = 0; i < z; i += 16) {
      a = HASH.slice((j = 0), 8);

      for (; j < 64; a[4] += y) {
        if (j < 16) {
          W[j] = m[j + i];
        } else {
          W[j] =
            (S((y = W[j - 2]), 17) ^ S(y, 19) ^ (y >>> 10)) +
            (W[j - 7] | 0) +
            (S((y = W[j - 15]), 7) ^ S(y, 18) ^ (y >>> 3)) +
            (W[j - 16] | 0);
        }

        a.unshift(
          (y =
            ((a.pop() +
              (S((b = a[4]), 6) ^ S(b, 11) ^ S(b, 25)) +
              (((b & a[5]) ^ (~b & a[6])) + K[j])) |
              0) +
            (W[j++] | 0)) +
            (S((l = a[0]), 2) ^ S(l, 13) ^ S(l, 22)) +
            ((l & a[1]) ^ (a[1] & a[2]) ^ (a[2] & l))
        );
      }

      for (j = 8; j--; ) HASH[j] = a[j] + HASH[j];
    }

    for (s = ""; j < 63; )
      s += ((HASH[++j >> 3] >> (4 * (7 - (j % 8)))) & 15).toString(16);

    return s;
  }

  return SHA256;
})();
/*eslint-enable */
