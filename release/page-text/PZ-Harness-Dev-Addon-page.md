(Readable copy; Steam itself uses BBCode, the source is overlay/items/PZHarnessDevAddon/description.txt)

# PZ Harness Dev Add-on (for scripts and AI agents)

An add-on for **PZ Harness** that lets a script or an AI coding agent drive it from outside the game, so it can build and run test cases for your own mods while you watch. **Update both items together:** the add-on needs the same version of PZ Harness.

## What is in this item
- **PZ Harness: Bridge (dev add-on)**: the command-file bridge, with a Claude skill, guides and a report comparison tool.
- **PZ Harness: UI check and tour (dev add-on)**: measures PZ Harness's own screens for layout defects and can walk through them taking screenshots. Does nothing unless a flag file asks for it.

## **Read this first: security**
Once a second the bridge reads *Zomboid\Lua\TestGround_cmd.txt* and runs each line. One command, *lua*, runs any Lua code. It is **off by default**: it works only when the game is started with -debug or the save's sandbox option **Test Ground Bridge: allow lua lines** is on. With it on, **any program on your PC that can write that file can run code in your game**. Every lua line, run or refused, is logged to *Zomboid\Lua\TestGround_bridge_lua.txt*.
- Turn the sandbox option on only in a test save, on your own machine, and only while you need it. The other commands work without it.
- Don't enable it on a server. It does nothing in multiplayer.

## Commands
- **status**: idle or running, position, fps, last report
- **baseline** [quick]: run the standard West Point test route (or the 5-minute quick one)
- **survey** [radius] [run]: scan the area for walls, doors, ladders, streets and containers, and write a plan
- **run** [file]: run a plan file from Zomboid\Lua\
- **stop**: stop and write the report so far
- **lua** <code>: run one line of Lua (only with -debug or the sandbox option)
Replies are appended to *Zomboid\Lua\TestGround_out.txt*, and *=== done <report>* marks the end of a run.

## Using it with an AI agent
In the Bridge mod's folder, *agent-skill\* holds Claude skills: how to drive PZ Harness through the bridge, how to write and patch a Build 42 mod, and how to find and fix a slow mod. Copy a skill folder into your agent's skills folder (for Claude Code: *.claude\skills\* in your project, or *~\.claude\skills\*). *guides\* explains how to build your own bridge, capture tool and autopilot, so you can reproduce them without installing anything. *tools\compare.py* compares two reports.
You'll find the files under *Steam\steamapps\workshop\content\108600\<this item's id>\mods\TestGroundBridge\* once you've subscribed.

## Hands-free runs and auto-queue
The flag-file engine is part of PZ Harness (see its page). A PowerShell auto-queue script for queuing runs lives in the project's GitHub repository, with setup instructions. It is not part of this item, because the Workshop doesn't take scripts and you should read one before you run it:
[https://github.com/galaxy321/pz-harness](https://github.com/galaxy321/pz-harness)
Use it only on a test copy of a save.

## Requires
- PZ Harness
