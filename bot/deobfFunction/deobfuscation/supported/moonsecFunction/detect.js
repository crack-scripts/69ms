"use strict";

/**
 * Moonsec / Moonveil detection heuristics.
 *
 * Signals:
 * - Watermark strings ("Moonsec v3 wrapped", "Moonveil", "IrisWare") → 0.95
 * - \\NNN byte-escape density (>200 hits) → 0.85
 * - string.char() wrapper pattern (>10 calls with escapes) → 0.75
 * - loadstring() fence (≥2 calls with escapes) → 0.7
 * - v3 wrapper closure shape → 0.9
 *
 * @param {string} source - Lua source code
 * @returns {{ matches: boolean, confidence: number, reasons: string[] }}
 */
function detect(source) {
  const reasons = [];
  let confidence = 0;

  if (!source || source.length < 50) {
    return { matches: false, confidence: 0, reasons: ["Source too short to analyze"] };
  }

  // 1) Watermark strings
  const watermarkPatterns = [
    /Moonsec\s*v?\s*3/i,
    /Moonveil/i,
    /IrisWare/i,
    /--\s*Moonsec\b/i,
    /moonsec/i,
    /moonveil_/i,
  ];

  let watermarkHits = 0;
  for (const pattern of watermarkPatterns) {
    if (pattern.test(source)) {
      watermarkHits++;
    }
  }

  if (watermarkHits >= 2) {
    reasons.push(`Multiple Moonsec watermarks found (${watermarkHits} markers)`);
    confidence = Math.max(confidence, 0.95);
  } else if (watermarkHits === 1) {
    reasons.push("Moonsec-related watermark found");
    confidence = Math.max(confidence, 0.8);
  }

  // 2) \\NNN byte-escape density (e.g., \92\108\117\97)
  const byteEscapeMatches = source.match(/\\(\d{2,3})/g);
  const byteEscapeCount = byteEscapeMatches ? byteEscapeMatches.length : 0;

  if (byteEscapeCount > 200) {
    reasons.push(`High byte-escape density (${byteEscapeCount} escapes)`);
    confidence = Math.max(confidence, 0.85);
  } else if (byteEscapeCount > 80) {
    reasons.push(`Moderate byte-escape density (${byteEscapeCount} escapes)`);
    confidence = Math.max(confidence, 0.65);
  }

  // 3) string.char() wrapper pattern
  const stringCharCalls = source.match(/string\.char\s*\(/g);
  const charCallCount = stringCharCalls ? stringCharCalls.length : 0;

  // Look for char calls containing numeric escapes
  const charWithEscapes = source.match(/string\.char\s*\(\s*\d+[^)]*\)/g);
  const charWithEscapeCount = charWithEscapes ? charWithEscapes.length : 0;

  if (charWithEscapeCount > 10) {
    reasons.push(`Heavy string.char() usage with numbers (${charWithEscapeCount} calls)`);
    confidence = Math.max(confidence, 0.75);
  } else if (charWithEscapeCount > 5) {
    reasons.push(`Moderate string.char() usage (${charWithEscapeCount} calls)`);
    confidence = Math.max(confidence, 0.5);
  }

  // 4) loadstring() fence
  const loadstringCalls = source.match(/loadstring\s*\(/g);
  const loadstringCount = loadstringCalls ? loadstringCalls.length : 0;

  // Loadstring with escaped content
  const loadstringWithEscapes = source.match(/loadstring\s*\(\s*["'][^"']*\\\d{2,3}/g);
  const loadstringEscapeCount = loadstringWithEscapes ? loadstringWithEscapes.length : 0;

  if (loadstringEscapeCount >= 2) {
    reasons.push(`Multiple loadstring calls with encoded content (${loadstringEscapeCount})`);
    confidence = Math.max(confidence, 0.7);
  } else if (loadstringCount >= 3) {
    reasons.push(`Multiple loadstring calls (${loadstringCount})`);
    confidence = Math.max(confidence, 0.5);
  }

  // 5) v3 wrapper closure shape
  // Moonsec v3 wraps code in (function(a,b,...) ... end)(...)
  const closurePattern = /\(function\s*\(\s*\w+\s*,\s*\w+\s*,\s*\.{3}\s*\)/;
  if (closurePattern.test(source)) {
    // Check for nested wrapper
    const nestedWrapper = source.match(/\(function\s*\([^)]*\.{3}[^)]*\)\s*\(/g);
    if (nestedWrapper && nestedWrapper.length >= 2) {
      reasons.push(`Moonsec v3-style nested wrapper closures detected (${nestedWrapper.length})`);
      confidence = Math.max(confidence, 0.9);
    }
  }

  const matches = confidence >= 0.3;

  return {
    matches,
    confidence: Math.min(confidence, 1),
    reasons: reasons.length > 0 ? reasons : ["No Moonsec-specific signals found"],
  };
}

module.exports = { detect };