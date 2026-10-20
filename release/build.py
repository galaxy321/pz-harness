#!/usr/bin/env python3
"""Assemble the Steam Workshop folders for Test Ground and Test Ground Bridge, and check them.

    python3 test-ground/release/build.py
    TG_SRC_TestGround=/path/to/unzipped/ship-1.13.16/TestGround python3 test-ground/release/build.py

Writes release/Workshop/TestGround/ and release/Workshop/TestGroundBridge/. Copy each to
Zomboid\\Workshop\\ and upload it from the main menu > Workshop. Mod sources are read from
test-ground/TestGround and test-ground/TestGroundBridge and are never changed. Exits 1 while
any blocker is open; the folders are still written so they can be looked at.

The upload rules checked here are the game's own (zombie.core.znet.SteamWorkshopItem, B42):
preview.png square 256 or 512 px and under 1,024,000 bytes; no .exe .dll .bat .app .dylib .sh
.so .zip anywhere; only folders in Contents/mods; each mod has mod.info with an id. Folders in
a mod other than common/ and version folders (42/) are ignored by the game, so agent-skill/ and
tools/ ship as plain files.
"""
import os, re, shutil, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
WS = os.path.join(HERE, "Workshop")
TAGS = {"Build 40", "Build 41", "Build 42", "Animals", "Audio", "Balance", "Building", "Clothing/Armor",
        "Farming", "Food", "Framework", "Hardmode", "Interface", "Items", "Language/Translation", "Literature",
        "Map", "Military", "Misc", "Models", "Multiplayer", "Pop Culture", "Realistic", "Silly/Fun", "Skills",
        "Textures", "Traits", "Vehicles", "QoL", "WIP", "Weapons"}   # media/WorkshopTags.txt
BANNED = (".exe", ".dll", ".bat", ".app", ".dylib", ".sh", ".so", ".zip")

ITEMS = [
    {"id": "TestGround", "title": "Test Ground (B42 performance test bench)", "tags": "Build 42;Misc",
     "lua": "42/media/lua/client/TestGround.lua", "extra": {}},
    {"id": "TestGroundBridge", "title": "Test Ground Bridge (for scripts and AI agents)", "tags": "Build 42;Misc",
     "lua": "42/media/lua/client/TestGroundBridge.lua",
     "extra": {"agent-skill/pz-test-ground": os.path.join(HERE, "skill", "pz-test-ground"),
               "tools/compare.py": os.path.join(ROOT, "compare.py")}},
]
VISIBILITY = "unlisted"

blockers, notes = [], []

def read(p):
    with open(p, encoding="utf-8", errors="replace") as f:
        return f.read()

def png_size(p):
    with open(p, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])

def lua_files(mod):
    out = ""
    for root, _, files in os.walk(mod):
        for n in files:
            if n.endswith(".lua"):
                out += read(os.path.join(root, n))
    return out

def build(item):
    mid = item["id"]
    # TG_SRC_<id> builds that mod from another folder (an unzipped ship-x.y.z), e.g. a cleared build
    src = os.environ.get("TG_SRC_" + mid) or os.path.join(ROOT, mid)
    ov = os.path.join(HERE, "overlay", mid)
    out = os.path.join(WS, mid)
    mod = os.path.join(out, "Contents", "mods", mid)
    if not os.path.isdir(os.path.join(src, "42", "media")):
        blockers.append("%s: no sources at test-ground/%s yet" % (mid, mid))
        return None
    main = read(os.path.join(src, item["lua"]))
    m = re.search(r'local VERSION = "([\d.]+)"', main)
    version = m.group(1) if m else "0.0.0"
    if os.path.isdir(out):
        shutil.rmtree(out)
    shutil.copytree(os.path.join(src, "42", "media"), os.path.join(mod, "42", "media"))
    shutil.copytree(os.path.join(src, "common"), os.path.join(mod, "common"))
    info = read(os.path.join(ov, "mod.info")).replace("@VERSION@", version)
    with open(os.path.join(mod, "42", "mod.info"), "w", encoding="utf-8", newline="\n") as f:
        f.write(info)
    for img in ("poster.png", "icon.png"):
        shutil.copy(os.path.join(ov, img), os.path.join(mod, "42", img))
    shutil.copy(os.path.join(ov, "preview.png"), os.path.join(out, "preview.png"))
    for dst, s in item["extra"].items():
        d = os.path.join(mod, dst)
        if os.path.isdir(s):
            shutil.copytree(s, d)
        elif os.path.isfile(s):
            os.makedirs(os.path.dirname(d), exist_ok=True)
            shutil.copy(s, d)
        else:
            blockers.append("%s: missing %s" % (mid, s))
    # workshop.txt: one description= line per line of description.txt, as the game's template does.
    # No id= line: the game writes the published id into it after the first upload; copy that file
    # back to overlay/<mod>/workshop.id.txt and the build will keep the id from then on.
    lines = ["version=1"]
    idf = os.path.join(ov, "workshop.id.txt")
    if os.path.isfile(idf):
        m = re.search(r"^id=(\d+)", read(idf), re.M)
        if m: lines.append("id=" + m.group(1))
    lines.append("title=" + item["title"])
    lines += ["description=" + l for l in read(os.path.join(ov, "description.txt")).rstrip("\n").split("\n")]
    lines += ["tags=" + item["tags"], "visibility=" + VISIBILITY]
    with open(os.path.join(out, "workshop.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    # the game's own upload checks
    size = png_size(os.path.join(out, "preview.png"))
    if not size or size[0] != size[1] or size[0] not in (256, 512):
        blockers.append("%s: preview.png must be a 256x256 or 512x512 PNG (is %s)" % (mid, size))
    if os.path.getsize(os.path.join(out, "preview.png")) > 1024000:
        blockers.append("%s: preview.png is over 1,024,000 bytes" % mid)
    for t in item["tags"].split(";"):
        if t not in TAGS:
            blockers.append("%s: tag %r is not in the game's tag list" % (mid, t))
    for root, dirs, files in os.walk(os.path.join(out, "Contents")):
        for n in files:
            if n.lower().endswith(BANNED):
                blockers.append("%s: the uploader refuses %s" % (mid, os.path.relpath(os.path.join(root, n), out)))
    if not re.search(r"^id=" + mid + r"\s*$", info, re.M):
        blockers.append("%s: mod.info id is not %s" % (mid, mid))
    if "(dev tool)" in info:
        blockers.append('%s: mod name still says "(dev tool)"' % mid)
    for p in ("42/mod.info", "42/poster.png", "42/icon.png", "common"):
        if not os.path.exists(os.path.join(mod, p)):
            blockers.append("%s: missing %s" % (mid, p))
    allfiles = []
    for root, _, files in os.walk(out):
        allfiles += [os.path.join(root, n) for n in files]
    for p in allfiles:
        if p.endswith((".lua", ".md", ".txt", ".info", ".py")):
            t = read(p)
            for pat, why in ((r"[A-Za-z]:\\\\Users\\\\(?!<)", "a Windows user path"), (r"tony6", "the PC's user name"),
                             (r"Lumberjack", "the PC's save name")):
                if re.search(pat, t):
                    blockers.append("%s: %s in %s" % (mid, why, os.path.relpath(p, out)))
    if "@REPO_URL@" in read(os.path.join(out, "workshop.txt")):
        blockers.append("%s: description still has the @REPO_URL@ placeholder; set the GitHub link in overlay/%s/description.txt" % (mid, mid))
    print("built Workshop/%s (%s %s)" % (mid, mid, version))
    return {"mod": mod, "main": main, "lua": lua_files(mod), "info": info}

def main():
    core = build(ITEMS[0])
    bridge = build(ITEMS[1])
    if core:
        lua = core["lua"]
        # the core must not read command files or run code: that lives in the bridge
        if re.search(r'cmd == "lua"|loadstring\(', lua):
            blockers.append('TestGround: still runs Lua from the command file (the "lua" command belongs in the bridge)')
        if re.search(r"TestGround_cmd\.txt", lua):
            blockers.append("TestGround: still polls TestGround_cmd.txt (the bridge does that now)")
        if not re.search(r"isClient\(\)", lua) or not re.search(r"isServer\(\)", lua):
            blockers.append("TestGround: no isClient()/isServer() guard, so a run could start in multiplayer")
        if not re.search(r"ISModalDialog|ISTextBox|confirm", core["main"]):
            blockers.append("TestGround: no first-run warning that a run changes the save")
        roads = read(os.path.join(core["mod"], "42", "media", "lua", "shared", "TestGroundRoads.lua"))
        if not re.search(r"scanned", roads):
            blockers.append("TestGround: tree-road list is not from a real treescan yet")
        if not re.search(r"getModFileReader", lua):
            blockers.append("TestGround: the baseline is re-surveyed per save; ship the fixed plan (data/baseline_frozen.txt) and read it with getModFileReader")
        if re.search(r'"clear"', core["main"]) and not re.search(r'obstacles = (lval == "clear" and "clear" or "avoid"|"avoid")', core["main"]):
            notes.append("TestGround: obstacles defaults to clear, so the fast drive removes parked cars in the player's save")
    if bridge:
        lua = bridge["lua"]
        if not re.search(r"^require=\\TestGround\s*$", bridge["info"], re.M):
            blockers.append("TestGroundBridge: mod.info must have require=\\TestGround")
        if not re.search(r"isClient\(\)", lua) or not re.search(r"isServer\(\)", lua):
            blockers.append("TestGroundBridge: no isClient()/isServer() guard; it must do nothing in multiplayer")
        if not re.search(r"TestGround\.command", lua):
            notes.append("TestGroundBridge: doesn't call TestGround.command; check it still runs the core's commands")
        so = os.path.join(bridge["mod"], "42", "media", "sandbox-options.txt")
        if os.path.isfile(so):
            keys = ["Sandbox_" + k for k in re.findall(r"(?:translation|page)\s*=\s*(\w+)", read(so))]
            tr = ""
            for root, _, files in os.walk(os.path.join(bridge["mod"], "42", "media", "lua", "shared", "Translate")):
                tr += "".join(read(os.path.join(root, n)) for n in files)
            missing = sorted(set(k for k in keys if k not in tr))
            if missing:
                notes.append("TestGroundBridge: no EN translation for sandbox keys %s, so the sandbox screen shows raw keys" % ", ".join(missing))
        skill = os.path.join(bridge["mod"], "agent-skill", "pz-test-ground", "SKILL.md")
        if not os.path.isfile(skill) or not read(skill).startswith("---\nname: pz-test-ground\n"):
            blockers.append("TestGroundBridge: agent-skill/pz-test-ground/SKILL.md missing or without front matter")
    for b in blockers: print("BLOCKER: " + b)
    for n in notes: print("note:    " + n)
    print("placeholder art: replace overlay/<mod>/poster.png (512x512), icon.png (64x64) and preview.png (256x256)")
    return 1 if blockers else 0

if __name__ == "__main__":
    sys.exit(main())
