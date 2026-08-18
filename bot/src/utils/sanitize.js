"use strict";

/**
 * Scrub absolute paths, usernames, and internal script references
 * before any output leaves the bot (privacy).
 */
function sanitize(s) {
  if (!s) return "";
  return String(s)
    // Internal 69ms scripts referenced by absolute path -> "internal"
    .replace(
      /(?<![A-Za-z])[A-Za-z]:\\[^"'`\s)\]]*?69ms[\\/](?:httplog2|luraphdump|loadstringlog)(?::\d+)?/gi,
      "internal"
    )
    // Any remaining Windows drive paths -> <path>
    .replace(/(?<![A-Za-z])[A-Za-z]:\\[^"'`\s)\]]+/g, "<path>")
    // Unix home paths -> <path>
    .replace(/\/(?:home|Users)\/[^\s"'`\)\]:/]+/g, "<path>")
    // Common internal paths
    .replace(/\/home\/[^\/\s]+/g, "<path>")
    .replace(/C:\\Users\\[^\\]+/gi, "<path>");
}

module.exports = sanitize;
