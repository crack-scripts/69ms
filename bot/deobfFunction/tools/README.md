# deobfFunction/tools — Lua Deobfuscator Runners

Each file in this directory is a **lune runner** that wraps an open-source
Lua deobfuscator for use by the 69ms bot's `.deobf` command.

## How it works

1. The JS `luneRunner.js` writes the user's input to a temp file and
   passes its path as the first CLI argument (`INPUT`).
2. The second CLI argument (`OUTPUT`) is where the runner writes the
   deobfuscated result.
3. The Lua runner reads `INPUT`, runs the deobfuscator, and writes
   `OUTPUT`.

## Wiring your deobfuscator

Each `tools/<name>.lua` file has `-- BEGIN USER DEOBF` / `-- END USER DEOBF`
markers. Paste your open-source deobfuscator Lua code **between** these
markers.

### Requirements

- Your code must assign the deobfuscated source (as a Lua string) to
  `local decoded`.
- Your code can use any lune-available libraries (`fs`, `string`, `table`, etc.)
- The input source text is available in the global `source` variable.

### Example

```lua
-- BEGIN USER DEOBF
-- My custom deobfuscator
local function deobf(s)
    -- ... your unwrapping logic here ...
    return s:gsub("obfuscated_", "clean_")
end
local decoded = deobf(source)
-- END USER DEOBF
```

## Files

| File | Obfuscator | Status |
|---|---|---|
| `moonsec.lua` | Moonsec / Moonveil | Placeholder |
| `irobbrew.lua` | Ironbrew v1 / Ironveil | Placeholder |
| `irobbrew2.lua` | Ironbrew v2 / ib2 | Placeholder |
| `prometheus.lua` | Prometheus / LuaObfuscator | Placeholder |

## Open-source references

Repos with ready-to-use Lua deobfuscators:
- https://github.com/crack-scripts/deobfuscation-Function

For each zip:
- `moonveil deobf.zip` → `moonsec.lua`
- `Ironveil-Deobfuscator-V1-main.zip` → `irobbrew.lua`
- `ib2-deobf.zip` → `irobbrew2.lua`
- `LuaObfuscator-Deobfuscator-main.zip` → `prometheus.lua`