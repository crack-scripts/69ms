"use strict";

const path = require("path");
const fs = require("fs/promises");
const { AttachmentBuilder } = require("discord.js");
const { runLune, LUNE_BIN } = require("./lune");
const { extractInputs, filenameFromUrl } = require("./fetcher");
const sanitize = require("./sanitize");

const DUMPS_IN = path.join(__dirname, "..", "..", "..", "dumps", "original");
const DUMPS_OUT = path.join(__dirname, "..", "..", "..", "dumps", "dumped");

/**
 * Shared job runner for .l, .dump, .loadstringlog commands.
 * @param {import("discord.js").Message} message
 * @param {object} options
 * @param {string} options.script - relative path to lua script
 * @param {string} [options.validate] - validation regex pattern (e.g., "luraph")
 * @param {string} options.name - command name for messages
 * @param {number} options.timeoutMs
 * @param {number} options.maxConcurrent
 * @param {import("discord.js").InteractionReplyOptions} loadingMsg
 */
async function runLuneCommand(message, options, loadingMsg) {
  const { script, validate, name, timeoutMs, maxConcurrent } = options;

  // Ensure dump directories exist
  await fs.mkdir(DUMPS_IN, { recursive: true });
  await fs.mkdir(DUMPS_OUT, { recursive: true });

  // Get command prefix length
  const prefix = (message.content || "").trim().toLowerCase().split(" ")[0];
  const commandLen = prefix.length;

  // Extract inputs from message
  const inputs = await extractInputs(message);
  if (inputs.length === 0) {
    return {
      type: "error",
      content: "Send a `.lua`/`.txt` file, a raw link, or paste the code directly.",
    };
  }

  // Filter by validation if needed
  if (validate) {
    const validInputs = [];
    for (const inp of inputs) {
      if (validate === "luraph" && !/(?:luraph|does your environment support load\/loadstring)/i.test(inp.text)) {
        validInputs.push({
          ...inp,
          _invalid: true,
          _reason: "Not recognized as Luraph format",
        });
      } else {
        validInputs.push(inp);
      }
    }
    inputs.length = 0;
    inputs.push(...validInputs);
  }

  const repoRoot = path.join(__dirname, "..", "..", "..");
  let processed = 0;
  const results = [];
  let running = 0;
  const waiting = [];

  async function processInput(resolved, idx) {
    const base = `${message.id}-${idx}`;
    const inName = `${base}.lua`;
    const inPath = path.join(DUMPS_IN, inName);
    const outPath = path.join(DUMPS_OUT, `${base}.lua`);

    if (resolved._invalid) {
      return {
        type: "invalid",
        source: resolved.source,
        reason: resolved._reason,
      };
    }

    await fs.writeFile(inPath, resolved.text, "utf8");
    await fs.rm(outPath, { force: true }).catch(() => {});

    try {
      const res = await runLune(script, inName, repoRoot, timeoutMs);

      let output = null;
      try {
        output = await fs.readFile(outPath, "utf8");
      } catch {
        // No output file
      }

      if (res.timedOut) {
        return {
          type: "timeout",
          source: resolved.source,
          seconds: res.seconds,
        };
      }

      if (!output || !output.trim()) {
        return {
          type: "error",
          source: resolved.source,
          detail: sanitize((res.stderr || "").slice(-400)).trim(),
        };
      }

      // Add note if couldn't parse
      if (output.includes("[69ms] couldn't parse")) {
        output += `\n-- (69ms received ${Buffer.byteLength(resolved.text, "utf8")} bytes via ${resolved.source})`;
      }

      return {
        type: "success",
        source: resolved.source,
        output: sanitize(output),
        seconds: res.seconds,
        inputName: resolved.source.startsWith("file:")
          ? resolved.source.slice(5).replace(/\.[^.]*$/, "").slice(0, 60) + ".dumped.lua"
          : "dumped.lua",
      };
    } finally {
      await fs.rm(inPath, { force: true }).catch(() => {});
      await fs.rm(outPath, { force: true }).catch(() => {});
    }
  }

  function runLimited(fn) {
    const start = async () => {
      running++;
      try {
        await fn();
      } catch (e) {
        console.error(`[luneCommand:${name}] error:`, e);
      } finally {
        running--;
        processed++;
        const next = waiting.shift();
        if (next) next();
      }
    };
    if (running < maxConcurrent) start();
    else waiting.push(start);
  }

  // Start processing all inputs
  for (let i = 0; i < inputs.length; i++) {
    runLimited(async () => {
      const result = await processInput(inputs[i], i);
      results.push(result);
    });
  }

  // Wait for all to complete
  await new Promise((resolve) => {
    const check = () => {
      if (processed >= inputs.length) resolve();
      else setTimeout(check, 100);
    };
    check();
  });

  return { type: "results", results };
}

module.exports = { runLuneCommand };
