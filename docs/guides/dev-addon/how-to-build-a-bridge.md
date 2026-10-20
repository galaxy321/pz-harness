# How to build your own command-file bridge

*Ships with: PZ Harness Dev Add-on. Audience: people who downloaded the add-on but don't want to install the Bridge, or want to adapt it. Draft, written from Test Ground Bridge 1.1.0.*

A bridge lets a script or an AI agent drive the game by writing text files. Lua can only touch `Zomboid\Lua\`, so that folder is the channel.

## The protocol
- **Commands in:** `Zomboid\Lua\TestGround_cmd.txt`, one command per line.
- **Answers out:** `Zomboid\Lua\TestGround_out.txt`, append-only. Each command gets `=== #<n> <command>` followed by its reply lines. A run's end appends `=== done <report> <trace> <perf> <spikes>`.
- **Poll:** about once a second, on `OnTick`. `OnTick` doesn't fire at the main menu or while the game is paused, so a paused game answers nothing. Callers should treat no answer within ~5 s as "paused, at the menu, or bridge not enabled".

## The whole mod is ~100 lines
1. `Events.OnGameStart.Add(...)`: return if `isClient() or isServer()` (singleplayer only); register `Events.OnTick.Add(poll)`; append `=== bridge ready (...)` to the out file so callers see it came up.
2. `poll()`: skip unless 1000 ms passed (`getTimestampMs`); read the command file with `getFileReader(name, false)` and `readLine()` until nil; ignore blank lines; **empty the file** (`getFileWriter(name, true, false)`, write nothing, close) *before* running anything, so a slow command isn't run twice.
3. For each line: `pcall` the handler, then append `=== #n line` plus reply lines (or `error: ...`) with `getFileWriter(name, true, true)` (create, append). A handler returns a table of strings.
4. Handler: split the first word. Known words go to the mod being driven (here `TestGround.command(line)`); everything else replies `unknown command`.

## Safety, learned the hard way
- **Any program that can write the command file can run what the bridge runs.** So never include a raw-Lua command by default. Test Ground Bridge's `lua <code>` runs only with `-debug` or a sandbox option that lives outside `Zomboid\Lua\` (where a program writing the command file can't flip it), and every `lua` line, run or refused, is logged to a file and the console.
- Only call functions you've seen in vanilla Lua; in `-debug`, even a caught error can stop the game in the debugger.
- Wrap all file access in `pcall`; the game refuses writes to `.csv`, so use `.txt`.
- Singleplayer only: don't act when `isClient()`/`isServer()`.

## A minimal version
```lua
local CMD, OUT = "MyBridge_cmd.txt", "MyBridge_out.txt"
local last = 0
local function lines(name)
  local t = {}
  pcall(function()
    local r = getFileReader(name, false); if not r then return end
    local l = r:readLine(); while l do t[#t+1] = l; l = r:readLine() end; r:close()
  end)
  return t
end
local function write(name, t, append)
  pcall(function() local w = getFileWriter(name, true, append); for _, l in ipairs(t) do w:writeln(l) end; w:close() end)
end
local n = 0
local function poll()
  local now = getTimestampMs(); if now - last < 1000 then return end; last = now
  local cmds = {}
  for _, c in ipairs(lines(CMD)) do if c:find("%S") then cmds[#cmds+1] = c end end
  if #cmds == 0 then return end
  write(CMD, {}, false)
  for _, c in ipairs(cmds) do
    n = n + 1
    local out = { "=== #" .. n .. " " .. c }
    local ok, res = pcall(MyMod.command, c)           -- your own command table
    if ok then for _, l in ipairs(res or {}) do out[#out+1] = l end else out[#out+1] = "error: " .. tostring(res) end
    write(OUT, out, true)
  end
end
Events.OnGameStart.Add(function() if isClient() or isServer() then return end; Events.OnTick.Add(poll) end)
```

## Test it
Mock: run the file under lupa with fake `Events`, `getFileReader`, `getFileWriter`. In game: write `status` to the command file, expect the `=== #1` block within ~2 s, and check that the command file is empty afterwards.

Not verified: the minimal version above was written from the real bridge's structure and not run.
