"use strict";

/**
 * 69ms Discord Bot
 * 
 * A Discord bot for Lua deobfuscation with Components v2 UI.
 * Supports: detect, deobfuscate, download, and env-log commands.
 */

const path = require("path");
const {
  Client,
  GatewayIntentBits,
  Events,
  MessageFlags,
} = require("discord.js");

const config = require("./src/utils/env");
const { loadCommands, matchCommand } = require("./src/loader");
const deobfFunction = require("./deobfFunction");

// MessageFlags.IsComponentsV2
const V2 = 1 << 6;

// Load all commands
const commands = loadCommands();

console.log(`[bot] Loaded ${commands.size} commands:`);
for (const [trigger, cmd] of commands) {
  console.log(`  ${trigger} — ${cmd.description}`);
}

console.log(`[bot] Registered ${deobfFunction.obfuscators.length} obfuscators:`);
for (const obf of deobfFunction.obfuscators) {
  console.log(`  ${obf.display} (${obf.name})`);
}

// Create Discord client
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

// Client ready
client.once(Events.ClientReady, (c) => {
  console.log(`[bot] Online as ${c.user.tag}`);
  console.log(`[bot] Listening in channel: ${config.channelId}`);
  console.log(`[bot] Command prefix: ${config.prefix}`);
});

// Message handler
client.on(Events.MessageCreate, async (message) => {
  // Ignore bots
  if (message.author.bot) return;

  // Only respond in configured channel
  if (message.channelId !== config.channelId) return;

  // Match command
  const matched = matchCommand(message.content, commands);
  if (!matched) {
    // Unknown command - send reminder
    const { ContainerBuilder, TextDisplayBuilder, SectionBuilder, SeparatorBuilder } = require("discord.js");
    const { header, body } = require("./src/ui/v2");
    const { STATUS } = require("./src/ui/icons");

    const triggers = [...commands.keys()].join(", ");

    const container = new ContainerBuilder();
    container.addTextDisplayComponents(header("🤖", "Unknown Command"));
    container.addSeparatorComponents(new SeparatorBuilder().setDivider(true).setSpacing(4));
    container.addTextDisplayComponents(
      body(
        `Available commands: ${triggers}\n\n` +
          `Type \`.help\` for a full list of commands.`
      )
    );
    container.setAccentColor(0x6b7280);

    await message.reply({ flags: V2, components: [container] }).catch(() => {});
    return;
  }

  // Run the command
  try {
    await matched.command.run(message, V2);
  } catch (e) {
    console.error(`[command:${matched.trigger}] error:`, e);
    const { ContainerBuilder, TextDisplayBuilder } = require("discord.js");
    const { header, errorContainer } = require("./src/ui/v2");
    const { STATUS } = require("./src/ui/icons");

    const container = errorContainer(
      STATUS.error,
      "Command Failed",
      `An error occurred: ${e.message}`
    );
    await message.reply({ flags: V2, components: [container] }).catch(() => {});
  }
});

// Error handlers
client.on(Events.Error, (e) => console.error("[client]", e));
process.on("unhandledRejection", (e) => console.error("[unhandledRejection]", e));

// Validate config
if (!config.token) {
  console.error("[bot] Error: TOKEN not set. Create .env or config.json with your bot token.");
  process.exit(1);
}

if (config.token.includes("YOUR_BOT_TOKEN")) {
  console.error("[bot] Error: Please set a real bot token in .env or config.json.");
  process.exit(1);
}

if (!config.channelId) {
  console.error("[bot] Error: CHANNEL_ID not set. Create .env or config.json with your channel ID.");
  process.exit(1);
}

// Start
console.log("[bot] Starting...");
client.login(config.token).catch((e) => {
  console.error("[bot] Login failed:", e.message);
  process.exit(1);
});
