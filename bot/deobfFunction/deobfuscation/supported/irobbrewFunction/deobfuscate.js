"use strict";

const { runObfuscator } = require("../../../luneRunner");

/**
 * Ironbrew v1 deobfuscation via lune runner.
 * @param {string} source - Lua source code
 * @param {object} [opts]
 * @param {number} [opts.timeoutMs]
 * @returns {Promise<{ code: string, notes?: string[] }>}
 */
async function deobfuscate(source, opts = {}) {
  return runObfuscator("irobbrew", source, opts);
}

module.exports = { deobfuscate };