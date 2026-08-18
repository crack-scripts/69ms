"use strict";

const { ContainerBuilder, TextDisplayBuilder, SectionBuilder, SeparatorBuilder, AttachmentBuilder } = require("discord.js");
const { header, body, separator, loadingContainer, errorContainer, nextSpinner, resetSpinner } = require("../ui/v2");
const { STATUS, STATUS_COLORS, OBF_ICONS, OBF_COLORS } = require("../ui/icons");
const deobfFunction = require("../../deobfFunction");
const { extractInputs } = require("../utils/fetcher");
const sanitize = require("../utils/sanitize");

const V2 = 1 << 6; // MessageFlags.IsComponentsV2

/**
 * Deobfuscate command - deobfuscate Lua source code.
 * @param {import("discord.js").Message} message
 * @param {import("discord.js").MessageFlags} flags
 * @returns {Promise<void>}
 */
async function run(message, flags) {
  // Extract inputs
  const inputs = await extractInputs(message);
  if (inputs.length === 0) {
    const container = errorContainer(STATUS.error, "No Input", "Send a `.lua` file, a link, or paste code directly.");
    await message.reply({ flags, components: [container] });
    return;
  }

  const source = inputs[0].text;
  const sourceTag = inputs[0].source;

  // Show loading state
  resetSpinner();
  let loadingMsg;
  const loadingCont = new ContainerBuilder();
  loadingCont.addTextDisplayComponents(header("🔓", "Deobfuscating…"));
  loadingCont.addTextDisplayComponents(
    new TextDisplayBuilder().setContent(`Processing ${sourceTag}…`)
  );
  loadingCont.setAccentColor(STATUS_COLORS.loading);

  loadingMsg = await message.reply({ flags, components: [loadingCont] });

  const startTime = Date.now();

  // Animate spinner
  const animationInterval = setInterval(async () => {
    const spinner = nextSpinner();
    const spinCont = new ContainerBuilder();
    spinCont.addTextDisplayComponents(header("🔓", "Deobfuscating…"));
    spinCont.addTextDisplayComponents(
      new TextDisplayBuilder().setContent(`Processing ${sourceTag}… ${spinner}`)
    );
    spinCont.setAccentColor(STATUS_COLORS.loading);
    try {
      await loadingMsg.edit({ components: [spinCont] });
    } catch {
      clearInterval(animationInterval);
    }
  }, 350);

  try {
    const result = await deobfFunction.run(source);
    clearInterval(animationInterval);

    const elapsed = Date.now() - startTime;
    const obfColor = OBF_COLORS[result.obfuscator.name] || STATUS_COLORS.success;

    // Build notes text
    const notesText = result.notes && result.notes.length > 0
      ? `\n\n**Notes:**\n${result.notes.map((n) => `• ${n}`).join("\n")}`
      : "";

    // Create result container
    const container = new ContainerBuilder();
    container.addTextDisplayComponents(
      header("✅", `Deobfuscated: ${result.obfuscator.display}`)
    );
    container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));

    const bodyText =
      `**Deobfuscation successful!**\n\n` +
      `Obfuscator: ${result.obfuscator.display}\n` +
      `Output size: ${result.code.length.toLocaleString()} chars\n` +
      `Time: ${elapsed}ms` +
      notesText;

    container.addTextDisplayComponents(body(bodyText));
    container.setAccentColor(obfColor);

    // Create the output file
    const outputFilename = `deobfuscated.${Date.now()}.lua`;
    const file = new AttachmentBuilder(
      Buffer.from(sanitize(result.code), "utf8"),
      { name: outputFilename }
    );

    await loadingMsg.edit({ components: [container], files: [file] });
  } catch (e) {
    clearInterval(animationInterval);
    console.error("[deobf] error:", e);

    if (e.code === "UNSUPPORTED") {
      // Build list of what was tried
      let triedList = "No obfuscator matched this source.";

      if (e.tried && e.tried.length > 0) {
        triedList =
          "**Detectors tried:**\n" +
          e.tried.map((t) => `• ${t.obfuscator.display}`).join("\n");
      }

      const container = new ContainerBuilder();
      container.addTextDisplayComponents(header("❌", "Not Supported"));
      container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
      container.addTextDisplayComponents(
        body(
          `**This obfuscator is not yet supported.**\n\n` +
            triedList +
            `\n\nSource: ${sourceTag}`
        )
      );
      container.setAccentColor(STATUS_COLORS.warning);

      await loadingMsg.edit({ components: [container] });
      return;
    }

    const container = errorContainer(
      STATUS.error,
      "Deobfuscation Failed",
      `An error occurred: ${sanitize(e.message)}`
    );
    await loadingMsg.edit({ components: [container] });
  }
}

module.exports = {
  trigger: ".deobf",
  description: "Deobfuscate Lua source code",
  run,
};
