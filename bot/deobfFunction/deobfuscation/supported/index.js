"use strict";

/**
 * Registry of all supported obfuscators.
 * Add new obfuscators here by importing their module and adding to the array.
 * This is the ONLY place to register new obfuscators.
 */

// Import obfuscator modules
const moonsec = require("./moonsecFunction");
const irobbrew = require("./irobbrewFunction");
const irobbrew2 = require("./irobbrew2Function");
const prometheus = require("./prometheusFunction");

/**
 * @type {Array<{name: string, display: string, blurb: string, detect: Function, deobfuscate: Function}>}
 */
const registry = [
  moonsec,
  irobbrew,
  irobbrew2,
  prometheus,
];

module.exports = registry;
