import UploadMixin from "discourse/mixins/upload";

export default Ember.Component.extend(UploadMixin, {
  uploadDone(upload) {
    console.log("Upload done", upload);
  }
});
