"use strict";

const fs = require("fs");
const path = require("path");

/**
 * Load configuration from .env file first, then fall back to config.json.
 * Environment variables take precedence over config.json values.
 */
function loadConfig() {
  // Try to load .env file
  const envPath = path.join(__dirname, "..", ".env");
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, "utf8");
    for (const line of envContent.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const eqIdx = trimmed.indexOf("=");
      if (eqIdx === -1) continue;
      const key = trimmed.slice(0, eqIdx).trim();
      const value = trimmed.slice(eqIdx + 1).trim();
      // Only set if not already in process.env
      if (process.env[key] === undefined) {
        process.env[key] = value;
      }
    }
  }

  // Load config.json as fallback
  const configPath = path.join(__dirname, "..", "config.json");
  let fileConfig = {};
  if (fs.existsSync(configPath)) {
    try {
      fileConfig = JSON.parse(fs.readFileSync(configPath, "utf8"));
    } catch (e) {
      console.error("[env] Failed to parse config.json:", e.message);
    }
  }

  // Build final config with precedence: env > fileConfig > defaults
  return {
    token: process.env.TOKEN || fileConfig.token,
    channelId: process.env.CHANNEL_ID || fileConfig.channelId,
    prefix: process.env.PREFIX || fileConfig.prefix || ".",
    timeoutMs: parseInt(process.env.TIMEOUT_MS || fileConfig.timeoutMs || "125000", 10),
    maxConcurrent: parseInt(process.env.MAX_CONCURRENT || fileConfig.maxConcurrent || "5", 10),
    logger: process.env.LOGGER || fileConfig.logger || "69ms/httplog2.lua",
    dumper: process.env.DUMPER || fileConfig.dumper || "69ms/luraphdump.lua",
    loadstringlog: process.env.LOADSTRINGLOG || fileConfig.loadstringlog || "69ms/loadstringlog.lua",
  };
}

const config = loadConfig();

module.exports = config;
