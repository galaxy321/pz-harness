(Readable copy; Steam itself uses BBCode, the source is overlay/items/PZHarness/description.txt)

# PZ Harness (Build 42 performance test bench)

Measure how a mod setup plays, the same way every time. PZ Harness drives, walks and fights through one fixed scripted route and writes the frame times of each part to a report, so you can compare two mod lists, a patch on and off, or a settings change, without replaying anything by hand.

**Update both items together.** The PZ Harness Dev Add-on needs the same version of this item.

## What is in this item
Each is a separate entry in the game's mod list. Tick only what you want.
- **PZ Harness**: the test bench itself. Required.
- **PZ Harness: Capture (needs ZombieBuddy)**, optional: lets Benchmark Save copy one of your saves. Without it only "New vanilla save" works.
- **PZ Harness: Memory (needs ZombieBuddy)**, optional: adds RAM, Java heap and VRAM lines under every step.
The two optional ones are Java and need [ZombieBuddy](https://steamcommunity.com/sharedfiles/filedetails/?id=3619862853) (its page explains its installer). ZombieBuddy asks once to allow each unsigned jar. PZ Harness itself is plain Lua.

## Quick test or full test
- **Quick test (about 5 minutes):** the steps that carry the most signal: looting, a drive, a 90 s fast drive with chunk loading, a melee fight and the 500-zombie crowd. Use it to check a change or compare two setups quickly.
- **Full test (about 15 minutes):** the whole route below. Use it for a careful comparison.
Both run the same fixed route from the same start, so a quick report compares only with another quick report, and a full report with another full one.

## How to use it
- In the main menu, click **Benchmark Save**.
- Pick one of your saves (needs the Capture submod), or **New vanilla save**. PZ Harness tests a **thrown-away copy** of it, so your own save is never touched. The copy is deleted the next time you reach the main menu.
- Press **Quick test** or **Start full benchmark**, and leave the game window in front: if the game pauses when it loses focus, the run pauses too.
- When the run ends, an end screen shows the key figures and counts down to closing the game; a button pauses the countdown.
The full report is written to *Zomboid\Lua\TestGround_<name>_<id>.txt*, with a per-second CSV and a spike list next to it.
Already in a save? Right-click the ground > **Test Ground** > **Run the fixed baseline (West Point)** runs the full test there. That route changes the save you are in, so use a copy.

## The full test route
Every run starts on South St in West Point on the vanilla map, so every save runs the same streets.
- a 60 s drive (chunk loading at driving speed)
- a walk loop with real Walk To pathfinding
- a small and a large zombie fight
- looting six containers in one house
- a drive back, and a drive along a tree-lined road
- a real car down the Dixie Highway at 120 km/h
- a fight where you swing yourself
- 500 zombies crowding round you
- the first drive again in fog
Two research plans (shooting and aim sweep) are also included. They aren't part of the normal tests.

## Good to know
- **Singleplayer only.** It does nothing on a server.
- **Vanilla map.** The start and the routes are on the vanilla map. Map mods that change those streets make the fast drive and tree road fall back to shorter roads.
- **Can't die mode.** Outside debug mode the game doesn't allow god mode from Lua, so the fights restore your health every tick instead. Launch with -debug for real god mode.
- **Other mods' welcome pop-ups** that open in the first seconds after loading are closed by the test, and the trace lists what it closed.
- A run changes the save it runs in: it teleports you, spawns and removes zombies and parked cars on the fast-drive road, and changes time and weather. Benchmark Save runs in a copy for that reason.
- Plans are plain text in *Zomboid\Lua\*; you can write your own.

## Hands-free runs: the flag file
For unattended runs PZ Harness contains a small engine that does **nothing at all** unless you create *Zomboid\Lua\TestGround_autorun.txt*. If that file exists and names a save, then on the next start of the main menu the game loads that save, runs the named plan, writes a result file and quits to the desktop. It can also create a new vanilla save, and temporarily add mods to the named save's mod list (taken off again at the next main menu). It runs no Lua from the file: it only reads settings such as the save, plan and timeouts. Don't create that file unless you want that, and use it only on test copies.

## Scripted runs, AI agents and auto-queue
The **PZ Harness Dev Add-on**, a separate item, adds a command-file bridge for scripts and AI agents, a Claude skill for building test cases, and guides. A PowerShell auto-queue script for queuing runs lives in the project's GitHub repository and is not part of this item: [https://github.com/galaxy321/pz-harness](https://github.com/galaxy321/pz-harness)

## Skills and guides in this item
Files, not game content: in the mod's folder under *steamapps\workshop\content\108600\<this item's id>\mods\TestGround\* you'll find *agent-skill\* (Claude skills: run a benchmark, read a report, add a test step to your own mod), *guides\quick-start.md* and *tools\compare.py*, which compares two reports.
