"use strict";

/**
 * Detection engine - runs every registered obfuscator's detect function
 * and returns results sorted by confidence.
 */

const registry = require("./supported");

/**
 * Run detection on all registered obfuscators.
 * @param {string} source - Lua source code to analyze
 * @returns {Array<{obfuscator: object, result: {matches: boolean, confidence: number, reasons: string[]}}>}
 */
function detect(source) {
  const results = [];

  for (const obfuscator of registry) {
    try {
      const result = obfuscator.detect(source);
      results.push({
        obfuscator,
        result: {
          matches: result.matches ?? false,
          confidence: result.confidence ?? 0,
          reasons: result.reasons ?? [],
        },
      });
    } catch (e) {
      // Detection errors are non-fatal
      results.push({
        obfuscator,
        result: { matches: false, confidence: 0, reasons: [`Detection error: ${e.message}`] },
      });
    }
  }

  // Sort by confidence descending
  results.sort((a, b) => b.result.confidence - a.result.confidence);

  return results;
}

module.exports = { detect };
