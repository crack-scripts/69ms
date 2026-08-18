# 69ms Discord Bot

A Discord bot for Lua deobfuscation with Components v2 UI. Supports detecting obfuscator types, deobfuscating scripts, downloading files, and running existing Lune tools.

## Commands

| Trigger | Description |
|---|---|
| `.help` | Show all available commands and supported obfuscators |
| `.detect <input>` | Detect obfuscator type and confidence from a Lua file, link, paste, or reply |
| `.deobf <input>` | Deobfuscate and download the result as a `.lua` file |
| `.get <link>` | Download a raw file from a URL (Roblox/WinInet User-Agent) |
| `.l <input>` | Env-log Lua scripts using `69ms/httplog2.lua` |
| `.dump <luraph-input>` | Dump Luraph obfuscated scripts using `69ms/luraphdump.lua` |
| `.loadstringlog <input>` | Capture loadstring payloads using `69ms/loadstringlog.lua` |

### Input Formats

All commands that take `<input>` support:
- **Attached file**: Attach a `.lua` file directly to your message
- **Link**: Paste a URL pointing to a Lua script
- **Inline paste**: Paste code directly after the command (with or without ```lua fences)
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
- **lune** on PATH (for `.l`, `.dump`, `.loadstringlog` commands)
- Discord **Message Content Intent** enabled

## Supported Obfuscators

| Obfuscator | Status |
|---|---|
| Moonsec | Detection/Deobfuscation stubs (TODO) |
| Irobbrew | Detection/Deobfuscation stubs (TODO) |
| Irobbrew2 | Detection/Deobfuscation stubs (TODO) |
| Prometheus | Detection/Deobfuscation stubs (TODO) |

## Adding a New Obfuscator

1. Create a new folder in `deobfFunction/deobfuscation/supported/`:
   ```
   deobfFunction/deobfuscation/supported/myobfFunction/
   ```

2. Create three files:

**`index.js`** - Module exports:
```javascript
module.exports = {
  name: "myobf",
  display: "MyObf",
  blurb: "Description for .help",
  detect: require("./detect"),
  deobfuscate: require("./deobfuscate"),
};
```

**`detect.js`** - Detection logic:
```javascript
function detect(source) {
  // Return: { matches: boolean, confidence: 0-1, reasons: string[] }
  const reasons = [];
  let confidence = 0;
  
  if (source.includes("obfuscation_marker")) {
    reasons.push("Found obfuscation marker");
    confidence = 0.8;
  }
  
  return { matches: confidence > 0.5, confidence, reasons };
}
module.exports = { detect };
```

**`deobfuscate.js`** - Deobfuscation logic:
```javascript
async function deobfuscate(source) {
  // Return: { code: string, notes?: string[] }
  // Or throw Error with err.code = "UNSUPPORTED"
  const result = yourDeobfuscationLogic(source);
  return { code: result, notes: ["Step 1 done", "Step 2 done"] };
}
module.exports = { deobfuscate };
```

3. Register in `deobfFunction/deobfuscation/supported/index.js`:
```javascript
const myobf = require("./myobfFunction");
// Add to registry array
```

4. (Optional) Add icon/color in `src/ui/icons.js`:
```javascript
const OBF_ICONS = { ..., myobf: "🔮" };
const OBF_COLORS = { ..., myobf: 0x8b5cf6 };
```

## Security

- **Never commit `config.json` or `.env`** - these contain your bot token
- The bot sanitizes all output to prevent leaking local paths
- Only responds in the configured channel
- Ignores messages from other bots

## Architecture

```
bot/
├── index.js              # Entry point, command dispatch
├── src/
│   ├── loader.js         # Auto-loads all commands
│   ├── ui/
│   │   ├── v2.js        # Components v2 builders
│   │   └── icons.js     # Emoji/color constants
│   ├── commands/         # One file per command
│   │   ├── help.js
│   │   ├── detect.js
│   │   ├── deobf.js
│   │   ├── get.js
│   │   ├── l.js
│   │   ├── dump.js
│   │   └── loadstringlog.js
│   └── utils/
│       ├── env.js        # Config loader (.env → config.json → defaults)
│       ├── fetcher.js    # URL/attachment extraction
│       ├── sanitize.js   # Path scrubbing
│       ├── lune.js       # Lune binary runner
│       └── luneCommand.js # Shared job runner
└── deobfFunction/
    ├── index.js          # Public surface
    └── deobfuscation/
        ├── index.js      # detect, run, registry
        ├── detector.js   # Runs all detect.js
        └── supported/    # Obfuscator modules
            ├── moonsecFunction/
            ├── irobbrewFunction/
            ├── irobbrew2Function/
            └── prometheusFunction/
```

## Optional Commands (Not Implemented)

These were deliberately excluded to keep the framework minimal:

- **`.compare <a> <b>`** - Side-by-side original vs deobfuscated view
- **`.stats <file|link>`** - Line/char/entropy statistics
- **`.history [@user]`** - Last 10 jobs with logging
- **Interactive `.help`** - Button-based command docs
- **`feedback.json`** - Report undetected obfuscators
- **Per-obfuscator `runsIn` flags** - DM protection
- **Test harness** - Automated detector testing

These can be added in later passes.
