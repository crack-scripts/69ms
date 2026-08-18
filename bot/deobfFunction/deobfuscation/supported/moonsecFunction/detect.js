"use strict";

/**
 * Moonsec obfuscator detection stub.
 * TODO: Implement actual detection heuristics.
 * @param {string} source - Lua source code
 * @returns {{ matches: boolean, confidence: number, reasons: string[] }}
 */
function detect(source) {
  // TODO: Implement actual detection logic
  return {
    matches: false,
    confidence: 0,
    reasons: [],
  };
}

module.exports = { detect };
