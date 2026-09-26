// functions/eslint.config.js — ESLint 10 flat config.
// Replaces .eslintrc.js (eslint-config-google doesn't support flat config).
// Runs before every deploy (firebase.json → predeploy → npm run lint).

const js = require("@eslint/js");
const globals = require("globals");

module.exports = [
  { ignores: ["node_modules/**"] },
  js.configs.recommended,
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: "commonjs",
      globals: { ...globals.node },
    },
    rules: {
      // Carried over from the old .eslintrc.js
      "no-restricted-globals": ["error", "name", "length"],
      "prefer-arrow-callback": "error",
      "quotes": ["error", "double", { allowTemplateLiterals: true, avoidEscape: true }],
      // Unused catch params / leading-underscore args are intentional here.
      "no-unused-vars": ["error", { argsIgnorePattern: "^_", caughtErrors: "none" }],
    },
  },
];
