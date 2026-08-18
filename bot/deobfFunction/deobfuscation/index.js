"use strict";

/**
 * Deobfuscation engine - orchestrates detection and deobfuscation.
 */

const registry = require("./supported");
const { detect } = require("./detector");

/**
 * Detect obfuscator in source code.
 * @param {string} source - Lua source code
 * @returns {{ best: object|null, all: Array }}
 */
function runDetect(source) {
  const results = detect(source);
  const best = results.find((r) => r.result.matches && r.result.confidence > 0) || null;
  return { best, all: results };
}

/**
 * Attempt to deobfuscate source code using the most likely obfuscator.
 * @param {string} source - Lua source code
 * @param {string} [preferredObfuscator] - specific obfuscator to try
 * @returns {Promise<{code: string, obfuscator: object, notes?: string[]}>}
 */
async function runDeobfuscate(source, preferredObfuscator) {
  // If specific obfuscator requested, try it first
  if (preferredObfuscator) {
    const obf = registry.find((o) => o.name === preferredObfuscator);
    if (obf) {
      try {
        const result = await obf.deobfuscate(source);
        return { code: result.code, obfuscator: obf, notes: result.notes };
      } catch (e) {
        if (e.code === "UNSUPPORTED") {
          throw e;
        }
        // Fall through to auto-detect on other errors
      }
    }
  }

  // Auto-detect and try each obfuscator in order of confidence
  const { all } = runDetect(source);

  const errors = [];
  for (const { obfuscator, result } of all) {
    if (!result.matches && result.confidence === 0) continue;

    try {
      const deobfResult = await obfuscator.deobfuscate(source);
      return { code: deobfResult.code, obfuscator, notes: deobfResult.notes };
    } catch (e) {
      if (e.code === "UNSUPPORTED") {
        errors.push({ obfuscator, error: e.message });
      } else {
        throw e;
      }
    }
  }

  // All failed with UNSUPPORTED
  const err = new Error("No supported obfuscator succeeded");
  err.code = "UNSUPPORTED";
  err.tried = errors;
  throw err;
}

module.exports = {
  detect: runDetect,
  run: runDeobfuscate,
  obfuscators: registry,
  registry,
};
