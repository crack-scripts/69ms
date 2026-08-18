--[[
69ms — Ironbrew v1 / Ironveil deobfuscator runner
============================================
INPUT  = first CLI arg (source file path)
OUTPUT = second CLI arg (write decoded result here)

Wire your open-source Ironbrew/Ironveil deobfuscator between the
BEGIN/END markers below and ensure `local decoded` holds
the deobfuscated source string.

DO NOT change the INPUT/OUTPUT or decoded contract above or
below the markers.
]]

local INPUT = ...
local OUTPUT = select(2, ...)

-- Read the input file
local fs = require("fs")
local source = fs.readFile(INPUT)

-- Placeholder: deobfuscated result
local decoded

-- ============================================================
-- BEGIN USER DEOBF — paste your Ironbrew v1 deobfuscator Lua below
-- ============================================================

-- Default: pass-through (no-op). Replace with your algorithm.
-- Your code should read `source` and write `local decoded = <result>`.
local decoded = source

-- ============================================================
-- END USER DEOBF
-- ============================================================

-- Write output (DO NOT modify this part)
assert(decoded, "decoded must be assigned by your deobfuscator code")
fs.writeFile(OUTPUT, decoded)

print("[69ms] Irobbrew deobfuscation complete")