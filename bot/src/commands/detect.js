"use strict";

const { ContainerBuilder, TextDisplayBuilder, SectionBuilder, SeparatorBuilder, ButtonBuilder, ButtonStyle } = require("discord.js");
const { header, body, separator, section, loadingContainer, errorContainer, nextSpinner, resetSpinner } = require("../ui/v2");
const { STATUS, STATUS_COLORS } = require("../ui/icons");
const deobfFunction = require("../../deobfFunction");
const { extractInputs } = require("../utils/fetcher");

const V2 = 1 << 6; // MessageFlags.IsComponentsV2

/**
 * Detect command - identify obfuscator type in source code.
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
  const loadingContainer = new ContainerBuilder();
  loadingContainer.addTextDisplayComponents(header("🔍", "Detecting…"));
  loadingContainer.addTextDisplayComponents(
    new TextDisplayBuilder().setContent(`Analyzing ${sourceTag}…`)
  );
  loadingContainer.setAccentColor(STATUS_COLORS.loading);

  loadingMsg = await message.reply({ flags, components: [loadingContainer] });

  const startTime = Date.now();

  // Animate spinner
  const animationInterval = setInterval(async () => {
    const spinner = nextSpinner();
    const loadingCont = new ContainerBuilder();
    loadingCont.addTextDisplayComponents(header("🔍", "Detecting…"));
    loadingCont.addTextDisplayComponents(
      new TextDisplayBuilder().setContent(`Analyzing ${sourceTag}… ${spinner}`)
    );
    loadingCont.setAccentColor(STATUS_COLORS.loading);
    try {
      await loadingMsg.edit({ components: [loadingCont] });
    } catch {
      clearInterval(animationInterval);
    }
  }, 350);

  try {
    const { best, all } = deobfFunction.detect(source);
    clearInterval(animationInterval);

    const elapsed = Date.now() - startTime;

    if (!best || best.result.confidence === 0) {
      // No match found
      const container = new ContainerBuilder();
      container.addTextDisplayComponents(header("❌", "Detection Complete"));
      container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
      container.addTextDisplayComponents(
        body(
          `**No supported obfuscator matched**\n\n` +
            `All detectors returned 0% confidence for this source.\n\n` +
            `Source: ${sourceTag}\n` +
            `Time: ${elapsed}ms`
        )
      );
      container.setAccentColor(STATUS_COLORS.warning);

      await loadingMsg.edit({ components: [container] });
      return;
    }

    // Build confidence reasons
    const reasonsText = best.result.reasons.length > 0
      ? best.result.reasons.map((r) => `• ${r}`).join("\n")
      : "No specific reasons returned";

    const otherResults = all
      .filter((r) => r !== best && r.result.confidence > 0)
      .map((r) => `• ${r.obfuscator.display}: ${Math.round(r.result.confidence * 100)}%`)
      .join("\n");

    // Build result container
    const container = new ContainerBuilder();
    container.addTextDisplayComponents(
      header("✅", `Detected: ${best.obfuscator.display}`)
    );
    container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));

    const bodyText =
      `**Confidence:** ${Math.round(best.result.confidence * 100)}%\n\n` +
      `**Why:**\n${reasonsText}\n\n` +
      (otherResults ? `**Other matches:**\n${otherResults}\n\n` : "") +
      `**Next:** Run \`.deobf\` to deobfuscate\n\n` +
      `Source: ${sourceTag} • Time: ${elapsed}ms`;

    container.addTextDisplayComponents(body(bodyText));
    container.setAccentColor(STATUS_COLORS.success);

    // Add button for next action
    const deobfBtn = new ButtonBuilder()
      .setLabel("Run .deobf")
      .setCustomId(`deobf:${best.obfuscator.name}`)
      .setStyle(ButtonStyle.Success);

    const actionRow = new SectionBuilder()
      .setTextDisplays([new TextDisplayBuilder().setContent("_")])
      .setButtonAccessory(deobfBtn);

    container.addSectionComponents(actionRow);

    await loadingMsg.edit({ components: [container] });
  } catch (e) {
    clearInterval(animationInterval);
    console.error("[detect] error:", e);
    const container = errorContainer(
      STATUS.error,
      "Detection Failed",
      `An error occurred: ${e.message}`
    );
    await loadingMsg.edit({ components: [container] });
  }
}

module.exports = {
  trigger: ".detect",
  description: "Detect obfuscator type in source code",
  run,
};
