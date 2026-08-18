"use strict";

const { ContainerBuilder, TextDisplayBuilder, SeparatorBuilder, AttachmentBuilder } = require("discord.js");
const { header, body, errorContainer } = require("../ui/v2");
const { STATUS, STATUS_COLORS } = require("../ui/icons");
const { extractUrl, fetchText, filenameFromUrl, fileSizeFromUrl } = require("../utils/fetcher");

const V2 = 1 << 6; // MessageFlags.IsComponentsV2

/**
 * Get command - download a file from a URL.
 * @param {import("discord.js").Message} message
 * @param {import("discord.js").MessageFlags} flags
 * @returns {Promise<void>}
 */
async function run(message, flags) {
  const url = extractUrl(message.content);
  if (!url) {
    const container = errorContainer(
      STATUS.warning,
      "No URL Provided",
      "Give me a link to download: `.get <link>`"
    );
    await message.reply({ flags, components: [container] });
    return;
  }

  const start = Date.now();
  const filename = filenameFromUrl(url);

  // Show downloading state
  const loadingCont = new ContainerBuilder();
  loadingCont.addTextDisplayComponents(header("📥", "Downloading…"));
  loadingCont.addTextDisplayComponents(body(`Fetching ${url}`));
  loadingCont.setAccentColor(STATUS_COLORS.loading);

  const statusMsg = await message.reply({ flags, components: [loadingCont] });

  try {
    let body;
    let err;

    try {
      body = await fetchText(url, "Roblox/WinInet");
    } catch (e) {
      err = e.message;
    }

    const secs = ((Date.now() - start) / 1000).toFixed(2);

    if (err) {
      const container = errorContainer(
        STATUS.error,
        "Download Failed",
        `Failed in ${secs}s: ${err}`
      );
      await statusMsg.edit({ components: [container] });
      return;
    }

    if (!body) {
      const container = errorContainer(
        STATUS.warning,
        "Empty Response",
        `Got empty response in ${secs}s`
      );
      await statusMsg.edit({ components: [container] });
      return;
    }

    const sizeBytes = Buffer.byteLength(body, "utf8");
    if (sizeBytes > 9_000_000) {
      const container = errorContainer(
        STATUS.warning,
        "File Too Large",
        `Response too large (${(sizeBytes / 1e6).toFixed(1)} MB) to attach`
      );
      await statusMsg.edit({ components: [container] });
      return;
    }

    const sizeMB = (sizeBytes / (1024 * 1024)).toFixed(2);

    // Build success container
    const container = new ContainerBuilder();
    container.addTextDisplayComponents(header("✅", "Download Complete"));
    container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
    container.addTextDisplayComponents(
      body(
        `**URL:** ${url}\n` +
          `**Filename:** ${filename}\n` +
          `**Size:** ${sizeMB} MB\n` +
          `**Time:** ${secs}s`
      )
    );
    container.setAccentColor(STATUS_COLORS.success);

    const file = new AttachmentBuilder(Buffer.from(body, "utf8"), { name: filename });

    await statusMsg.edit({ components: [container], files: [file] });
  } catch (e) {
    console.error("[get] error:", e);
    const container = errorContainer(
      STATUS.error,
      "Download Failed",
      `An error occurred: ${e.message}`
    );
    await statusMsg.edit({ components: [container] });
  }
}

module.exports = {
  trigger: ".get",
  description: "Download a file from a URL",
  run,
};
