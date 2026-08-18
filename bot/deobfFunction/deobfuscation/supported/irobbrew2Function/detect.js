"use strict";

/**
 * Ironbrew v2 / ib2 detection heuristics.
 *
 * Signals:
 * - v2 watermark ("Ironbrew v2", "ib2") → 0.95
 * - _ENV wrapper / proxy → 0.55
 * - Big numeric constant pool → 0.5
 * - ib2 dispatch arithmetic pattern → 0.8
 * - pcall + setmetatable indirection (≥2 pcall) → 0.45
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

  // 1) v2 watermark
  const watermarkPatterns = [
    /Ironbrew\s*v2/i,
    /\bib2\b/i,
    /IronBrew2/i,
    /ib2_/i,
    /Ironbrew\s+v?\s*2/i,
    /--\s*ib2/i,
  ];

  let watermarkHits = 0;
  for (const pattern of watermarkPatterns) {
    if (pattern.test(source)) watermarkHits++;
  }

  if (watermarkHits >= 2) {
    reasons.push(`Multiple Ironbrew v2 watermarks found (${watermarkHits} markers)`);
    confidence = Math.max(confidence, 0.95);
  } else if (watermarkHits === 1) {
    reasons.push("Ironbrew v2 watermark found");
    confidence = Math.max(confidence, 0.8);
  }

  // 2) _ENV wrapper / proxy
  const envProxyPatterns = [
    /_ENV\s*=\s*\{\s*__index\s*=\s*_ENV\s*\}/,
    /setmetatable\s*\(\s*_ENV\s*,/,
    /getfenv\s*\(\s*\d+\s*\)/,
    /local\s+\w+\s*=\s*_ENV/,
  ];

  let envHits = 0;
  for (const pattern of envProxyPatterns) {
    if (pattern.test(source)) envHits++;
  }

  if (envHits >= 2) {
    reasons.push(`_ENV proxy/wrapper patterns found (${envHits})`);
    confidence = Math.max(confidence, 0.55);
  } else if (envHits === 1) {
    reasons.push("_ENV manipulation detected");
    confidence = Math.max(confidence, 0.3);
  }

  // 3) Big numeric constant pool
  // ib2 uses large tables of numbers for dispatch
  const numericTablePattern = /\{\s*-?\d+\s*,\s*-?\d+\s*,\s*-?\d+\s*,\s*-?\d+\s*,\s*-?\d+/g;
  const numTables = source.match(numericTablePattern);
  const numTableCount = numTables ? numTables.length : 0;

  // Count total numbers in tables
  const allNumbers = source.match(/\{\s*[\d.,\s-]{50,}\}/g);
  const bigTableCount = allNumbers ? allNumbers.length : 0;

  if (bigTableCount >= 3) {
    reasons.push(`Large numeric constant pools detected (${bigTableCount} big tables)`);
    confidence = Math.max(confidence, 0.5);
  }

  // 4) ib2 dispatch arithmetic pattern
  // ib2 uses arithmetic on opcodes like idx % N, idx // N, etc.
  const arithmeticPatterns = [
    /\w+\s*%\s*\d{2,4}/,
    /\w+\s*\/\/\s*\d{2,4}/,
    /%\s*\d{3,}/,
    /math\.floor\s*\(\s*\w+\s*\/\s*\d+/,
  ];

  let arithmeticHits = 0;
  for (const pattern of arithmeticPatterns) {
    if (pattern.test(source)) arithmeticHits++;
  }

  if (arithmeticHits >= 2) {
    reasons.push(`ib2 dispatch arithmetic detected (${arithmeticHits} patterns)`);
    confidence = Math.max(confidence, 0.8);
  }

  // 5) pcall + setmetatable indirection
  const pcallCount = (source.match(/pcall\s*\(/g) || []).length;
  const setmetaCount = (source.match(/setmetatable\s*\(/g) || []).length;

  if (pcallCount >= 2 && setmetaCount >= 1) {
    reasons.push(`pcall+setmetatable indirection (${pcallCount} pcall, ${setmetaCount} setmetatable)`);
    confidence = Math.max(confidence, 0.45);
  }

  const matches = confidence >= 0.3;

  return {
    matches,
    confidence: Math.min(confidence, 1),
    reasons: reasons.length > 0 ? reasons : ["No Ironbrew v2-specific signals found"],
  };
}

module.exports = { detect };