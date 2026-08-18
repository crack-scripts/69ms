"use strict";

/**
 * Irobbrew2 obfuscator deobfuscation stub.
 * TODO: Implement actual deobfuscation logic.
 * @param {string} source - Lua source code
 * @returns {Promise<{ code: string, notes?: string[] }>}
 */
async function deobfuscate(source) {
  // TODO: Implement actual deobfuscation logic
  const err = new Error("Irobbrew2 deobfuscation not implemented yet");
  err.code = "UNSUPPORTED";
  throw err;
}

module.exports = { deobfuscate };
