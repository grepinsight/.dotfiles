const raycast = require("@raycast/eslint-config");

module.exports = [
  { ignores: ["dist/**", "node_modules/**"] },
  ...raycast,
  {
    // The lib is plain Node and its tests run under `node --test`, not in the
    // Raycast runtime, so the extension-specific rules do not apply there.
    files: ["src/lib/*.test.ts"],
    rules: { "@typescript-eslint/no-non-null-assertion": "off" },
  },
];
