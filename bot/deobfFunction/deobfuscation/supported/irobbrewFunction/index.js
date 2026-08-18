"use strict";

const { detect } = require("./detect");
const { deobfuscate } = require("./deobfuscate");

module.exports = {
  name: "irobbrew",
  display: "Irobbrew",
  blurb: "Detects and deobfuscates Irobbrew-protected Lua scripts",
  detect,
  deobfuscate,
};
