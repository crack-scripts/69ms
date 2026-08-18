"use strict";

/**
 * Per-obfuscator display icons and accent colors.
 */
const OBF_ICONS = {
  moonsec: "🌙",
  irobbrew: "🍺",
  irobbrew2: "🍻",
  prometheus: "🔥",
  unknown: "❓",
};

const OBF_COLORS = {
  moonsec: 0x8b5cf6,    // Purple
  irobbrew: 0xf59e0b,   // Amber
  irobbrew2: 0xeab308,  // Yellow
  prometheus: 0xef4444, // Red
  unknown: 0x6b7280,    // Gray
};

/**
 * Status icons for various states.
 */
const STATUS = {
  loading: "⏳",
  success: "✅",
  error: "❌",
  info: "ℹ️",
  warning: "⚠️",
  waiting: "⏳",
};

/**
 * Accent colors for status states.
 */
const STATUS_COLORS = {
  success: 0x22c55e,  // Green
  error: 0xef4444,    // Red
  warning: 0xf59e0b,  // Amber
  info: 0x3b82f6,     // Blue
  danger: 0xdc2626,   // Dark Red
  loading: 0x6b7280,  // Gray
};

module.exports = {
  OBF_ICONS,
  OBF_COLORS,
  STATUS,
  STATUS_COLORS,
};
