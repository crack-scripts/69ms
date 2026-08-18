"use strict";

const path = require("path");
const fs = require("fs/promises");
const { spawn } = require("child_process");
const { randomUUID } = require("crypto");

/**
 * luneRunner.js — single source of truth for shelling out to `lune`.
 *
 * Contract:
 * 1. Writes user input to `<dumps>/deobf/<name>-<jobId>.in.lua`
 * 2. Spawns `lune run deobfFunction/tools/<name>.lua <in> <out>`
 *    with cwd = repoRoot
 * 3. Strips stderr, surfaces RUNNER_* errors
 * 4. Cleans up temp files
 *
 * The Lua runner must assign the deobfuscated source to `local decoded = ...`.
 */

const DUMPS_DEOBF = path.join(__dirname, "..", "..", "dumps", "deobf");

/**
 * Resolve lune binary path.
 * @returns {string}
 */
function resolveLune() {
  const { execSync } = require("child_process");
  try {
    const cmd = process.platform === "win32" ? "where lune" : "which lune";
    const first = execSync(cmd, { encoding: "utf8" }).split(/\r?\n/).filter(Boolean)[0];
    return first || "lune";
  } catch {
    return "lune";
  }
}

const LUNE_BIN = resolveLune();

/**
 * Run a Lua deobfuscator via lune.
 *
 * @param {string} name - obfuscator name (e.g. "moonsec")
 * @param {string} source - Lua source code to deobfuscate
 * @param {object} [opts]
 * @param {number} [opts.timeoutMs=125000]
 * @returns {Promise<{code: string, notes?: string[]}>}
 */
async function runObfuscator(name, source, opts = {}) {
  const timeoutMs = opts.timeoutMs || 125000;
  const jobId = randomUUID().slice(0, 8);

  const inFilename = `${name}-${jobId}.in.lua`;
  const outFilename = `${name}-${jobId}.out.lua`;

  const inPath = path.join(DUMPS_DEOBF, inFilename);
  const outPath = path.join(DUMPS_DEOBF, outFilename);

  const repoRoot = path.resolve(__dirname, "..", "..");
  const toolRel = path.relative(repoRoot, path.join(__dirname, "tools", `${name}.lua`));

  // Ensure dump dir exists
  await fs.mkdir(DUMPS_DEOBF, { recursive: true });

  // Write input file
  await fs.writeFile(inPath, source, "utf8");

  // Clear prior output
  try {
    await fs.rm(outPath, { force: true });
  } catch {
    // Ignore
  }

  const startTime = Date.now();
  let timedOut = false;
  let stderr = "";
  let exitCode = null;

  try {
    await new Promise((resolve, reject) => {
      const child = spawn(LUNE_BIN, ["run", toolRel, inPath, outPath], {
        cwd: repoRoot,
        stdio: ["ignore", "pipe", "pipe"],
        shell: false,
      });

      const timer = setTimeout(() => {
        timedOut = true;
        try {
          child.kill("SIGKILL");
        } catch {
          // Already dead
        }
      }, timeoutMs);

      child.stdout.on("data", () => {
        // We don't read stdout — output goes to outPath
      });

      child.stderr.on("data", (d) => {
        stderr += d.toString();
      });

      child.on("error", (e) => {
        clearTimeout(timer);
        reject(e);
      });

      child.on("close", (code) => {
        clearTimeout(timer);
        exitCode = code;
        resolve();
      });
    });
  } catch (e) {
    // Cleanup on spawn failure
    await fs.rm(inPath, { force: true }).catch(() => {});
    await fs.rm(outPath, { force: true }).catch(() => {});

    if (e.code === "ENOENT") {
      const err = new Error("lune binary not found on PATH");
      err.code = "RUNNER_SPAWN";
      throw err;
    }

    const err = new Error(`Spawn failed: ${e.message}`);
    err.code = "RUNNER_SPAWN";
    throw err;
  }

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);

  // Handle timeout
  if (timedOut) {
    await fs.rm(inPath, { force: true }).catch(() => {});
    await fs.rm(outPath, { force: true }).catch(() => {});
    const err = new Error(`lune runner exceeded ${timeoutMs}ms budget`);
    err.code = "RUNNER_TIMEOUT";
    throw err;
  }

  // Handle non-zero exit
  if (exitCode !== 0) {
    await fs.rm(inPath, { force: true }).catch(() => {});
    await fs.rm(outPath, { force: true }).catch(() => {});
    const details = stderr ? `: ${stderr.slice(0, 300).trim()}` : "";
    const err = new Error(`lune runner exited with code ${exitCode}${details}`);
    err.code = exitCode === 1 && stderr.includes("UNSUPPORTED") ? "UNSUPPORTED" : "RUNNER_SPAWN";
    throw err;
  }

  // Read output
  let output;
  try {
    output = await fs.readFile(outPath, "utf8");
  } catch {
    output = null;
  }

  // Cleanup temp files
  await fs.rm(inPath, { force: true }).catch(() => {});
  await fs.rm(outPath, { force: true }).catch(() => {});

  if (!output || output.trim().length === 0) {
    const err = new Error("Runner did not write output file");
    err.code = "RUNNER_NO_OUTPUT";
    throw err;
  }

  // Check for empty placeholder
  if (output.trim() === "-- [[69ms placeholder]]" || output.trim() === "local decoded = source -- [[placeholder]]") {
    const err = new Error("Deobfuscator returned placeholder output (not wired in yet)");
    err.code = "RUNNER_EMPTY";
    throw err;
  }

  const notes = [];
  if (Number(elapsed) > 10) {
    notes.push(`Deobfuscation took ${elapsed}s`);
  }

  return {
    code: output,
    notes: notes.length > 0 ? notes : undefined,
  };
}

module.exports = { runObfuscator, LUNE_BIN };