"use strict";

const { fetch: globalFetch } = require("undici") || globalThis;

/**
 * Extract the first URL from text.
 * @param {string} text
 * @returns {string|null}
 */
function extractUrl(text) {
  if (!text) return null;
  const match = text.match(/https?:\/\/[^\s"'`<>\[\]]+/i);
  return match ? match[0] : null;
}

/**
 * Fetch text content from a URL.
 * @param {string} url
 * @param {string} [userAgent]
 * @returns {Promise<string>}
 */
async function fetchText(url, userAgent = "Mozilla/5.0 (compatible; 69ms-bot)") {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 20000);
  try {
    const res = await globalFetch(url, {
      signal: ctrl.signal,
      redirect: "follow",
      headers: { "User-Agent": userAgent },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.text();
  } finally {
    clearTimeout(t);
  }
}

/**
 * Get filename from URL. Keeps real extension, else defaults.
 * @param {string} url
 * @returns {string}
 */
function filenameFromUrl(url) {
  try {
    const base = new URL(url).pathname.split("/").filter(Boolean).pop() || "download";
    return /\.[a-z0-9]{1,6}$/i.test(base) ? base.slice(0, 80) : base.slice(0, 75) + ".txt";
  } catch {
    return "download.txt";
  }
}

/**
 * Get file size in MB from URL headers.
 * @param {string} url
 * @returns {Promise<number|null>}
 */
async function fileSizeFromUrl(url) {
  try {
    const res = await globalFetch(url, {
      method: "HEAD",
      redirect: "follow",
      headers: { "User-Agent": "Roblox/WinInet" },
    });
    const size = res.headers.get("content-length");
    return size ? parseInt(size, 10) / (1024 * 1024) : null;
  } catch {
    return null;
  }
}

/**
 * Strip ```lua ... ``` fences (or leading ```) from a message body.
 * @param {string} s
 * @returns {string}
 */
function unfence(s) {
  s = (s || "").trim();
  const block = s.match(/```(?:lua|luau)?\s*([\s\S]*?)```/i);
  if (block) return block[1].trim();
  return s.replace(/^```(?:lua|luau)?\s*/i, "").replace(/```$/i, "").trim();
}

/**
 * Extract all inputs from a message: attachments, links, and inline code.
 * @param {import("discord.js").Message} message
 * @param {string} [label] - label for link source
 * @returns {Promise<Array<{text: string, source: string}>>}
 */
async function extractInputs(message, label) {
  const out = [];

  // 1) Attachments
  const atts = [...message.attachments.values()].slice(0, 15);
  for (const a of atts) {
    try {
      out.push({ text: await fetchText(a.url), source: `file:${a.name || "attachment"}` });
    } catch {
      // Skip failed attachments
    }
  }

  // 2) Link in message
  const url = extractUrl(message.content);
  if (url) {
    try {
      out.push({ text: await fetchText(url), source: label ? `${label} link` : "link" });
    } catch {
      // Skip failed URLs
    }
  }

  // 3) Inline code (if no attachments or links)
  if (out.length === 0) {
    const code = unfence(message.content);
    if (code.length > 0) {
      out.push({ text: code, source: "inline paste" });
    }
  }

  // 4) Replied-to message content (if still no inputs)
  if (out.length === 0 && message.reference && message.reference.messageId) {
    try {
      const ref = await message.fetchReference();
      if (ref) {
        // Replied message attachments
        for (const a of [...ref.attachments.values()].slice(0, 15)) {
          try {
            out.push({ text: await fetchText(a.url), source: `replied file:${a.name || "attachment"}` });
          } catch {
            // Skip
          }
        }
        // Replied message link
        const refUrl = extractUrl(ref.content);
        if (refUrl) {
          try {
            out.push({ text: await fetchText(refUrl), source: "replied link" });
          } catch {
            // Skip
          }
        }
        // Replied message code
        const refCode = unfence(ref.content);
        if (refCode.length > 0 && !refUrl && ref.attachments.size === 0) {
          out.push({ text: refCode, source: "replied message" });
        }
      }
    } catch {
      // Skip failed references
    }
  }

  return out;
}

module.exports = {
  extractUrl,
  fetchText,
  filenameFromUrl,
  fileSizeFromUrl,
  unfence,
  extractInputs,
};
