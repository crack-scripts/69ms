"use strict";

// 69ms logger bot
// .l            <file|link|paste> -> env-logs with 69ms/httplog2.lua
// .dump         <luraph file|link> -> dumps with 69ms/luraphdump.lua
// .loadstringlog<file|link>        -> captures loadstring payloads with 69ms/loadstringlog.lua
// .get          <link>             -> raw download (User-Agent: Roblox/WinInet), no logging
//
// Every reply is sent as a .lua file, tags the requester, and is path-sanitized
// so it never leaks local folders/usernames. Attach SEVERAL files and they're all
// dumped concurrently (up to maxConcurrent at a time). A job is killed after
// timeoutMs.

const path = require("path");
const fs = require("fs/promises");
const fsSync = require("fs");
const { spawn, execSync } = require("child_process");
const {
  Client,
  GatewayIntentBits,
  AttachmentBuilder,
  Events,
} = require("discord.js");

const config = require("./config.json");
const ROOT = path.resolve(__dirname, ".."); // repo root: where dumps/ and 69ms/ live
const DUMPS_IN = path.join(ROOT, "dumps", "original");
const DUMPS_OUT = path.join(ROOT, "dumps", "dumped");
const TIMEOUT_MS = config.timeoutMs || 60000;
const TIMEOUT_S = Math.round(TIMEOUT_MS / 1000);

fsSync.mkdirSync(DUMPS_IN, { recursive: true });
fsSync.mkdirSync(DUMPS_OUT, { recursive: true });

// command -> { script, validate, ping }
const COMMANDS = {
  ".loadstringlog": { script: config.loadstringlog, validate: null },
  ".dump": { script: config.dumper, validate: "luraph" },
  ".l": { script: config.logger, validate: null },
};

// Resolve the lune binary once so spawn() doesn't depend on shell/PATHEXT.
const LUNE_BIN = (() => {
  try {
    const cmd = process.platform === "win32" ? "where lune" : "which lune";
    const first = execSync(cmd, { encoding: "utf8" }).split(/\r?\n/).filter(Boolean)[0];
    return first || "lune";
  } catch {
    return "lune";
  }
})();

const URL_RE = /https?:\/\/[^\s"'`<>()\[\]]+/i;
const LURAPH_RE = /does your environment support load\/loadstring\?|luraph/i;

// Remove any absolute machine path / username before anything leaves the bot.
function sanitize(s) {
  if (!s) return "";
  // (?<![A-Za-z]) keeps "https://" URLs intact while scrubbing real "C:\..." paths.
  return String(s)
    // our own scripts referenced by absolute path -> "internal"
    .replace(/(?<![A-Za-z])[A-Za-z]:\\[^\s"'`)\]]*?69ms[\\/](?:httplog2|luraphdump|loadstringlog)(?::\d+)?/gi, "internal")
    // any remaining windows drive path -> <path>
    .replace(/(?<![A-Za-z])[A-Za-z]:\\[^\s"'`)\]]+/g, "<path>")
    // unix home paths -> <path>
    .replace(/\/(?:home|Users)\/[^\s"'`)\]:/]+/g, "<path>");
}

function extractUrl(text) {
  const m = (text || "").match(URL_RE);
  return m ? m[0] : null;
}

async function fetchText(url, userAgent) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 20000);
  try {
    const res = await fetch(url, {
      signal: ctrl.signal,
      redirect: "follow",
      headers: { "User-Agent": userAgent || "Mozilla/5.0 (69ms-logger)" },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.text();
  } finally {
    clearTimeout(t);
  }
}

// Best-effort filename from a URL (keeps a real extension, else .txt).
function fileNameFromUrl(url) {
  try {
    const base = new URL(url).pathname.split("/").filter(Boolean).pop() || "download";
    return /\.[a-z0-9]{1,6}$/i.test(base) ? base.slice(0, 80) : base.slice(0, 75) + ".txt";
  } catch {
    return "download.txt";
  }
}

// .get — raw download with the Roblox user-agent. No logging/analysis at all.
async function processGet(message) {
  const url = extractUrl(message.content);
  if (!url) {
    await message.reply({ content: "give me a link to `.get`", allowedMentions: { repliedUser: false } });
    return;
  }

  const status = await message.reply({ content: "getting…", allowedMentions: { repliedUser: false } });
  const start = Date.now();
  let body, err;
  try {
    body = await fetchText(url, "Roblox/WinInet");
  } catch (e) {
    err = e.message;
  }
  const secs = ((Date.now() - start) / 1000).toFixed(2);

  if (err != null) {
    await status.edit(`failed in ${secs}s: ${sanitize(err)}`);
    return;
  }
  if (!body) {
    await status.edit(`empty response in ${secs}s`);
    return;
  }
  if (Buffer.byteLength(body, "utf8") > 9_000_000) {
    await status.edit(`response too large to attach (${(Buffer.byteLength(body, "utf8") / 1e6).toFixed(1)} MB)`);
    return;
  }

  const file = new AttachmentBuilder(Buffer.from(body, "utf8"), { name: fileNameFromUrl(url) });
  await status.delete().catch(() => {});
  await message.reply({
    content: `<@${message.author.id}> done in ${secs}s`,
    files: [file],
    allowedMentions: { users: [message.author.id], repliedUser: true },
  });
}

// Pull every attachment + a link out of a single message.
async function attachmentsAndLink(msg, label) {
  const out = [];
  const atts = [...msg.attachments.values()].slice(0, 15);
  const fetched = await Promise.all(
    atts.map(async (a) => {
      try {
        return { text: await fetchText(a.url), source: `file:${a.name || "attachment"}` };
      } catch {
        return null;
      }
    })
  );
  for (const f of fetched) if (f) out.push(f);

  const url = extractUrl(msg.content);
  if (url) {
    try {
      out.push({ text: await fetchText(url), source: label ? `${label} link` : "link" });
    } catch {}
  }
  return out;
}

// Strip a single ```lua ... ``` fence (or leading ``` ) off a chat message body.
function unfence(s) {
  s = (s || "").trim();
  const block = s.match(/```(?:lua|luau)?\s*([\s\S]*?)```/i);
  if (block) return block[1].trim();
  return s.replace(/^```(?:lua|luau)?\s*/i, "").replace(/```$/i, "").trim();
}

// Resolve ALL inputs from a message: its own attachments/link/paste, AND — if the
// `.l` was sent as a REPLY — the replied-to message's file / link / code too.
// Returns an array of { text, source }.
async function resolveInputs(message, commandLen) {
  const inputs = [];

  // 1) the `.l` message's own attachments + link
  for (const i of await attachmentsAndLink(message)) inputs.push(i);

  // 2) if `.l` is a reply, log whatever the replied-to message carries
  if (message.reference && message.reference.messageId) {
    try {
      const ref = await message.fetchReference();
      if (ref) {
        for (const i of await attachmentsAndLink(ref, "replied")) inputs.push(i);
        // its code content (a ``` block or raw lua) if it had no file/link
        const code = unfence(ref.content);
        if (code.length > 0 && !extractUrl(ref.content) && ref.attachments.size === 0) {
          inputs.push({ text: code, source: "replied message" });
        }
      }
    } catch {}
  }

  // 3) inline paste after `.l ...`, only if nothing else was provided
  if (inputs.length === 0) {
    const rest = unfence((message.content || "").slice(commandLen));
    if (rest.length > 0) inputs.push({ text: rest, source: "inline paste" });
  }

  return inputs;
}

// Run a lune script on a saved filename (cwd = repo root). Resolves with timing.
function runLune(scriptRel, fileName) {
  return new Promise((resolve) => {
    const start = Date.now();
    let stderr = "";
    let timedOut = false;

    const child = spawn(LUNE_BIN, ["run", scriptRel, fileName], { cwd: ROOT });
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, TIMEOUT_MS);

    child.stdout.on("data", () => {}); // logger writes the trace to a file; ignore stdout
    child.stderr.on("data", (d) => (stderr += d.toString()));
    child.on("error", (e) => finish({ ok: false, error: e.message }));
    child.on("close", (code) => finish({ ok: !timedOut && code === 0, code, timedOut }));

    function finish(extra) {
      clearTimeout(timer);
      resolve({ seconds: (Date.now() - start) / 1000, stderr, ...extra });
    }
  });
}

function resultName(resolved) {
  if (resolved.source.startsWith("file:")) {
    return resolved.source.slice(5).replace(/\.[^.]*$/, "").slice(0, 60) + ".dumped.lua";
  }
  return "dumped.lua";
}

async function sendResult(message, status, secs, output, resolved) {
  // Always a sanitized .lua file + a tag, never an inline code block.
  const file = new AttachmentBuilder(Buffer.from(sanitize(output), "utf8"), { name: resultName(resolved) });
  await status.delete().catch(() => {});
  await message.reply({
    content: `<@${message.author.id}> done in ${secs}s — ${resolved.source}`,
    files: [file],
    allowedMentions: { users: [message.author.id], repliedUser: true },
  });
}

// Process ONE resolved input. `idx` keeps temp filenames unique across files.
async function processJob(message, spec, resolved, idx) {
  const base = `${message.id}-${idx}`;
  const inName = `${base}.lua`;
  const inPath = path.join(DUMPS_IN, inName);
  const outPath = path.join(DUMPS_OUT, `${base}.lua`);
  const input = resolved.text;
  const tag = resolved.source;

  if (spec.validate === "luraph" && !LURAPH_RE.test(input)) {
    await message.reply({
      content: `you can only provide luraph files (${tag})`,
      allowedMentions: { repliedUser: false },
    });
    return;
  }

  await fs.writeFile(inPath, input, "utf8");
  await fs.rm(outPath, { force: true }).catch(() => {});

  const status = await message.reply({
    content: `logging ${tag}…`,
    allowedMentions: { repliedUser: false },
  });

  try {
    const res = await runLune(spec.script, inName);

    if (res.timedOut) {
      await status.edit(`timed out after ${TIMEOUT_S}s — skipped (${tag})`);
      return;
    }

    let output = null;
    try {
      output = await fs.readFile(outPath, "utf8");
    } catch {
      /* no output file */
    }

    if (!output || !output.trim()) {
      const detail = sanitize((res.stderr || "").slice(-400)).trim();
      await status.edit(`failed (${tag})${detail ? `\n\`\`\`${detail}\`\`\`` : ""}`);
      return;
    }

    // If it couldn't parse, show exactly what was received so truncation is obvious.
    if (output.includes("[69ms] couldn't parse")) {
      output += `\n-- (69ms received ${Buffer.byteLength(input, "utf8")} bytes via ${tag})`;
    }

    await sendResult(message, status, res.seconds.toFixed(2), output, resolved);
  } finally {
    await fs.rm(inPath, { force: true }).catch(() => {});
    await fs.rm(outPath, { force: true }).catch(() => {});
  }
}

// ---- concurrency limiter: up to maxConcurrent jobs at once (not one-after-one) ----
const MAX_CONCURRENT = config.maxConcurrent || 5;
let running = 0;
const waiting = [];

function runLimited(fn) {
  const start = async () => {
    running++;
    try {
      await fn();
    } catch (e) {
      console.error("[job] error:", e);
    } finally {
      running--;
      const next = waiting.shift();
      if (next) next();
    }
  };
  if (running < MAX_CONCURRENT) start();
  else waiting.push(start);
}

function parseCommand(content) {
  const lower = (content || "").trim().toLowerCase();
  for (const [cmd, spec] of Object.entries(COMMANDS)) {
    if (lower === cmd || lower.startsWith(cmd + " ") || lower.startsWith(cmd + "\n")) {
      return { cmd, spec };
    }
  }
  return null;
}

// ---------------------------------- client ----------------------------------
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

client.once(Events.ClientReady, (c) => {
  console.log(`online as ${c.user.tag} | channel ${config.channelId} | lune: ${LUNE_BIN}`);
});

client.on(Events.MessageCreate, async (message) => {
  if (message.author.bot) return;
  if (message.channelId !== config.channelId) return;

  // .get is a plain download (no logging).
  const lower = (message.content || "").trim().toLowerCase();
  if (lower === ".get" || lower.startsWith(".get ") || lower.startsWith(".get\n")) {
    processGet(message).catch((e) => console.error("[get] error:", e));
    return;
  }

  const parsed = parseCommand(message.content);
  if (!parsed) return;

  if (!parsed.spec.script) {
    await message.reply({ content: `\`${parsed.cmd}\` is not configured`, allowedMentions: { repliedUser: false } });
    return;
  }

  let inputs;
  try {
    inputs = await resolveInputs(message, parsed.cmd.length);
  } catch (e) {
    console.error("[resolve] error:", e);
    return;
  }
  if (inputs.length === 0) {
    await message.reply({
      content: "send a `.lua`/`.txt` file (you can attach several) or a raw link",
      allowedMentions: { repliedUser: false },
    });
    return;
  }

  // dump every input concurrently (capped), not one-after-one
  inputs.forEach((inp, i) => runLimited(() => processJob(message, parsed.spec, inp, i)));
});

client.on(Events.Error, (e) => console.error("[client]", e));
process.on("unhandledRejection", (e) => console.error("[unhandledRejection]", e));

if (!config.token || config.token.includes("YOUR_BOT_TOKEN")) {
  console.error("Set your bot token in bot/config.json first.");
  process.exit(1);
}
client.login(config.token);
