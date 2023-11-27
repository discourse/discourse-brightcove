import { click, visit } from "@ember/test-helpers";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("Discourse Brightcove | upload modal", function (needs) {
  needs.user();
  needs.settings({
    brightcove_enabled: true,
  });

  test("can display modal", async (assert) => {
    await visit("/new-topic?category_id=1");
    await click(".d-editor-button-bar .brightcove-upload");
    assert.dom(".d-modal.brightcove-upload-modal").exists();
  });
});
