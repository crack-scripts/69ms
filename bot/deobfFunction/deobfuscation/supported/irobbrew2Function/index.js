"use strict";

const { detect } = require("./detect");
const { deobfuscate } = require("./deobfuscate");

module.exports = {
  name: "irobbrew2",
  display: "Irobbrew2",
  blurb: "Detects and deobfuscates Irobbrew v2-protected Lua scripts",
  detect,
  deobfuscate,
};
