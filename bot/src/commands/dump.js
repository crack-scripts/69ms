"use strict";

const { ContainerBuilder, TextDisplayBuilder, SectionBuilder, SeparatorBuilder, AttachmentBuilder } = require("discord.js");
const { header, body, loadingContainer, errorContainer, nextSpinner, resetSpinner } = require("../ui/v2");
const { STATUS, STATUS_COLORS } = require("../ui/icons");
const { runLuneCommand } = require("../utils/luneCommand");
const config = require("../utils/env");

const V2 = 1 << 6; // MessageFlags.IsComponentsV2

/**
 * .dump command - dump Luraph obfuscated scripts
 * @param {import("discord.js").Message} message
 * @param {import("discord.js").MessageFlags} flags
 * @returns {Promise<void>}
 */
async function run(message, flags) {
  // Show loading state
  resetSpinner();
  let loadingMsg;
  const loadingCont = new ContainerBuilder();
  loadingCont.addTextDisplayComponents(header("💾", "Processing…"));
  loadingCont.addTextDisplayComponents(body("Running Luraph dump…"));
  loadingCont.setAccentColor(STATUS_COLORS.loading);

  loadingMsg = await message.reply({ flags, components: [loadingCont] });

  // Animate spinner
  const animationInterval = setInterval(async () => {
    const spinner = nextSpinner();
    const spinCont = new ContainerBuilder();
    spinCont.addTextDisplayComponents(header("💾", "Processing…"));
    spinCont.addTextDisplayComponents(body(`Running Luraph dump… ${spinner}`));
    spinCont.setAccentColor(STATUS_COLORS.loading);
    try {
      await loadingMsg.edit({ components: [spinCont] });
    } catch {
      clearInterval(animationInterval);
    }
  }, 350);

  try {
    const result = await runLuneCommand(message, {
      script: config.dumper,
      validate: "luraph",
      name: "dump",
      timeoutMs: config.timeoutMs,
      maxConcurrent: config.maxConcurrent,
    });

    clearInterval(animationInterval);

    if (result.type === "error" && !result.results) {
      const container = errorContainer(STATUS.warning, "No Input", result.content);
      await loadingMsg.edit({ components: [container] });
      return;
    }

    // Process results
    const files = [];
    const errors = [];
    let totalTime = 0;

    for (const r of result.results) {
      if (r.type === "success") {
        files.push({ output: r.output, filename: r.inputName });
        totalTime += r.seconds;
      } else if (r.type === "invalid") {
        errors.push(`• ${r.source}: ${r.reason}`);
      } else if (r.type === "timeout") {
        errors.push(`• ${r.source}: Timed out after ${r.seconds.toFixed(1)}s`);
      } else if (r.type === "error") {
        errors.push(`• ${r.source}: ${r.detail || "Failed"}`);
      }
    }

    // Build result container
    const container = new ContainerBuilder();
    container.addTextDisplayComponents(header("✅", "Dump Complete"));
    container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));

    const bodyText =
      (files.length > 0
        ? `**Processed:** ${files.length} Luraph file(s)\n**Total time:** ${totalTime.toFixed(2)}s`
        : "No files processed") +
      (errors.length > 0 ? `\n\n**Issues:**\n${errors.join("\n")}` : "");

    container.addTextDisplayComponents(body(bodyText));
    container.setAccentColor(files.length > 0 ? STATUS_COLORS.success : STATUS_COLORS.warning);

    // Attach files
    const attachments = files.map((f) =>
      new AttachmentBuilder(Buffer.from(f.output, "utf8"), { name: f.filename })
    );

    await loadingMsg.edit({ components: [container], files: attachments.length > 0 ? attachments : [] });
  } catch (e) {
    clearInterval(animationInterval);
    console.error("[dump] error:", e);
    const container = errorContainer(STATUS.error, "Failed", `An error occurred: ${e.message}`);
    await loadingMsg.edit({ components: [container] });
  }
}

module.exports = {
  trigger: ".dump",
  description: "Dump Luraph obfuscated scripts",
  run,
};
