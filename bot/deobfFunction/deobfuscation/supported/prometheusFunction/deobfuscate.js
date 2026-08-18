"use strict";

const { runObfuscator } = require("../../../luneRunner");

/**
 * Prometheus deobfuscation via lune runner.
 * @param {string} source - Lua source code
 * @param {object} [opts]
 * @param {number} [opts.timeoutMs]
 * @returns {Promise<{ code: string, notes?: string[] }>}
 */
async function deobfuscate(source, opts = {}) {
  return runObfuscator("prometheus", source, opts);
}

module.exports = { deobfuscate };