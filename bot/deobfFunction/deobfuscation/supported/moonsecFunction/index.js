"use strict";

const { detect } = require("./detect");
const { deobfuscate } = require("./deobfuscate");

module.exports = {
  name: "moonsec",
  display: "Moonsec",
  blurb: "Detects and deobfuscates Moonsec-protected Lua scripts",
  detect,
  deobfuscate,
};
