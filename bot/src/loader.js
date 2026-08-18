"use strict";

const path = require("path");
const fs = require("fs");

/**
 * Auto-load all command modules from src/commands/.
 * Commands are sorted by trigger length (longest first) for proper prefix matching.
 * @returns {Map<string, object>}
 */
function loadCommands() {
  const commandsDir = path.join(__dirname, "commands");
  const commands = new Map();

  const files = fs.readdirSync(commandsDir).filter((f) => f.endsWith(".js"));

  for (const file of files) {
    try {
      const cmd = require(path.join(commandsDir, file));
      if (cmd.trigger && typeof cmd.run === "function") {
        commands.set(cmd.trigger, cmd);
      }
    } catch (e) {
      console.error(`[loader] Failed to load ${file}:`, e.message);
    }
  }

  // Sort by trigger length descending (longest first)
  const sorted = [...commands.entries()].sort((a, b) => b[0].length - a[0].length);

  return new Map(sorted);
}

/**
 * Match a command from message content.
 * @param {string} content - message content
 * @param {Map<string, object>} commands
 * @returns {{ command: object, trigger: string }|null}
 */
function matchCommand(content, commands) {
  const trimmed = (content || "").trim().toLowerCase();
  const prefix = trimmed.split(/\s/)[0];

  // Find longest matching trigger
  for (const [trigger, cmd] of commands) {
    if (trigger.startsWith(".")) {
      // Commands start with dot
      if (trimmed === trigger || trimmed.startsWith(trigger + " ") || trimmed.startsWith(trigger + "\n")) {
        return { command: cmd, trigger };
      }
    }
  }

  return null;
}

module.exports = { loadCommands, matchCommand };
