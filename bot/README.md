# 69ms Discord Bot

A Discord bot for Lua deobfuscation with Discord Components v2 UI.

**Version:** 2.1.0

Supports detecting obfuscator types, deobfuscating scripts, downloading files,
running existing Lune tools, and analyzing source code statistics.

> **Status:** Everything except `.deobf`'s actual algorithm works out of the box.
> The Lua deobfuscator files ship as placeholders — paste your open-source
> deobfuscator to enable real deobfuscation (see "Wiring your deobfuscator" below).

## Commands

| Trigger | Description |
|---|---|
| `.help` | Show all available commands and supported obfuscators |
| `.detect <input>` | Detect obfuscator type with confidence %, reasons, and timing |
| `.deobf <input>` | Deobfuscate Lua source and return a clean `.lua` file |
| `.stats <input>` | Byte/line/identifier counts + 4 detector opinions + best guess |
| `.tools` | List each obfuscator runner's wired state + instructions |
| `.get <link>` | Download a raw file from a URL |
| `.l <input>` | Env-log Lua scripts using `69ms/httplog2.lua` |
| `.dump <luraph-input>` | Dump Luraph obfuscated scripts using `69ms/luraphdump.lua` |
| `.loadstringlog <input>` | Capture loadstring payloads using `69ms/loadstringlog.lua` |

### Input Formats

All commands that take `<input>` support:
- **Attached file**: Attach a `.lua` file directly to your message
- **Link**: Paste a URL pointing to a Lua script
- **Inline paste**: Paste code directly (with or without ```lua fences)
- **Reply**: Reply to a message containing any of the above

## Setup

### 1. Enable Message Content Intent

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications)
2. Select your bot application
3. Navigate to **Bot** → **Privileged Gateway Intents**
4. Enable **Message Content Intent**
5. Save Changes

### 2. Configure the Bot

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

Or use `config.json` (gitignored):

```json
{
  "token": "YOUR_BOT_TOKEN",
  "channelId": "123456789012345678",
  "prefix": ".",
  "timeoutMs": 125000,
  "maxConcurrent": 5,
  "logger": "69ms/httplog2.lua",
  "dumper": "69ms/luraphdump.lua",
  "loadstringlog": "69ms/loadstringlog.lua"
}
```

### 3. Install and Run

```bash
cd bot
npm install
npm start
```

### Requirements

- **Node.js** ≥ 18
- **lune** on PATH (for `.l`, `.dump`, `.loadstringlog`, and `.deobf` commands)
- Discord **Message Content Intent** enabled

## Supported Obfuscators

| Obfuscator | Detection | Deobfuscation (wired) |
|---|---|---|
| Moonsec / Moonveil | ✅ Built-in | ⚠️ Needs Lua paste-in |
| Ironbrew v1 / Ironveil | ✅ Built-in | ⚠️ Needs Lua paste-in |
| Ironbrew v2 / ib2 | ✅ Built-in | ⚠️ Needs Lua paste-in |
| Prometheus / LuaObfuscator | ✅ Built-in | ⚠️ Needs Lua paste-in |

> **Detection** works immediately with heuristic analysis.
> **Deobfuscation** needs the open-source Lua deobfuscator pasted into
> `deobfFunction/tools/<name>.lua` (see next section).

## Wiring your deobfuscator

Each `deobfFunction/tools/<name>.lua` ships with `-- BEGIN USER DEOBF` /
`-- END USER DEOBF` markers. To wire in a real deobfuscator:

### Step-by-step

1. Download the open-source deobfuscator from one of:
   - https://github.com/crack-scripts/deobfuscation-Function (four zips)
   - `moonveil deobf.zip` → `moonsec.lua`
   - `Ironveil-Deobfuscator-V1-main.zip` → `irobbrew.lua`
   - `ib2-deobf.zip` → `irobbrew2.lua`
   - `LuaObfuscator-Deobfuscator-main.zip` → `prometheus.lua`

2. Find the **entry point** Lua file (the one that does the actual unwrap).

3. Open `bot/deobfFunction/tools/<name>.lua`.

4. Paste the entry-point code **between** the `BEGIN USER DEOBF` /
   `END USER DEOBF` markers.

5. Make sure the deobfuscated source ends up in `local decoded`:
   ```lua
   -- BEGIN USER DEOBF
   -- Your deobfuscation logic here...
   local decoded = your_deobfuscator(source)
   -- END USER DEOBF
   ```

6. Run `.tools` in Discord — that obfuscator should say ✅ ready.

7. Try `.deobf <some obfuscated .lua>` to confirm.

### Lua runner contract

| Variable | Purpose |
|---|---|
| `source` | The original obfuscated source (read from INPUT) |
| `decoded` | **Must** be assigned to the deobfuscated source string |
| `INPUT` | First argument (input file path) — read by boilerplate |
| `OUTPUT` | Second argument (output file path) — written by boilerplate |

Your deobfuscator code only needs to process the `source` string and
assign the result to `local decoded`. The boilerplate handles file I/O.

## Architecture

```
bot/
├── index.js                  # Entry point, command dispatch
├── src/
│   ├── loader.js             # Auto-loads all commands (longest trigger first)
│   ├── ui/
│   │   ├── v2.js            # Components v2 builders (Container, Section, etc.)
│   │   └── icons.js         # Emoji/color constants per obfuscator
│   ├── commands/             # One file per command
│   │   ├── help.js           # .help
│   │   ├── detect.js         # .detect
│   │   ├── deobf.js          # .deobf
│   │   ├── stats.js          # .stats
│   │   ├── tools.js          # .tools
│   │   ├── get.js            # .get
│   │   ├── l.js              # .l
│   │   ├── dump.js           # .dump
│   │   └── loadstringlog.js  # .loadstringlog
│   └── utils/
│       ├── env.js            # Config loader (.env → config.json → defaults)
│       ├── fetcher.js        # URL/attachment extraction + download
│       ├── sanitize.js       # Path scrubbing (privacy)
│       ├── lune.js           # Lune binary runner (generic)
│       ├── luneCommand.js    # Shared runner for .l/.dump/.loadstringlog
│       └── sourceStats.js    # Source analysis for .stats
└── deobfFunction/
    ├── index.js              # Public surface
    ├── luneRunner.js         # Single source of truth for lune deobfuscation
    ├── tools/                # Lua deobfuscator runners
    │   ├── README.md
    │   ├── moonsec.lua
    │   ├── irobbrew.lua
    │   ├── irobbrew2.lua
    │   └── prometheus.lua
    └── deobfuscation/
        ├── index.js          # Orchestrator (detect, run, registry)
        ├── detector.js       # Runs every detect.js, sorts by confidence
        └── supported/        # One folder per obfuscator
            ├── index.js      # Registry (only place to add new ones)
            ├── moonsecFunction/
            ├── irobbrewFunction/
            ├── irobbrew2Function/
            └── prometheusFunction/
```

## Detection Heuristics

All four detectors run on every `.detect` and `.stats` call. Results are
sorted by confidence; the highest match wins.

| Obfuscator | Key signals |
|---|---|
| Moonsec | Watermarks, `\NNN` byte-escape density, `string.char()` wrapper, loadstring fence, v3 closure shape |
| Ironbrew v1 | Watermarks, dispatcher loop, single-letter local pool, `string.char()` builder |
| Ironbrew v2 | Watermarks, `_ENV` proxy, numeric constant pool, dispatch arithmetic, pcall+setmetatable |
| Prometheus | Watermarks, random-string pool, short-identifier density, bytecode-style indexing, `bit` library |

## Security

- **Never commit `config.json` or `.env`** — these contain your bot token.
- The bot sanitizes all output to prevent leaking local paths.
- Only responds in the configured channel.
- Ignores messages from other bots.
- Token sanity check: refused if it starts with `YOUR_BOT_TOKEN`.

## Suggested additions (not implemented)

- `.compare <a> <b>` — side-by-side original vs deobfuscated view
- `.history [@user]` — last 10 jobs with logging
- Interactive `.help` — button-based command expansion
- `feedback.json` — report undetected obfuscators
- Per-obfuscator `runsIn` flags — DM protection
- Test harness for detectors

## License

MIT