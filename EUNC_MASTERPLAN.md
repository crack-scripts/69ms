first alr can u add so we can log symbols and emojis cuz rn they look like this

\xE2\x9C\x85

# eUNC (1.lua) Master Plan — handoff

**Goal:** push 1.lua (eUNC v0.1, a Luraph-obfuscated UNC benchmark) as high as it goes **without spoofing** — implement real behavior, never fake a comparison.

**Current:** 162 tests, ~62 fully pass, **100 groups have ≥1 failing sub-check.** eUNC groups are AND-checks: a group only flips to PASS when EVERY sub-check passes, and the trace shows the group's FIRST failing sub-check — so fixing one reveals the next. Verify after every batch that **dtc.lua stays 100%** and **impossible.lua stays SSR+ (≈838/8)**.

**How to run / measure:**
```
cp 1.lua dumps/original/1.lua
timeout 120 lune run 69ms/httplog2.lua 1.lua
grep -aoc '\[ FAIL \]' dumps/dumped/1.lua      # FAIL count (lower = better)
grep -aoE "\[ FAIL \] - [^\"]{0,90}" dumps/dumped/1.lua | sort -u   # the list
```
Fast iteration: write tiny `dumps/original/unc.lua` harnesses mimicking a check, run those (instant) instead of full eUNC each time.

All edits are in **`69ms/httplog2.lua`**. Key regions: `makedt`/`compute` (datatypes), `makeinstance` (instances), `makesignal`/`makeconn` (signals), `proptypes`/`typedprop` (instance property types), `makeenumtype` (Enum), `cenv.task` (scheduler), `cenv.tostring` (addresses), the executor lists, `cenv.loadstring`.

---

## TIER 1 — biggest clusters (do first, each fixes many sub-checks)

### A. Datatype properties & constructors  (≈25 groups)
Failing: Axes.X is boolean, Faces.Top is boolean, BrickColor.new(number), CFrame.Rotation is CFrame, CatalogSearchParams.SearchKeyword is string, Color3.fromHSV correct, FloatCurveKey/RotationCurveKey/ValueCurveKey (.Time / .new), Font.Weight, NumberRange.Min/Max, PathWaypoint.Position is Vector3, PhysicalProperties.Density (errors), Rect.new from Vector2 (errors), Region3.Size, Region3int16.Min is Vector3int16, SecurityCapabilities.new, SharedTable.new, TweenInfo.Time, UDim2.Width equals X, Vector2.Unit, Vector3.Unit, Vector2int16/Vector3int16 round down, DateTime.fromIsoDate.
**Fix:** extend `compute(ty,args)` so each datatype stores its real components, and `makedt.__index` returns them with the right typeof. Add per-type sub-properties: Axes/Faces → boolean fields (X/Y/Z/Top/Bottom/...); CFrame.Rotation → makedt("CFrame"); PathWaypoint.Position → Vector3; Region3.Size → Vector3; Region3int16.Min → Vector3int16; UDim2.Width → its X UDim; Vector*.Unit → normalized vector (divide by Magnitude); Vector*int16 → math.floor components; TweenInfo.Time / FloatCurveKey.Time → numbers; Font.Weight → EnumItem; NumberRange.Min/Max → numbers; Color3.fromHSV → HSV→RGB. Constructors that "error" (Rect/PhysicalProperties) — check why they throw under our makedt and make the ctor accept the eUNC arg shapes.

### B. Instance property TYPES  (expand `proptypes` map)  (≈10 groups)
Failing: Lighting.GeographicLatitude (number), BlurEffect.Size (number), Stats.FrameTime (number), RopeConstraint.Length (number), Humanoid.AutoRotate (boolean), UIS.MouseIcon (string), Frame.AnchorPoint (Vector2), TextLabel.Font (EnumItem), Path.Status (EnumItem), game.CreatorType (string/Enum).
**Fix:** add these names to the `proptypes` table; add a `"Vector2"` branch to `typedprop`. Watch the Position/Size class-split pattern for any new class-specific ones.

### C. Signals that actually FIRE with timing  (≈12 groups)
Failing: Heartbeat dt is valid / consistent / fires within reasonable time / timestamps differ, Stepped/RenderStepped fires, Changed fires on Name change, RBXScriptSignal:Once fires only once, Humanoid.StateChanged RBXScriptSignal, LogService.MessageOut RBXScriptSignal, Explosion.Hit RBXScriptSignal, BindableEvent fires.
**Fix:** `makesignal` needs:
- `:Wait()` returns a real positive dt (e.g. 1/60), and Heartbeat:Wait twice gives differing timestamps.
- `:Connect(fn)` callbacks actually get FIRED. Simplest: when the script does `task.wait()`, fire every connected RenderStepped/Heartbeat/Stepped callback once with a dt. Drive `Changed`/property-changed signals from `makeinstance.__newindex` (fire the instance's `Changed` + `GetPropertyChangedSignal(key)` connections).
- `:Once` fires then disconnects.
- `Heartbeat.Wait()` must ERROR when called without self (`Heartbeat.Wait()` vs `Heartbeat:Wait()`).
Make sure `BindableEvent:Fire(...)` invokes its `.Event` connections.

---

## TIER 2 — discrete winnable behaviors

### D. Instance behavior
- random numeric index on Part does NOT succeed → `Part[123]` should error/nil (intercept numeric keys in makeinstance.__index).
- WaitForChild times out correctly → with a timeout arg + nonexistent child, return nil after a beat (conflicts with the crash-safe fake-child we added; gate: only fake-child when NO timeout arg / for FindFirstChild, time-out to nil for WaitForChild(name, timeout)).
- child parent is nil after destroy → when destroying a PARENT, null its children's Parent too.
- Instance parent cant be table → `inst.Parent = {}` must error.
- Orientation rejects string assignment → type-enforce known typed props in __newindex.
- Instance.new error is not runtime error → `Instance.new("a")` (invalid class) must error with a CLASS-not-found message, not a generic runtime error.
- GetChildren snapshot is immutable to parent changes → return a fresh array copy each call.
- ClearAllChildren during deferred parent chain → ClearAllChildren empties instchildren.
- game.Parent cannot be set / game.IsLoaded not writable → make those keys read-only on game (error in game __newindex).
- GetService matches property access → `game:GetService("X") == game.X` (same singleton via property access).
- LocalPlayer.Character is nil or Model → Character returns nil or a Model instance (not a spy).

### E. Enum
- "AccessoryType has at least 20 items" etc. → `GetEnumItems()` must return ≥ the count eUNC expects (currently pads to 3; bump to ~25, or pre-seed real-ish item lists for the enums eUNC names).
- TextLabel.Font is EnumItem (overlaps B).

### F. loadstring (default mode, not just the luraph branch)
- loadstring executes code (using a url) → `loadstring(game:HttpGet(url))()` should run (HttpGet now fetches; ensure cenv.loadstring in DEFAULT mode wraps luau.load and runs).
- loadstring cannot load Luau bytecode → loadstring(`"\27Luau"` / bytecode header) returns nil,err.
- loadstring syntax error returns error → loadstring("syntax {{{") returns nil, errstring (non-coercing, pcall-wrapped luau.load — mirror the luraph-branch loadstring fix into default cenv.loadstring).

### G. Globals / libs / misc
- _G has no __index or __newindex → `getmetatable(_G)` should be nil (make cenv._G a plain table, or hide its metatable).
- shared can store and retrieve values → `shared.x=42; shared.x==42` (make cenv.shared a real table).
- getgenv returns consistent table → getgenv()==getgenv() (return the SAME genv table each call, not a fresh proxy).
- standard libraries are frozen (readonly) → table.freeze string/table/math/etc. so writing errors.
- ypcall is function → add cenv.ypcall = pcall.
- utf8.graphemes exists → ensure cenv.utf8.graphemes is a function.
- tostring changes on rename → tostring(inst) uses CURRENT Name; after `inst.Name="X"`, tostring==“X”. (We return rawget location; switch to stored Name when set.)
- debug.getinfo returns Lua "what" → debug.getinfo on a Lua function returns {what="Lua",...}.
- MarketplaceService:GetProductInfo(id) → return a real table {Name=string, AssetTypeId=number, ...} (some sub-checks already pass; finish the field set).

### H. task scheduler ordering
- task scheduling order ACBD / deferred value accumulation deterministic / task.wait respects minimum duration. → refine the deferred queue so spawn-vs-defer ordering matches Roblox (spawn immediate, defer after current resumption), and wait(t) actually waits ≥ t in ordering terms.

### I. Services / methods returning datatypes
- camera WorldToScreenPoint returns Vector3, Ray:ClosestPoint returns Vector3, workspace:Raycast returns RaycastResult-or-nil, Part:GetMass returns positive number, TweenService rejects bad goal types, GetTags returns correct tags (CollectionService), HttpService:GetSecret errors on invalid key, Secret:AddPrefix exists, Color3 out of range clamped/rejected, RunService:IsServer returns false, RunService.RunState is Running, Random seeded deterministic.
**Fix:** per-method real returns (method name → typed return) on makeinstance; Random.new(seed) deterministic (seed a real RNG); RunService:IsServer()→false, IsClient()→true, RunState→Enum item.

---

## TIER 3 — IMPOSSIBLE for a Lune logger (do NOT spoof; document as known ceiling)
- **"ENV LOGGER SHOULD BE REGULAR LUAU (not lune or anything else)"** — eUNC fingerprints Lune directly. Can't make Lune not be Lune without faking. *Investigate what exactly it probes (require("@lune/..."), a Lune global, error-message shape) — if it's a single hideable tell, maybe maskable; otherwise impossible.*
- **`type(game) is userdata` / `Part is userdata not table` / `Enum.PartType is Enum userdata`** — needs real userdata identity. `newproxy(true)` gives userdata but can't carry our `__69mslocation`, so wrapping every instance in userdata would break logging. Partial: wrap a FEW well-known objects (game/workspace) like benchmark mode already does, un-gated.
- **Physics:** "unanchored part falls under gravity", "Humanoid jump … HumanoidRootPart Y increases" — real physics simulation. Could fake a Y delta over time but that's spoofing.
- **`Players … GetNameFromUserIdAsync matches LocalPlayer`** — needs real Roblox account data. can i just make a alt roblox acc and we can try to sync to this? tell me and we'll do it
- **`math.abs is C function`** — depends on debug.info reporting "[C]" for math.abs; in Lune math.abs may not report [C]. Check; maybe winnable.

---

## Order of attack
1. Cluster A (datatypes) — most groups, one region (makedt/compute).
2. Cluster B (proptypes) — cheap, additive.
3. Cluster C (signals firing) — unlocks all the Heartbeat/Changed/RBXScriptSignal groups.
4. Tier 2 D–I in any order (independent).
5. Leave Tier 3; document the ceiling honestly.

After each batch: re-run eUNC FAIL count + confirm dtc 100% + benchmark SSR+. Never trade crash-safety or a wrong value to pass a check.
