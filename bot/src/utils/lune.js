"use strict";

const { spawn, execSync } = require("child_process");

/**
 * Resolve the lune binary path once.
 * @type {string}
 */
const LUNE_BIN = (() => {
  try {
    const cmd = process.platform === "win32" ? "where lune" : "which lune";
    const first = execSync(cmd, { encoding: "utf8" }).split(/\r?\n/).filter(Boolean)[0];
    return first || "lune";
  } catch {
    return "lune";
  }
})();

/**
 * Run a lune script on a file.
 * @param {string} scriptRel - relative path to script (from repo root)
 * @param {string} fileName - filename to pass to script
 * @param {string} cwd - working directory (repo root)
 * @param {number} timeoutMs
 * @returns {Promise<{ok: boolean, seconds: number, stderr: string, code?: number, timedOut?: boolean}>}
 */
function runLune(scriptRel, fileName, cwd, timeoutMs) {
  return new Promise((resolve) => {
    const start = Date.now();
    let stderr = "";
    let timedOut = false;

    const child = spawn(LUNE_BIN, ["run", scriptRel, fileName], { cwd });
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, timeoutMs);

    child.stdout.on("data", () => {});
    child.stderr.on("data", (d) => (stderr += d.toString()));
    child.on("error", (e) => finish({ ok: false, seconds: 0, stderr: e.message }));
    child.on("close", (code) => finish({ ok: !timedOut && code === 0, code, timedOut }));

    function finish(extra) {
      clearTimeout(timer);
      resolve({ seconds: (Date.now() - start) / 1000, stderr, ...extra });
    }
  });
}

module.exports = { LUNE_BIN, runLune };
