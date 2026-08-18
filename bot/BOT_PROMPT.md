# 69ms bot — Build Prompt

> **Purpose of this file**
> Drop the section under "██ Prompt" into a fresh chat to get the same
> scaffold rebuilt from scratch, or use it as a checklist while hand-editing.
> Everything **above** the divider is reference/living docs.

---

## Table of contents

1. [Goals](#goals)
2. [Target folder layout](#target-folder-layout)
3. [Commands](#commands)
4. [Components v2 UI rules](#components-v2-ui-rules)
5. [`deobfFunction/` contract](#deobffunction-contract)
6. [Config & runtime](#config--runtime)
7. [Security](#security)
8. [How to add a new obfuscator](#how-to-add-a-new-obfuscator)
9. [Suggested additions (optional)](#suggested-additions-optional)
10. [Do-NOT-touch list](#do-not-touch-list)
11. [████ Prompt — paste below ████](#████-prompt--paste-below-████)

---

## Goals

- A Discord bot for working with Lua scripts: **detect**, **deobfuscate**,
  **log**, **download**.
- **Every reply** uses Discord **Components v2** (no embeds, no `content`).
- Folder-organized source code that a single human can navigate.
- A pluggable `deobfFunction/` framework so new obfuscators can be added
  *without* touching the bot.
- The actual deobfuscation logic stays yours (we ship pluggable stubs).
- Runs on Discord.js v14.16+, Node ≥ 18, with `lune` on `PATH` for
  `.l / .dump / .loadstringlog`.

## Target folder layout

```
bot/
├── index.js                          # minimal entry point: load → dispatch → login
├── .env.example                      # template (TOKEN, CHANNEL_ID, PREFIX, …)
├── package.json
├── README.md
├── BOT_PROMPT.md                     # this file
├── config.example.json               # legacy back-compat
├── config.json                       # YOUR secrets, gitignored
├── src/
│   ├── loader.js                     # auto-load every src/commands/*.js
│   ├── ui/
│   │   ├── v2.js                     # ContainerBuilder / SectionBuilder / etc.
│   │   └── icons.js                  # accent colors + status emojis
│   ├── commands/                     # one file per command (no manual registration)
│   │   ├── help.js                   # `.help`
│   │   ├── detect.js                 # `.detect`
│   │   ├── deobf.js                  # `.deobf`
│   │   ├── get.js                    # `.get`
│   │   ├── l.js                      # `.l`
│   │   ├── dump.js                   # `.dump`
│   │   └── loadstringlog.js          # `.loadstringlog`
│   └── utils/
│       ├── env.js                    # `.env`-aware config loader
│       ├── fetcher.js                # URL/attachment extraction + download
│       ├── sanitize.js               # path scrubber (privacy)
│       ├── lune.js                   # spawn `lune` for the existing tools
│       └── luneCommand.js            # shared runner for .l/.dump/.loadstringlog
└── deobfFunction/                    # PLUGGABLE; commands never reach inside
    ├── index.js                      # re-export the public surface
    └── deobfuscation/
        ├── index.js                  # `detect`, `run`, `obfuscators`, `registry`
        ├── detector.js               # runs every registered detect.js
        └── supported/
            ├── index.js              # registry (the only place to add new ones)
            ├── moonsecFunction/      # detect.js + deobfuscate.js + index.js
            ├── irobbrewFunction/
            ├── irobbrew2Function/
            └── prometheusFunction/
```

## Commands

| Trigger | What the user sees | Behavior |
|---|---|---|
| `.help` | A Components v2 Container with one Section per command and a "Supported obfuscators" list | Static; pulled from the registry |
| `.detect <file \| link \| paste \| reply>` | Animated spinner → result Container with confidence %, "Why" reasons, "Next: run `.deobf`" hint, source tag, ms timing | Calls `deobfFunction.detect(source)` |
| `.deobf <file \| link \| paste \| reply>` | Animated spinner → either **attached `.lua` file + Container with notes**, **or** a "Not supported" Container listing every detector tried | Calls `deobfFunction.run(source)`; on `UNSUPPORTED` shows the tried list |
| `.get <link>` | "Downloading…" → Container with URL, filename, MB size, attached file | Raw GET with `Roblox/WinInet` UA |
| `.l <…>` | "Processing…" → Container with timing + attached dumped file | Runs `69ms/httplog2.lua` |
| `.dump <luraph ...>` | Same shape; rejects non-luraph input with a Container | Runs `69ms/luraphdump.lua` |
| `.loadstringlog <…>` | Same shape | Runs `69ms/loadstringlog.lua` |

All replies must set `flags: MessageFlags.IsComponentsV2`.

## Components v2 UI rules

1. **No embeds, no `content`** on v2 replies — only `components: [Container]` + optional `files`.
2. **Header per reply**: `# <icon> <title>` via `TextDisplay`.
3. **Body**: `TextDisplay` with Markdown.
4. **Grouping**: `SectionBuilder` with a button **accessory** for "Details" placeholders.
5. **Visual rhythm**: `SeparatorBuilder({ divider: true, spacing: "small" })` between sections.
6. **Loading state**: a Container whose `#` row stays the same while an inner
   `TextDisplay` cycles through a block-glyph spinner (`▏▎▍▌▋▊▉` family). Edit
   every ~350 ms via `message.edit({ components: [c], flags: V2 })`.
7. **Result styling**:
   - per-obfuscator accent color (`--accent` in `<OBF_COLORS>`)
   - per-obfuscator icon (`<OBF_ICONS>`)
   - the keyword **"not supported"** is reserved for the unsupported reply
   - never leak local paths or usernames; scrub with `sanitize()`
8. **Errors** go in a Container with `accent: danger` (red) and a short message.

## `deobfFunction/` contract

```js
// each obfuscator exports
module.exports = {
  name: "moonsec",                  // unique, lowercase, used for paths
  display: "Moonsec",               // user-facing label
  blurb: "...one-liner for `.help`...",
  detect:    (source: string) => DetectionResult,
  deobfuscate: (source: string) => Promise<DeobfResult>,
};

// DetectionResult  -> { matches: boolean, confidence: 0..1, reasons: string[] }
// DeobfResult      -> { code: string, notes?: string[] }
```

`detect.js` is run for **every** obfuscator in the registry on each `.detect`
call — there is no early exit. If `confidence === 0` everywhere, the
"No supported obfuscator matched" reply is shown.

`deobfuscate.js` may throw `new Error("...")`. If you throw with
`err.code = "UNSUPPORTED"`, the bot will show the "Not supported" reply
instead of a crash entry. Any other error becomes the "Deobfuscator failed"
Container.

## Config & runtime

| Source var / key | Default | Where |
|---|---|---|
| `TOKEN` / `config.token` | none (required) | login |
| `CHANNEL_ID` / `config.channelId` | none (required) | dispatch whitelist |
| `PREFIX` / `config.prefix` | `.` | trigger parser |
| `TIMEOUT_MS` / `config.timeoutMs` | `125000` | per-job kill |
| `MAX_CONCURRENT` / `config.maxConcurrent` | `5` | concurrency cap |
| `LOGGER` / `config.logger` | `69ms/httplog2.lua` | `.l` |
| `DUMPER` / `config.dumper` | `69ms/luraphdump.lua` | `.dump` |
| `LOADSTRINGLOG` / `config.loadstringlog` | `69ms/loadstringlog.lua` | `.loadstringlog` |

`env.js` loads `.env` first, then falls back to `config.json`, then to
built-in defaults. Either works; pick one.

## Security

- `.env` **and** `config.json` are gitignored.
- Token defaults check: refused if it starts with `YOUR_BOT_TOKEN`.
- Sandbox folder is `dumps/{original,dumped}/`, sanitized in every output.
- `Message Content Intent` must be enabled in the Developer Portal.

## How to add a new obfuscator

1. Create `deobfFunction/deobfuscation/supported/<name>Function/`.
2. Copy the contents of `moonsecFunction/` and adjust:
   - `index.js` (`name`, `display`, `blurb`)
   - `detect.js` (heuristics → `{ matches, confidence, reasons }`)
   - `deobfuscate.js` (your algorithm → `{ code, notes }`)
3. Register it in `deobfFunction/deobfuscation/supported/index.js`.
4. (Optional) extend `src/ui/icons.js` `OBF_ICONS` + `OBF_COLORS`.
5. That's it — `detector.js` and the bot's `.help` reflect it automatically.

## Suggested additions (optional)

These were **not** implemented to keep the framework minimal. They are listed
here so you can prompt them in later passes without re-deriving them.

- `.compare <a> <b>` — show original vs deobfuscated side-by-side.
- `.stats <file|link>` — line / char / identifier / entropy stats with a
  Components v2 grid.
- `.history [@user]` — last 10 jobs (`dumps/` + a small JSON log).
- Interactive `.help` — replace the disabled "Details" buttons with real
  `ButtonStyle.Primary` buttons whose `InteractionCreate` handler edits the
  reply to expand that command's docs in place.
- `feedback.json` — when `.detect` returns 0%, attach a "Report as X" button
  to the row of obfuscators and store the source → claimed-obfuscator pair
  for future tuning.
- Per-obfuscator `runsIn: "guildOnly"` flag — refuse `.deobf` in DMs for
  protected obfuscators.
- A test harness under `tests/` that feeds canned inputs through every
  registered detector and shows pass/fail per obfuscator.

## Do-NOT-touch list

If you're an AI assistant continuing this work, **do not modify**:

- `deobfFunction/deobfuscation/supported/<anything>Function/detect.js`
- `deobfFunction/deobfuscation/supported/<anything>Function/deobfuscate.js`

These are the user's private implementations. Treat them as a black box that
satisfies the contract above. Refactoring the **rest** of the bot is fine;
rewriting detection/deobfuscation algorithms is not.

---

## ████ Prompt — paste below ████

```text
You are refactoring a Discord bot for Lua deobfuscation. Build exactly the
folder structure shown below in the working directory `./bot`, using the
constraints below. Do NOT modify the existing deobfuscation algorithms.

FOLDER LAYOUT
- bot/index.js               (minimal entry, auto-loads commands)
- bot/.env.example
- bot/package.json           (discord.js ^14.16.3, type: commonjs, scripts: start, check)
- bot/README.md
- bot/src/loader.js          (auto-loads src/commands/*.js, longest-trigger-first)
- bot/src/ui/v2.js           (Components v2 builders)
- bot/src/ui/icons.js        (colors + emojis, per-obfuscator + per-status)
- bot/src/commands/help.js    → `.help`
- bot/src/commands/detect.js  → `.detect`
- bot/src/commands/deobf.js   → `.deobf`
- bot/src/commands/get.js     → `.get`
- bot/src/commands/l.js dump.js loadstringlog.js   → existing Lune tools
- bot/src/utils/env.js fetcher.js sanitize.js lune.js luneCommand.js
- bot/deobfFunction/index.js                  (public surface)
- bot/deobfFunction/deobfuscation/index.js    (detect, run, registry, obfuscators)
- bot/deobfFunction/deobfuscation/detector.js (runs every detect.js; sorts by confidence)
- bot/deobfFunction/deobfuscation/supported/index.js   (registry — the *only* place to add)
- bot/deobfFunction/deobfuscation/supported/moonsecFunction/{index,detect,deobfuscate}.js
- bot/deobfFunction/deobfuscation/supported/irobbrewFunction/{index,detect,deobfuscate}.js
- bot/deobfFunction/deobfuscation/supported/irobbrew2Function/{index,detect,deobfuscate}.js
- bot/deobfFunction/deobfuscation/supported/prometheusFunction/{index,detect,deobfuscate}.js

COMMANDS (all replies must use Components v2 + MessageFlags.IsComponentsV2)
- `.help`   — Container with one Section per command and a "Supported obfuscators" list
- `.detect <file|link|paste|reply>` — animated spinner → Container with confidence %, reasons, source tag
- `.deobf  <file|link|paste|reply>` — animated spinner → attached .lua file + Container, OR
                                     a "Not supported" Container listing every detector tried
- `.get    <link>` — Container with URL, filename, MB, attached file
- `.l / .dump / .loadstringlog` — existing Lune scripts, same Components v2 wrapper

CONTRACT FOR deobfFunction
Each obfuscator module exports:
    { name, display, blurb, detect(source) -> { matches, confidence, reasons },
                                            deobfuscate(source) -> { code, notes } }
Throw `new Error("...")` with `err.code = "UNSUPPORTED"` to make the bot show
the "Not supported" Container instead of a crash entry.

COMPONENTS V2 RULES
1. No `content`, no `embeds` — only `components: [Container]` (and optional `files`).
2. Header via TextDisplay: `# <icon> <title>`.
3. Group with SectionBuilder + button accessory for "Details" placeholders.
4. SeparatorBuilder({ divider: true, spacing: "small" }) between sections.
   `setSpacing()` takes a `SeparatorSpacingSize` enum, NOT a string.
5. Buttons use `ButtonStyle.Primary|Secondary|Success|Danger|Link` enums.
6. Result Containers get a per-obfuscator accent color and icon (look them up
   in `src/ui/icons.js`).
7. Loading animation: cycle a block-glyph `▏▎▍▌▋▊▉`-family chunk every ~350 ms
   via `message.edit({ components: [c], flags: V2 })`.

DETECT/DEOBF STUBS
The four `detect.js` / `deobfuscate.js` files in `supported/` are INTENTIONALLY
TODO STUBS. Each detect() returns `{ matches:false, confidence:0, reasons:[] }`;
each deobfuscate() throws `"<name> deobfuscation not implemented yet"`.
DO NOT replace them with real logic — the user fills these in themselves.

DISPATCHER BEHAVIOR
- Only listen in config.channelId.
- Ignore other bots.
- Commands support one trigger each (`.${name}`); longer-prefix wins
  (auto-sorted longest first by the loader).
- On unknown command: a Container reminder with the available triggers.
- On unknown obfuscator: the "Not supported" Container (see above).

ENV
.env is preferred; falls back to config.json. Keys:
    TOKEN, CHANNEL_ID, PREFIX (default "."),
    TIMEOUT_MS (default 125000), MAX_CONCURRENT (default 5),
    LOGGER (default "69ms/httplog2.lua"),
    DUMPER (default "69ms/luraphdump.lua"),
    LOADSTRINGLOG (default "69ms/loadstringlog.lua").

QUALITY BAR
- All files pass `node --check`.
- `npm start` loads, registers, and only fails at `client.login()` without a real token.
- Path sanitizer scrubs `C:\...`, `/home/...`, `/Users/...`, and references to the
  internal lune scripts before any output leaves the bot.
- maxConcurrent capped job runner for `.l/.dump/.loadstringlog` (≤ 5).

DELIVERABLES
- Files in the tree above, including `.env.example`, updated `README.md`,
  and `BOT_PROMPT.md`.
- A short summary of what each command does, and how to add a new obfuscator.
- A list of optional commands I deliberately did NOT implement (`.compare`,
  `.stats`, `.history`, interactive `.help`, `feedback.json`) so the user
  can prompt them in later passes.

CRITICAL CONSTRAINTS (re-state)
- DO NOT touch the four obfuscator `detect.js` / `deobfuscate.js` files.
- DO NOT change the public shape of `deobfFunction/`.
- DO NOT keep using embeds or `content` in any reply the bot sends —
  Components v2 ONLY.
```
