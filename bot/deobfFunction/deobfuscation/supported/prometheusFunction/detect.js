"use strict";

/**
 * Prometheus / LuaObfuscator detection heuristics.
 *
 * Signals:
 * - Watermark ("Prometheus obfuscated|wrapped") → 0.95
 * - Long random-string pool near top of file → 0.85
 * - Short-identifier density (>80 short locals) → 0.7
 * - Bytecode-style table indexing (table.create, select('#', …)) → 0.5
 * - bit library referenced → 0.35
 * - _ENV proxy guard → 0.4
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

  // 1) Watermark
  const watermarkPatterns = [
    /Prometheus\s+obfuscated/i,
    /Prometheus\s+wrapped/i,
    /LuaObfuscator\b/i,
    /luaobfuscator/i,
    /--\s*Prometheus\b/i,
    /obfuscated\s+by\s+prometheus/i,
  ];

  let watermarkHits = 0;
  for (const pattern of watermarkPatterns) {
    if (pattern.test(source)) watermarkHits++;
  }

  if (watermarkHits >= 2) {
    reasons.push(`Multiple Prometheus watermarks found (${watermarkHits} markers)`);
    confidence = Math.max(confidence, 0.95);
  } else if (watermarkHits === 1) {
    reasons.push("Prometheus watermark found");
    confidence = Math.max(confidence, 0.85);
  }

  // 2) Long random-string pool near top
  // Prometheus puts a large table of random-looking strings at the top
  const lines = source.split(/\r?\n/);
  const topLines = lines.slice(0, Math.min(30, lines.length)).join("\n");

  const stringPoolPattern = /\{\s*["'][a-zA-Z0-9_]{8,}["']\s*,\s*["'][a-zA-Z0-9_]{8,}["']/g;
  const stringPoolMatches = topLines.match(stringPoolPattern);

  if (stringPoolMatches) {
    const poolSize = stringPoolMatches.length;
    if (poolSize >= 5) {
      reasons.push(`Large random-string pool near top (${poolSize}+ entries)`);
      confidence = Math.max(confidence, 0.85);
    } else if (poolSize >= 2) {
      reasons.push(`Random-string pool detected (${poolSize} entries)`);
      confidence = Math.max(confidence, 0.6);
    }
  }

  // 3) Short-identifier density
  // Prometheus uses many single-letter variable names
  const shortIdentifiers = source.match(/\blocal\s+[a-z]\b/gi);
  const shortIdentCount = shortIdentifiers ? shortIdentifiers.length : 0;

  if (shortIdentCount > 80) {
    reasons.push(`Very high short-identifier density (${shortIdentCount} short locals)`);
    confidence = Math.max(confidence, 0.7);
  } else if (shortIdentCount > 40) {
    reasons.push(`High short-identifier density (${shortIdentCount} short locals)`);
    confidence = Math.max(confidence, 0.5);
  } else if (shortIdentCount > 20) {
    reasons.push(`Moderate short-identifier density (${shortIdentCount} short locals)`);
    confidence = Math.max(confidence, 0.3);
  }

  // 4) Bytecode-style table indexing
  const bytecodePatterns = [
    /table\.create\s*\(/,
    /select\s*\(\s*['"]#['"]\s*,/,
    /select\s*\(\s*#\s*,/,
    /rawget\s*\(\s*_ENV\s*,/,
    /rawset\s*\(\s*_ENV\s*,/,
  ];

  let bytecodeHits = 0;
  for (const pattern of bytecodePatterns) {
    if (pattern.test(source)) bytecodeHits++;
  }

  if (bytecodeHits >= 2) {
    reasons.push(`Bytecode-style table indexing (${bytecodeHits} patterns)`);
    confidence = Math.max(confidence, 0.5);
  }

  // 5) bit library referenced
  if (/\bbit\b/.test(source) && (source.includes("bit.band") || source.includes("bit.bor") || source.includes("bit.bxor"))) {
    reasons.push("bit library referenced (bit.band/bor/bxor)");
    confidence = Math.max(confidence, 0.35);
  }

  // 6) _ENV proxy guard
  const envGuardPatterns = [
    /local\s+\w+\s*=\s*_\s*ENV\s*or\s*getfenv/,
    /_ENV\s*=\s*_\s*ENV\s*or\s*\{\}/,
    /getfenv\s*\(\s*0\s*\)/,
    /setfenv\s*\(/,
  ];

  let envGuardHits = 0;
  for (const pattern of envGuardPatterns) {
    if (pattern.test(source)) envGuardHits++;
  }

  if (envGuardHits >= 2) {
    reasons.push(`_ENV proxy guard patterns (${envGuardHits})`);
    confidence = Math.max(confidence, 0.4);
  } else if (envGuardHits === 1) {
    reasons.push("_ENV guard detected");
    confidence = Math.max(confidence, 0.25);
  }

  const matches = confidence >= 0.3;

  return {
    matches,
    confidence: Math.min(confidence, 1),
    reasons: reasons.length > 0 ? reasons : ["No Prometheus-specific signals found"],
  };
}

module.exports = { detect };