"use strict";

const path = require("path");
const fs = require("fs");
const { ContainerBuilder, TextDisplayBuilder, SectionBuilder, SeparatorBuilder } = require("discord.js");
const { header, body, separator, errorContainer } = require("../ui/v2");
const { STATUS, STATUS_COLORS, OBF_ICONS } = require("../ui/icons");
const deobfFunction = require("../../deobfFunction");

const V2 = 1 << 6; // MessageFlags.IsComponentsV2

/**
 * Check if a lune runner has real code wired in (beyond the placeholder).
 * @param {string} name - obfuscator name
 * @returns {{ ready: boolean, placeholders: string[] }}
 */
function checkRunnerState(name) {
  const luaPath = path.join(__dirname, "..", "..", "deobfFunction", "tools", `${name}.lua`);
  const placeholders = [];

  try {
    if (!fs.existsSync(luaPath)) {
      return { ready: false, placeholders: ["File missing"] };
    }

    const content = fs.readFileSync(luaPath, "utf8");

    // Check if the placeholder markers haven't been filled
    if (content.includes("-- BEGIN USER DEOBF") && content.includes("-- END USER DEOBF")) {
      // Check if the code between markers is still placeholder
      const beginIdx = content.indexOf("-- BEGIN USER DEOBF");
      const endIdx = content.indexOf("-- END USER DEOBF");
      const between = content.slice(beginIdx, endIdx);

      if (between.includes("local decoded = source") || between.length < 80) {
        placeholders.push("Between BEGIN/END markers: still using placeholder (local decoded = source)");
      }
    }

    // Check if decoded assignment uses source directly
    if (content.includes("local decoded = source")) {
      placeholders.push("Has placeholder 'local decoded = source'");
    }

    return {
      ready: placeholders.length === 0,
      placeholders,
    };
  } catch (e) {
    return { ready: false, placeholders: [`Read error: ${e.message}`] };
  }
}

/**
 * Check if lune is on PATH.
 * @returns {boolean}
 */
function checkLuneAvailable() {
  try {
    const { execSync } = require("child_process");
    const cmd = process.platform === "win32" ? "where lune" : "which lune";
    execSync(cmd, { encoding: "utf8", stdio: "pipe" });
    return true;
  } catch {
    return false;
  }
}

/**
 * Tools command — list each runner's state and wiring status.
 * @param {import("discord.js").Message} message
 * @param {import("discord.js").MessageFlags} flags
 * @returns {Promise<void>}
 */
async function run(message, flags) {
  const luneOk = checkLuneAvailable();
  const obfuscators = deobfFunction.obfuscators;

  // Build runner status lines
  const runnerLines = [];
  for (const obf of obfuscators) {
    const state = checkRunnerState(obf.name);
    const icon = state.ready ? "✅" : "⚠️";
    const statusText = state.ready
      ? `${icon} **${obf.display}** — ready to use`
      : `${icon} **${obf.display}** — placeholder`;

    runnerLines.push(statusText);

    if (state.placeholders.length > 0) {
      for (const p of state.placeholders) {
        runnerLines.push(`   └ ${p}`);
      }
    }
  }

  // Lune runtime status
  const luneStatus = luneOk ? "✅ lune found on PATH" : "❌ lune NOT found on PATH";
  runnerLines.push("");
  runnerLines.push(`**Runtime:** ${luneStatus}`);

  // Build wiring instructions
  const instructions = [
    "**How to wire a deobfuscator:**",
    "",
    "1. Download the open-source deobfuscator Lua (e.g. from the deobfuscation-Function repo)",
    "2. Open `deobfFunction/tools/<name>.lua`",
    "3. Paste your code between `-- BEGIN USER DEOBF` and `-- END USER DEOBF`",
    "4. Ensure the deobfuscated source ends up in `local decoded`",
    "5. Run `.tools` again to confirm it's ready",
    "6. Try `.deobf <some obfuscated .lua>`",
    "",
    "**Open-source references:**",
    "• https://github.com/crack-scripts/deobfuscation-Function",
  ];

  // Build container
  const container = new ContainerBuilder();
  container.addTextDisplayComponents(header("🔧", "Tool Status"));
  container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
  container.addTextDisplayComponents(body(runnerLines.join("\n")));
  container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
  container.addTextDisplayComponents(body(instructions.join("\n")));
  container.setAccentColor(STATUS_COLORS.info);

  await message.reply({ flags, components: [container] });
}

module.exports = {
  trigger: ".tools",
  description: "List each obfuscator runner's wiring status",
  run,
};