"use strict";

/**
 * Public surface of the deobfFunction module.
 * Re-exports detection and deobfuscation functions.
 */

const deobf = require("./deobfuscation");

module.exports = {
  /**
   * Detect obfuscator in source code.
   * @param {string} source - Lua source code
   * @returns {{ best: object|null, all: Array }}
   */
  detect: (source) => deobf.detect(source),

  /**
   * Deobfuscate source code.
   * @param {string} source - Lua source code
   * @param {string} [preferredObfuscator] - specific obfuscator to try
   * @returns {Promise<{code: string, obfuscator: object, notes?: string[]}>}
   */
  run: (source, preferredObfuscator) => deobf.run(source, preferredObfuscator),

  /**
   * Registry of all supported obfuscators.
   * @type {Array}
   */
  obfuscators: deobf.obfuscators,

  /**
   * Direct access to the deobfuscation module.
   */
  deobf,
};
