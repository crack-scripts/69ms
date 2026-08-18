"use strict";

/**
 * Ironbrew v1 / Ironveil detection heuristics.
 *
 * Signals:
 * - Watermark ("IronBrew", "Ironveil") → 0.95
 * - v1 dispatcher loop pattern → 0.85
 * - Single/double-letter local pool (≥6 triples) → 0.6
 * - string.char() identifier builder (>6 calls) → 0.45
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
    /IronBrew/i,
    /Ironveil/i,
    /ironbrew/i,
    /ironveil/i,
    /--\s*Iron\s*Brew/i,
    /IB\s*v1/i,
  ];

  let watermarkHits = 0;
  for (const pattern of watermarkPatterns) {
    if (pattern.test(source)) watermarkHits++;
  }

  if (watermarkHits >= 2) {
    reasons.push(`Multiple Ironbrew watermarks found (${watermarkHits} markers)`);
    confidence = Math.max(confidence, 0.95);
  } else if (watermarkHits === 1) {
    reasons.push("Ironbrew-related watermark found");
    confidence = Math.max(confidence, 0.8);
  }

  // 2) v1 dispatcher loop pattern
  // Ironbrew v1 uses a specific while-loop dispatcher with opcode indexing
  const dispatcherPatterns = [
    /while\s+\w+\s*\[?\s*\w+\s*\]?\s*>\s*0\s+do/i,
    /local\s+\w+\s*=\s*\{\s*[\d.,\s]+\s*\}/,
    /\w+\s*=\s*\w+\s*\[\s*\w+\s*\]\s*\(\s*\.{3}\s*\)/,
    /pcall\s*\(\s*coroutine\.wrap/i,
  ];

  let dispatcherHits = 0;
  for (const pattern of dispatcherPatterns) {
    if (pattern.test(source)) dispatcherHits++;
  }

  if (dispatcherHits >= 2) {
    reasons.push(`Ironbrew v1 dispatcher patterns found (${dispatcherHits} signals)`);
    confidence = Math.max(confidence, 0.85);
  } else if (dispatcherHits === 1) {
    reasons.push("Possible dispatcher pattern detected");
    confidence = Math.max(confidence, 0.5);
  }

  // 3) Single/double-letter local pool (≥6 triples)
  // Ironbrew uses many single-letter locals like local a,b,c,d,e,f
  const localTriples = source.match(/local\s+[a-z]\s*,\s*[a-z]\s*,\s*[a-z]/g);
  const tripleCount = localTriples ? localTriples.length : 0;

  if (tripleCount >= 6) {
    reasons.push(`Large single-letter local pool (${tripleCount} triples)`);
    confidence = Math.max(confidence, 0.6);
  } else if (tripleCount >= 3) {
    reasons.push(`Moderate single-letter local pool (${tripleCount} triples)`);
    confidence = Math.max(confidence, 0.4);
  }

  // 4) string.char() identifier builder
  const charCalls = source.match(/string\.char\s*\(/g);
  const charCount = charCalls ? charCalls.length : 0;

  if (charCount > 6) {
    reasons.push(`Heavy string.char() usage (${charCount} calls)`);
    confidence = Math.max(confidence, 0.45);
  }

  const matches = confidence >= 0.3;

  return {
    matches,
    confidence: Math.min(confidence, 1),
    reasons: reasons.length > 0 ? reasons : ["No Ironbrew v1-specific signals found"],
  };
}

module.exports = { detect };