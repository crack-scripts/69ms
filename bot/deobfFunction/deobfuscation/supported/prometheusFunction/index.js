"use strict";

const { detect } = require("./detect");
const { deobfuscate } = require("./deobfuscate");

module.exports = {
  name: "prometheus",
  display: "Prometheus",
  blurb: "Detects and deobfuscates Prometheus-protected Lua scripts",
  detect,
  deobfuscate,
};
