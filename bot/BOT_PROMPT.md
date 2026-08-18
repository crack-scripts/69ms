# 69ms bot — Build Prompt (v2.1.0)

> **What this is**
> A complete, self-contained specification of everything the bot needs in
> order to run "out of the box" once the operator wires in their open-source
> Lua deobfuscator files.
>
> Two read paths:
> 1. **Reference / docs** — everything above the *████ Prompt* divider.
> 2. **Drop-in paste** — the fenced block under *████ Prompt* can be pasted
>    into a fresh session to rebuild the scaffold from scratch.

---

## Table of contents

1. [Goals](#goals)
2. [Status &amp; what runs out of the box](#status--what-runs-out-of-the-box)
3. [Folder layout](#folder-layout)
4. [Commands](#commands)
5. [Components v2 UI rules](#components-v2-ui-rules)
6. [`deobfFunction/` contract](#deobffunction-contract)
7. [Lune-runner pipeline](#lune-runner-pipeline)
8. [Detection heuristics (built-in)](#detection-heuristics-built-in)
9. [Config &amp; runtime](#config--runtime)
10. [Security](#security)
11. [How to wire in an open-source Lua deobfuscator](#how-to-wire-in-an-open-source-lua-deobfuscator)
12. [Suggested additions (optional)](#suggested-additions-optional)
13. [Do-NOT-touch list](#do-not-touch-list)
14. [████ Prompt — paste below ████](#████-prompt--paste-below-████)

---

## Goals

- A Discord bot for working with Lua scripts: **detect**, **deobfuscate**,
  **inspect**, **log**, **download**.
- **Every reply** uses Discord **Components v2** (no embeds, no `content`).
- Production-quality detect heuristics for Moonsec, Ironbrew v1, Ironbrew v2,
  Prometheus / LuaObfuscator — all four can immediately identify the right
  obfuscator.
- Pluggable deobfuscation runtime that streams an actual Lua deobfuscator
  via `lune` so the bot never has to mimic Lua semantics in JS.
- Folder-organized source code that a single person can navigate.
- Runs on Discord.js v14.16+, Node ≥ 18, with `lune` on `PATH`.

## Status &amp; what runs out of the box

| Component | State | Needs from you |
|---|---|---|
| `.help` | ✅ ready | — |
| `.detect` | ✅ ready | detectors are pre-built; works immediately |
| `.stats` | ✅ ready | — |
| `.get` | ✅ ready | — |
| `.tools` | ✅ ready | reports which Lua runners are wired in |
| `.l / .dump / .loadstringlog` | ✅ ready | `lune` on `PATH` |
| `.deobf` | ⚠ plumbing ready, output = input | paste your open-source Lua deobfuscator between the `BEGIN/END USER DEOBF` markers in `deobfFunction/tools/<name>.lua` |

Bottom line: **everything except `.deobf`'s actual algorithm works today**
out of the box. To make `.deobf` return real deobfuscated Lua,
paste your open-source deobfuscator Lua into the four runners (one
paragraph each, see `How to wire in an open-source Lua deobfuscator`
below).

## Folder layout

```
bot/
├── index.js                          # entry point
├── .env.example                      # config template
├── package.json
├── README.md
├── BOT_PROMPT.md                     # this file
├── config.example.json               # legacy back-compat
├── config.json                       # YOUR secrets, gitignored
├── src/
│   ├── loader.js                     # auto-load every src/commands/*.js
│   ├── ui/
│   │   ├── v2.js                     # Components v2 builders + send/edit
│   │   └── icons.js                  # accent colors + status emojis
│   ├── commands/                     # one file per command
│   │   ├── help.js                   # `.help`
│   │   ├── detect.js                 # `.detect`
│   │   ├── deobf.js                  # `.deobf`
│   │   ├── stats.js                  # `.stats`
│   │   ├── tools.js                  # `.tools`
│   │   ├── get.js                    # `.get`
│   │   ├── l.js                      # `.l`
│   │   ├── dump.js                   # `.dump`
│   │   └── loadstringlog.js          # `.loadstringlog`
│   └── utils/
│       ├── env.js                    # `.env`-aware config loader
│       ├── fetcher.js                # URL/attachment extraction + download
│       ├── sanitize.js               # path scrubber (privacy)
│       ├── lune.js                   # spawn `lune` for the existing tools
│       ├── luneCommand.js            # shared runner for .l/.dump/.loadstringlog
│       └── sourceStats.js            # for `.stats`
└── deobfFunction/
    ├── index.js                      # public surface
    ├── luneRunner.js                 # generic `lune run <name>.lua` spawner
    ├── tools/                        # PASTE your open-source Lua here
    │   ├── README.md                 # how to wire
    │   ├── moonsec.lua               # templates with BEGIN/END markers
    │   ├── irobbrew.lua
    │   ├── irobbrew2.lua
    │   └── prometheus.lua
    └── deobfuscation/
        ├── index.js                  # detect, run, registry, obfuscators
        ├── detector.js               # runs every detect.js in supported/
        └── supported/
            ├── index.js              # registry (the only place to add new ones)
            ├── moonsecFunction/
            │   ├── index.js
            │   ├── detect.js         # BUILT-IN heuristic
            │   └── deobfuscate.js    # uses moonsec.lua via luneRunner
            ├── irobbrewFunction/
            ├── irobbrew2Function/
            └── prometheusFunction/
```

## Commands

| Trigger | What the user sees | Backed by |
|---|---|---|
| `.help` | A Components v2 Container with one Section per command and the "Supported obfuscators" list, plus a setup status section | `commands/help.js` |
| `.detect <file\|link\|paste\|reply>` | Animated spinner → Container with confidence %, "Why" reasons, "Next: run `.deobf`" hint, source tag, ms timing | `commands/detect.js` + `deobfFunction` |
| `.deobf  <file\|link\|paste\|reply>` | Animated spinner → attached `.lua` file + Container with notes, **or** a "Not supported" Container listing every detector tried | `commands/deobf.js` + `deobfFunction` → `luneRunner` → `tools/<name>.lua` |
| `.stats <file\|link\|paste\|reply>` | Container with byte/lines/identifier counts + 4 detector opinions + best guess, **no `lune` required** | `commands/stats.js` + `utils/sourceStats.js` |
| `.tools` | Lists each runner's status (ready / placeholder / missing) and shows the recipe for wiring in | `commands/tools.js` |
| `.get   <link>` | Container with URL, filename, MB, attached file | `commands/get.js` |
| `.l     <…>` | Container with timing + attached dumped file | `commands/l.js` → `69ms/httplog2.lua` |
| `.dump  <luraph>` | Same shape; rejects non-luraph input | `commands/dump.js` → `69ms/luraphdump.lua` |
| `.loadstringlog <…>` | Same shape | `commands/loadstringlog.js` → `69ms/loadstringlog.lua` |

All replies set `flags: MessageFlags.IsComponentsV2`.

## Components v2 UI rules

1. **No embeds, no `content`** on v2 replies — only `components: [Container]` + optional `files`.
2. **Header per reply**: `# <icon> <title>` via `TextDisplay`.
3. **Body**: `TextDisplay` with Markdown.
4. **Grouping**: `SectionBuilder` with a button **accessory** for "Details" placeholders.
5. **Visual rhythm**: `SeparatorBuilder({ divider: true, spacing: "small" })` between sections. `setSpacing()` only accepts the **enum** `SeparatorSpacingSize.Small | .Large`, NOT a string.
6. **Loading state**: a Container whose `#` row stays the same while an inner `TextDisplay` cycles through a block-glyph spinner (`▏▎▍▌▋▊▉` family). Edit every ~350 ms via `message.edit({ components: [c], flags: V2 })`.
7. **Result styling**:
   - per-obfuscator accent color (`COLORS[obf]` in `src/ui/icons.js`)
   - per-obfuscator icon (`OBF_ICONS[obf]`)
   - the keyword **"not supported"** is reserved for the unsupported reply
   - never leak local paths or usernames; scrub with `sanitize()`
8. **Errors** go in a Container with `accent: danger` (red) and a short message.

## `deobfFunction/` contract

```js
// each obfuscator exports
module.exports = {
  name: "moonsec",                  // unique, lowercase, used for paths
  display: "Moonsec / Moonveil",    // user-facing label
  blurb: "...one-liner for `.help`...",
  detect:    (source: string) => DetectionResult,
  deobfuscate: (source: string, opts?: { timeoutMs: number }) => Promise<DeobfResult>,
};

// DetectionResult  -> { matches: boolean, confidence: 0..1, reasons: string[] }
// DeobfResult      -> { code: string, notes?: string[] }
```

`detect.js` is run for **every** registered obfuscator on each `.detect`
call — there is no early exit. If `confidence === 0` everywhere, the
"No supported obfuscator matched" reply is shown.

`deobfuscate.js` may throw. Distinguish:

| `err.code` value | What the bot shows |
|---|---|
| `"UNSUPPORTED"` | "Not supported" container listing every tried detector |
| `"RUNNER_SPAWN"` | "Deobfuscator failed: lune not found" |
| `"RUNNER_NO_OUTPUT"` | "Deobfuscator failed: runner did not write output" |
| `"RUNNER_TIMEOUT"` | "Deobfuscator failed: runner exceeded time budget" |
| `"RUNNER_EMPTY"` | "Deobfuscator failed: returned empty output" |
| anything else | generic "Deobfuscator failed" + sanitized message |

## Lune-runner pipeline

`deobfFunction/luneRunner.js` (the **single source of truth** for shelling
out to `lune`) does this for every `.deobf` invocation:

```
.deobf <src>
  ↓
moonsecFunction/deobfuscate.js(source)
  ↓ runObfuscator("moonsec", source, { timeoutMs })
deobfFunction/luneRunner.js
  ↓ dumps/deobf/moonsec-<jobId>.in.lua  <- writes user input
  ↓ dumps/deobf/moonsec-<jobId>.out.lua <- clears prior output
  ↓ spawn('lune', ['run', 'deobfFunction/tools/moonsec.lua',
                    'dumps/deobf/moonsec-<jobId>.in.lua',
                    'dumps/deobf/moonsec-<jobId>.out.lua'], { cwd: repoRoot })
  ↓ waits up to TIMEOUT_MS, then SIGKILL
  ↓ reads dumps/deobf/moonsec-<jobId>.out.lua
  ↓ cleans up input + output
return { code: <file contents>, notes: [...] }
```

Every obfuscator uses this same machinery. You only ever touch one file
per obfuscator: `deobfFunction/tools/<name>.lua`.

## Detection heuristics (built-in)

These are pre-built and run on every `.detect` and `.stats` call. You can
keep them, edit confidence weights, or replace them entirely. The
framework treats them as black boxes — `detector.js` simply sorts by
confidence and returns the highest.

### Moonsec / Moonveil
- Watermark strings ("Moonsec v3 wrapped", "Moonveil", "IrisWare", …) → `0.95`
- `\NNN` byte-escape density (`>200` hits) → `0.85`
- `string.char()` wrapper pattern (`>10` calls with escapes) → `0.75`
- `loadstring()` fence (`≥2` calls with escapes) → `0.7`
- v3 wrapper closure shape → `0.9`

### Ironbrew v1 / Ironveil
- Watermark (`IronBrew`, `Ironveil`) → `0.95`
- v1 dispatcher loop pattern → `0.85`
- Single/double-letter local pool (`≥6` triples) → `0.6`
- `string.char()` identifier builder (`>6` calls) → `0.45`

### Ironbrew v2 / ib2
- v2 watermark (`Ironbrew v2`, `ib2`) → `0.95`
- `_ENV` wrapper / proxy → `0.55`
- Big numeric constant pool → `0.5`
- ib2 dispatch arithmetic pattern → `0.8`
- pcall + setmetatable indirection (`≥2 pcall`) → `0.45`

### Prometheus / LuaObfuscator
- Watermark (`Prometheus obfuscated|wrapped`) → `0.95`
- Long random-string pool near top of file → `0.85`
- Short-identifier density (`>80` short locals) → `0.7`
- Bytecode-style table indexing (`table.create`, `select('#', …)`) → `0.5`
- `bit` library referenced → `0.35`
- `_ENV` proxy guard → `0.4`

These are tuned for typical fingerprints. You can tune the thresholds
inside each `detect.js`.

## Config &amp; runtime

| Source var / key | Default | Where |
|---|---|---|
| `TOKEN` / `config.token` | none (required) | login |
| `CHANNEL_ID` / `config.channelId` | none (required) | dispatch whitelist |
| `PREFIX` / `config.prefix` | `.` | trigger parser |
| `TIMEOUT_MS` / `config.timeoutMs` | `125000` | per-job kill (also `.deobf` budget) |
| `MAX_CONCURRENT` / `config.maxConcurrent` | `5` | concurrency cap for `.l/.dump/.loadstringlog` |
| `LOGGER` / `config.logger` | `69ms/httplog2.lua` | `.l` |
| `DUMPER` / `config.dumper` | `69ms/luraphdump.lua` | `.dump` |
| `LOADSTRINGLOG` / `config.loadstringlog` | `69ms/loadstringlog.lua` | `.loadstringlog` |

## Security

- `.env` **and** `config.json` are gitignored.
- Token defaults check: refused if it starts with `YOUR_BOT_TOKEN`.
- Sandbox folder is `dumps/{original,dumped,deobf}/`, sanitized in every output.
- `Message Content Intent` must be enabled in the Developer Portal.
- Never embed `lune` script paths verbatim in user-visible output.

## How to wire in an open-source Lua deobfuscator

The repos that contain ready-to-use Lua deobfuscators:

- https://github.com/crack-scripts/deobfuscation-Function (four zips:
  `moonveil deobf.zip`, `Ironveil-Deobfuscator-V1-main.zip`,
  `ib2-deobf.zip`, `LuaObfuscator-Deobfuscator-main.zip`)
- https://github.com/timmytim12354-png/dumper-and-env-loggers (env-loggers,
  useful as additional `.l` scripts)

For each deobfuscator you want:

1. Download the zip, find the **entry point** Lua file (the one that
   actually does the unwrap — usually `main.lua`, `src/main.lua`, or the
   file referenced by the `pcall(require, ...)` at the very top).
2. Open `bot/deobfFunction/tools/<name>.lua`.
3. Paste your entry-point Lua **between** the `BEGIN USER DEOBF` /
   `END USER DEOBF` markers.
4. Make sure your code ends with the deobfuscated source assigned to
   `local decoded = ...`. The bottom of the file already does
   `fs.writeFile(OUTPUT, decoded)`.
5. Run `.tools` in Discord — that obfuscator should now say `✅ ready`.
6. Try `.deobf <some obfuscated .lua>` to confirm.

Each `deobfFunction/tools/<name>.lua` ships with `process.args` already
bound to `INPUT` and `OUTPUT` so the rest of your code can read/write
the source directly without worrying about ARGV. See `tools/moonsec.lua`
for a working template.

> **Why this matters:** the JS-side `deobfuscate.js` only changes if the
> wire format changes. As long as your Lua runner follows
>
> `decoded = <deobfuscated source>`
>
> you never have to touch the bot to swap algorithms.

## Suggested additions (optional)

These were **not** implemented to keep the framework minimal. They are
listed here so you can prompt them in later passes without re-deriving
them.

- `.compare <a> <b>` — show original vs deobfuscated side-by-side.
- `.history [@user]` — last 10 jobs (`dumps/` + a small JSON log).
- Interactive `.help` — replace the disabled "Details" buttons with real
  `ButtonStyle.Primary` buttons whose `InteractionCreate` handler edits
  the reply to expand that command's docs in place.
- `feedback.json` — when `.detect` returns 0%, attach a "Report as X"
  button to the row of obfuscators and store the source → claimed-obfuscator
  pair for future tuning.
- Per-obfuscator `runsIn: "guildOnly"` flag — refuse `.deobf` in DMs for
  protected obfuscators.
- A test harness under `tests/` that feeds canned inputs through every
  registered detector and asserts confidence stays above a threshold.
- `lune`-less fallback: a pure-JS pretty-print pass that turns the
  raw obfuscated source into a formatted (still-obfuscated, but
  readable) version, so `.deobf` never returns completely empty even
  before you wire in the real deobfuscator (right now it returns input
  verbatim).

## Do-NOT-touch list

If you're an AI assistant continuing this work, **do not modify**:

- `deobfFunction/luneRunner.js` — the spawn contract is fixed
- The 4 `deobfuscation/supported/<name>Function/detect.js` heuristics —
  they are tuned by us; tune them only with care
- The Lua entry-point fragments you paste into
  `deobfFunction/tools/<name>.lua` — those are the user's own
  implementations

Everything else is fair game. The folder layout, command surfaces, and
detector registry are the stable surface area.

---

## ████ Prompt — paste below ████

```text
You are continuing the 69ms Discord bot. Build the exact folder structure
below and ensure every command runs end-to-end with Components v2 replies.
Do not rewrite the detector heuristics or break the lune-runner contract —
only fill in any missing files.

FOLDER LAYOUT (mirror this exactly)
- bot/index.js
- bot/.env.example
- bot/package.json          (discord.js ^14.16.3, commonjs, scripts: start, check)
- bot/README.md
- bot/BOT_PROMPT.md
- bot/src/loader.js         (auto-load src/commands/*.js; longest-trigger-first)
- bot/src/ui/v2.js          (Components v2 builders)
- bot/src/ui/icons.js       (colors + emojis, per-obfuscator + per-status)
- bot/src/commands/{help,detect,deobf,stats,tools,get,l,dump,loadstringlog}.js
- bot/src/utils/{env,fetcher,sanitize,lune,luneCommand,sourceStats}.js
- bot/deobfFunction/index.js
- bot/deobfFunction/luneRunner.js
- bot/deobfFunction/tools/{moonsec,irobbrew,irobbrew2,prometheus}.lua
- bot/deobfFunction/tools/README.md
- bot/deobfFunction/deobfuscation/{index.js, detector.js, supported/index.js}
- bot/deobfFunction/deobfuscation/supported/{moonsec,irobbrew,irobbrew2,prometheus}Function/{index,detect,deobfuscate}.js

COMMANDS (all replies MUST use Components v2 + MessageFlags.IsComponentsV2)
- `.help`             — Container listing all commands + supported obfuscators + setup status.
- `.detect <…>`       — Animated spinner → Container with confidence %, reasons, source tag.
- `.deobf  <…>`       — Animated spinner → attached `.lua` file OR "Not supported" Container.
- `.stats <…>`        — Container with bytes/lines/identifier counts + 4 detector opinions + best guess.
- `.tools`            — Container listing each runner's wired state with instructions.
- `.get    <link>`    — Container + attached file (no embeds, no content).
- `.l / .dump / .loadstringlog` — existing Lune scripts, Components v2 wrapper.

deobfFunction CONTRACT (DO NOT CHANGE)
- Each obfuscator exports { name, display, blurb, detect(src) -> {matches,confidence,reasons}, deobfuscate(src, opts) -> {code, notes?} }
- detect() errors are caught by `detector.js` and treated as {matches:false, confidence:0, reasons:["detector threw: …"]}.
- deobfuscate() may throw with `err.code` ∈
  {"UNSUPPORTED","RUNNER_SPAWN","RUNNER_NO_OUTPUT","RUNNER_TIMEOUT","RUNNER_EMPTY"}.
- Adding a new obfuscator: drop a new folder under `supported/`, register it in `supported/index.js`, drop a Lua runner in `tools/`. No other file changes are required.

LUNE RUNNER (DO NOT CHANGE)
- `luneRunner.js` is the single source of truth for shelling out to lune.
- It writes `<dumps>/deobf/<name>-<jobId>.in.lua` then spawns
    `lune run deobfFunction/tools/<name>.lua <in> <out>`
  with cwd = repo root.
- It strips stderr, surfaces RUNNER_* errors, and cleans up the temp files.
- The Lua runner only has to assign the deobfuscated source to a local named `decoded`.

LUA RUNNERS — ONLY fill-in required
The 4 Lua files currently end in `local decoded = source` (a placeholder).
To make `.deobf` return real deobfuscated output, the operator (or an
AI in a follow-up pass) writes the real deobfuscator BETWEEN the
`-- BEGIN USER DEOBF` and `-- END USER DEOBF` markers so that
`local decoded = <resulting Lua source string>`. Open-source references:
  - Ironveil-Deobfuscator-V1-main.zip   → irobbrew.lua
  - ib2-deobf.zip                       → irobbrew2.lua
  - moonveil deobf.zip                  → moonsec.lua
  - LuaObfuscator-Deobfuscator-main.zip → prometheus.lua
  (all from https://github.com/crack-scripts/deobfuscation-Function)

DETECT HEURISTICS (DO NOT CHANGE UNLESS ASKED)
The 4 detect.js files already produce 0.95 confidence on samples that
look like the matching obfuscator and 0% on plain Lua. Tighter tuning is
welcome but the public surface area is not.

COMPONENTS V2 RULES
1. No `content` or `embeds`; only `components: [Container]` and optional `files`.
2. Header via TextDisplay: `# <icon> <title>`.
3. SectionBuilder + button accessory for per-row Details placeholders.
4. SeparatorBuilder({ divider:true, spacing:"small" }); `setSpacing()` is enum-only.
5. Buttons reference `ButtonStyle.Primary|Secondary|Success|Danger|Link` enums.
6. Per-obfuscator accent color + icon. Keyword `not supported` is reserved.
7. Loading animation = container with '#' row unchanged + inner TextDisplay cycling
   `▏▎▍▌▋▊▉`-family glyphs every ~350 ms via `message.edit({ components, flags: V2 })`.
8. Errors → Container accent:danger (red) + short sanitized message.

ENVIRONMENT / CONFIG
.env preferred; falls back to config.json. Keys:
  TOKEN, CHANNEL_ID, PREFIX(.),
  TIMEOUT_MS(125000), MAX_CONCURRENT(5),
  LOGGER(69ms/httplog2.lua), DUMPER(69ms/luraphdump.lua),
  LOADSTRINGLOG(69ms/loadstringlog.lua).

QUALITY BAR
- `node --check` clean on all .js files.
- Loader auto-discovers every .js in src/commands/.
- Detectors all run on every .detect/.stats; sorted; top wins.
- `.tools` correctly reflects placeholder state from BEGIN/END markers + `local decoded = source`.
- `npm start` loads everything and only fails at `client.login()` without a real token.

DELIVERABLES
- Files matching the tree above.
- Updated README describing the wiring procedure for open-source Lua.
- Updated BOT_PROMPT.md (this file) — version-stamped in the title.
- Confirmation message summarizing what already runs vs. what still needs
  the Lua paste-in to enable end-to-end deobfuscation.

CRITICAL CONSTRAINTS (re-state for clarity)
- DO NOT change the JS-side detect.js heuristics unless explicitly tasked.
- DO NOT change the JS-side deobfuscate.js implementations — they call luneRunner.
- DO NOT change luneRunner.js's contract.
- DO NOT add embeds or `content` fields to any reply.
- DO respect Discord API limits: ≤4096 chars per TextDisplay, ≤9 MB per attachment.
```