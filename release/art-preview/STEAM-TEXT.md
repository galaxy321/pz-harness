# Steam page text as it stands (18 Oct build, placeholder wording)

BBCode tags are shown as Markdown; the real text is `overlay/<mod>/description.txt`. Both need rewriting for the rename, the submods and the end screen.

---

# Item: TestGround

Short mod.info description:
> Performance test bench for singleplayer on the vanilla map. Runs one fixed, scripted test route from South St in West Point: a drive, a walk loop, two zombie fights, looting, a tree-lined road, a real car down the Dixie Highway at 120 km/h, a 500-zombie crowd and a drive in fog. Writes frame times (fps, p95, p99, hitches) per step to Zomboid/Lua/ so two mod setups can be compared. A run teleports you, spawns and removes zombies and changes time and weather in the save it runs in, so use a copy of your save. Right-click > Test Ground to start.

# Test Ground (Build 42 performance test bench)

Measure how a mod setup plays, the same way every time. Test Ground drives, walks and fights through one fixed scripted route and writes the frame times of each part to a report, so you can compare two mod lists, a patch on and off, or a settings change, without replaying anything by hand.

## The test route
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


## How to use it

- Make a copy of your save (copy its folder under **Zomboid\Saves\**). **A run changes the save it runs in**: it teleports you, spawns and removes zombies, removes parked cars on the fast-drive road, and changes time and weather. You are put back where you were at the end.
- Enable Test Ground in that save and load it.
- Right-click the ground > **Test Ground** > **Run the fixed baseline (West Point)**. The first time in a save it asks you to confirm.
- Wait for the run to end (about 15 minutes). Keep the game window in front: if the game pauses when it loses focus, the run pauses too.

The report is written to **Zomboid\Lua\TestGround_baseline_<id>.txt**, with a per-second CSV and a spike list next to it.

## Good to know

- **Singleplayer only.** It does nothing on a server.
- **Vanilla map.** The start and the routes are on the vanilla map. Map mods that change those streets make the fast drive and tree road fall back to shorter roads.
- **Can't die mode.** Outside debug mode the game doesn't allow god mode from Lua, so the fights restore your health every tick instead. Launch with -debug for real god mode.
- Zombies you spawn or kill and the time that passes during the run stay in the save. That's why you use a copy.
- Plans are plain text in **Zomboid\Lua\**; you can write your own (see the plan file Test Ground creates on first load).


## Scripted runs and AI agents
**Test Ground Bridge**, a separate add-on, lets scripts and AI agents drive Test Ground from outside the game and comes with a Claude skill for building test cases. It is separate because it can run code in your game; Test Ground on its own reads no command files.


---

# Item: TestGroundBridge

Short mod.info description:
> Lets scripts and AI agents drive Test Ground from outside the game, to build and run test cases for your own mods. Once a second it reads Zomboid/Lua/TestGround_cmd.txt, runs each line as a Test Ground command and writes the replies to Zomboid/Lua/TestGround_out.txt. It can also run "lua <code>" lines, but only when the game runs with -debug or the save's sandbox option "Test Ground Bridge: allow lua lines" is on (off by default). With that on, any program that can write that file can run Lua in your game, so turn it on only in a test save on your own machine. Every lua line is logged to Zomboid/Lua/TestGround_bridge_lua.txt. Singleplayer only. Includes a Claude skill (agent-skill folder) that teaches an agent how to use it.

# Test Ground Bridge (for scripts and AI agents)

An add-on for **Test Ground** that lets a script or an AI coding agent drive it from outside the game, so it can build and run test cases for your own mods while you watch.

## **Read this first: security**
Once a second the bridge reads **Zomboid\Lua\TestGround_cmd.txt** and runs each line. One command, **lua**, runs any Lua code. It is **off by default**: it works only when the game is started with -debug or the save's sandbox option **Test Ground Bridge: allow lua lines** is on. With it on, **any program on your PC that can write that file can run code in your game**. Every lua line, run or refused, is logged to **Zomboid\Lua\TestGround_bridge_lua.txt**.

- Turn the sandbox option on only in a test save, on your own machine, and only while you need it. The other commands work without it.
- Don't enable it on a server. It does nothing in multiplayer.


## Commands

- **status**: idle or running, position, fps, last report
- **baseline**: run the standard West Point test route
- **survey** [radius] [run]: scan the area for walls, doors, ladders, streets and containers, and write a plan
- **run** [file]: run a plan file from Zomboid\Lua\
- **stop**: stop and write the report so far
- **lua** <code>: run one line of Lua (only with -debug or the sandbox option)

Replies are appended to **Zomboid\Lua\TestGround_out.txt**, and **=== done <report>** marks the end of a run.

## Using it with an AI agent
The mod folder has an **agent-skill\pz-test-ground** folder: a Claude skill that explains the bridge, the plan format, how to add a test step to your own mod and the Build 42 Lua traps found while building Test Ground. Copy that folder into your agent's skills folder (for Claude Code: **.claude\skills\** in your project, or **~\.claude\skills\**). The **tools** folder has **compare.py**, which compares two reports.

You'll find the files under **Steam\steamapps\workshop\content\108600\<this item's id>\mods\TestGroundBridge\** once you've subscribed.

## Requires

- Test Ground



