"use strict";

const { ContainerBuilder, TextDisplayBuilder, SectionBuilder, SeparatorBuilder } = require("discord.js");
const { header, body, separator, errorContainer } = require("../ui/v2");
const { STATUS, STATUS_COLORS, OBF_ICONS, OBF_COLORS } = require("../ui/icons");
const { extractInputs } = require("../utils/fetcher");
const { analyzeSource, countShortLocals, estimateEntropy } = require("../utils/sourceStats");
const deobfFunction = require("../../deobfFunction");

const V2 = 1 << 6; // MessageFlags.IsComponentsV2

/**
 * Stats command — analyze source code statistics and run all detectors.
 * @param {import("discord.js").Message} message
 * @param {import("discord.js").MessageFlags} flags
 * @returns {Promise<void>}
 */
async function run(message, flags) {
  // Extract inputs
  const inputs = await extractInputs(message);
  if (inputs.length === 0) {
    const container = errorContainer(STATUS.warning, "No Input", "Send a `.lua` file, a link, or paste code directly.");
    await message.reply({ flags, components: [container] });
    return;
  }

  const source = inputs[0].text;
  const sourceTag = inputs[0].source;

  // Compute stats
  const stats = analyzeSource(source);
  const shortLocalCount = countShortLocals(source);
  const entropy = estimateEntropy(source);

  // Run detectors
  const { all } = deobfFunction.detect(source);

  // Build stats content
  const statsLines = [
    `**Bytes:** ${stats.bytes.toLocaleString()}`,
    `**Lines:** ${stats.lines.toLocaleString()}`,
    `**Characters:** ${(stats.bytes / 1024).toFixed(1)} KB`,
    `**Short local vars:** ${shortLocalCount}`,
    `**Entropy:** ${entropy.toFixed(2)}`,
    `**Source:** ${sourceTag}`,
  ];

  // Build detector opinions
  const detectorOpinions = all.map((r) => {
    const pct = Math.round(r.result.confidence * 100);
    const icon = OBF_ICONS[r.obfuscator.name] || "❓";
    const colorStr = pct >= 50 ? "🟢" : pct >= 20 ? "🟡" : "🔴";
    return `${icon} **${r.obfuscator.display}:** ${colorStr} ${pct}% — ${r.result.reasons.slice(0, 2).join("; ") || "no signals"}`;
  }).join("\n");

  // Best guess
  const best = all.find((r) => r.result.matches && r.result.confidence > 0);
  const bestGuess = best
    ? `${OBF_ICONS[best.obfuscator.name] || "❓"} **${best.obfuscator.display}** (${Math.round(best.result.confidence * 100)}%)`
    : "❓ **No match** — could be custom/unknown obfuscator or plain Lua";

  // Build container
  const container = new ContainerBuilder();
  container.addTextDisplayComponents(header("📊", "Source Statistics"));
  container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));

  // Raw stats section
  container.addTextDisplayComponents(new TextDisplayBuilder().setContent("## 📈 Raw Stats"));
  container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
  container.addTextDisplayComponents(body(statsLines.join("\n")));
  container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));

  // Detector opinions section
  container.addTextDisplayComponents(new TextDisplayBuilder().setContent("## 🔬 Detector Opinions"));
  container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
  container.addTextDisplayComponents(body(detectorOpinions));
  container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));

  // Best guess
  container.addTextDisplayComponents(new TextDisplayBuilder().setContent("## 🎯 Best Guess"));
  container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
  container.addTextDisplayComponents(body(bestGuess));

  container.setAccentColor(best ? OBF_COLORS[best.obfuscator.name] || STATUS_COLORS.info : STATUS_COLORS.warning);

  await message.reply({ flags, components: [container] });
}

module.exports = {
  trigger: ".stats",
  description: "Analyze source code statistics and detector opinions",
  run,
};