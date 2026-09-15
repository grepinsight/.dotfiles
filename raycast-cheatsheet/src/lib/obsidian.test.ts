import { test } from "node:test";
import assert from "node:assert/strict";

import { advancedUri } from "./obsidian.ts";

test("builds an adv-uri carrying vault, path and line", () => {
  const uri = advancedUri({ vault: "Notes", filepath: "Git.md", line: 12 });

  assert.match(uri, /^obsidian:\/\/adv-uri\?/);
  assert.match(uri, /vault=Notes/);
  assert.match(uri, /filepath=Git\.md/);
  assert.match(uri, /line=12/);
});

test("always sends column=1", () => {
  // The plugin computes ch as Math.min(column - 1, lineLength). With no column
  // that is Math.min(NaN, n), so the cursor lands at NaN. Sending 1 pins ch 0.
  assert.match(
    advancedUri({ vault: "V", filepath: "a.md", line: 3 }),
    /column=1/,
  );
});

test("percent-encodes spaces in the folder and file name", () => {
  const uri = advancedUri({
    vault: "My Vault",
    filepath: "03-Resources/Quick Ref/Git Commands.md",
    line: 1,
  });

  assert.match(uri, /vault=My%20Vault/);
  assert.match(uri, /filepath=03-Resources%2FQuick%20Ref%2FGit%20Commands\.md/);
  assert.ok(!uri.includes(" "), "no raw spaces survive in a URI");
});

test("encodes characters that would otherwise split the query", () => {
  const uri = advancedUri({ vault: "V", filepath: "Notes/A&B #1.md", line: 2 });

  assert.ok(!/[^%]&B/.test(uri), "a literal & would start a new parameter");
  assert.ok(!uri.includes("#"), "a literal # would start a fragment");
  assert.match(uri, /line=2/);
});

test("encodes non-latin paths", () => {
  const uri = advancedUri({ vault: "V", filepath: "메모/한국어.md", line: 5 });

  assert.ok(!/[가-힣]/.test(uri));
  assert.match(uri, /filepath=%/);
});
