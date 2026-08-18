"use strict";

/**
 * Source code statistics for .stats command.
 * Counts bytes, lines, identifiers, etc. No lune required.
 * Also runs all detectors and returns their opinions.
 */

/**
 * Analyze basic properties of a Lua source string.
 * @param {string} source
 * @returns {{ bytes: number, lines: number, identifiers: number, charCount: Record<string, number> }}
 */
function analyzeSource(source) {
  if (!source) {
    return { bytes: 0, lines: 0, identifiers: 0, charCount: {} };
  }

  const bytes = Buffer.byteLength(source, "utf8");
  const lines = source.split(/\r?\n/).length; // include trailing-empty
  const charCount = { letters: 0, digits: 0, spaces: 0, other: 0 };

  for (const ch of source) {
    if (/[a-zA-Z]/.test(ch)) charCount.letters++;
    else if (/[0-9]/.test(ch)) charCount.digits++;
    else if (/\s/.test(ch)) charCount.spaces++;
    else charCount.other++;
  }

  // Simple identifier count: local/function variable names
  const identifierMatches = source.match(/\b(local|function|end|if|then|else|for|while|do|repeat|until|return|break)\b/gi) || [];
  const identifiers = identifierMatches.length;

  return { bytes, lines, identifiers, charCount };
}

/**
 * Count short variable names (≤2 chars) — heuristic for obfuscation.
 * @param {string} source
 * @returns {number}
 */
function countShortLocals(source) {
  const matches = source.match(/\blocal\s+([a-zA-Z_][a-zA-Z0-9_]{0,2})\b/g) || [];
  return matches.length;
}

/**
 * Estimate entropy-like density metric.
 * @param {string} source
 * @returns {number}
 */
function estimateEntropy(source) {
  if (!source || source.length === 0) return 0;
  const freq = {};
  for (const ch of source) {
    freq[ch] = (freq[ch] || 0) + 1;
  }
  const len = source.length;
  let entropy = 0;
  for (const count of Object.values(freq)) {
    const p = count / len;
    entropy -= p * Math.log2(p);
  }
  return entropy;
}

module.exports = {
  analyzeSource,
  countShortLocals,
  estimateEntropy,
};