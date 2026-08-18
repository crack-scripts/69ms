"use strict";

const { ContainerBuilder, TextDisplayBuilder, SectionBuilder, SeparatorBuilder } = require("discord.js");
const { header, body, separator, section } = require("../ui/v2");
const { OBF_ICONS, OBF_COLORS, STATUS } = require("../ui/icons");
const deobfFunction = require("../../deobfFunction");

/**
 * Help command - shows all available commands and supported obfuscators.
 * @param {import("discord.js").Message} message
 * @param {import("discord.js").MessageFlags} flags
 * @returns {Promise<void>}
 */
async function run(message, flags) {
  const obfuscators = deobfFunction.obfuscators;

  // Build obfuscator list
  const obfList = obfuscators
    .map((o) => `**${o.display}** — ${o.blurb}`)
    .join("\n");

  // Build command sections
  const commands = [
    {
      name: ".help",
      desc: "Show this help message",
    },
    {
      name: ".detect <file|link|paste|reply>",
      desc: "Detect obfuscator type and confidence",
    },
    {
      name: ".deobf <file|link|paste|reply>",
      desc: "Deobfuscate and download the result",
    },
    {
      name: ".get <link>",
      desc: "Download a file from a URL",
    },
    {
      name: ".l <file|link|paste|reply>",
      desc: "Env-log using 69ms/httplog2.lua",
    },
    {
      name: ".dump <luraph file|link>",
      desc: "Dump Luraph obfuscated scripts",
    },
    {
      name: ".loadstringlog <file|link>",
      desc: "Capture loadstring payloads",
    },
  ];

  // Build container with all sections
  const container = new ContainerBuilder();

  // Header
  container.addTextDisplayComponents(header("📚", "69ms Bot Help"));

  container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));

  // Commands section
  for (const cmd of commands) {
    const cmdSection = new SectionBuilder().setTextDisplays([
      new TextDisplayBuilder().setContent(`**${cmd.name}**\n${cmd.desc}`),
    ]);
    container.addSectionComponents(cmdSection);
    container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
  }

  // Supported obfuscators section
  container.addTextDisplayComponents(new TextDisplayBuilder().setContent("## 🛡️ Supported Obfuscators"));
  container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
  container.addTextDisplayComponents(new TextDisplayBuilder().setContent(obfList));

  await message.reply({
    flags,
    components: [container],
  });
}

module.exports = {
  trigger: ".help",
  description: "Show help message",
  run,
};
