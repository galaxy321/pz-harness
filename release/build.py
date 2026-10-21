#!/usr/bin/env python3
"""Assemble the two Steam Workshop items for PZ Harness and check them.

    TG_SHIP=/path/to/unzipped/ship-x.y.z python3 test-ground/release/build.py

Items (Workshop/<key>/), each holding several mods under Contents/mods/ (a player ticks the
opt-in ones in the mod list):
  PZHarness          TestGround (core), TestGroundMemory, TestGroundCapture   (CAPTURE_IN)
  PZHarnessDevAddon  TestGroundBridge, TestGroundAutorun                      (+ Capture if CAPTURE_IN says so)

Mod sources: $TG_SRC_<id> if set, else $TG_SHIP/<id> if that exists (an unzipped ship zip), else
test-ground/<id>. Sources are only read. Per-mod overrides (name, description, versionMin) are in
overlay/mods/<id>/info.txt, art in overlay/mods/<id>/, the Steam page in overlay/items/<key>/.
Exits 1 while any blocker is open; the folders are still written.

The upload rules checked are the game's own (zombie.core.znet.SteamWorkshopItem, B42): preview.png
square 256 or 512 px and under 1,024,000 bytes; no .exe .dll .bat .app .dylib .sh .so .zip anywhere;
only folders in Contents/mods; each mod has mod.info with an id. Folders in a mod other than common/
and version folders (42/) are ignored by the game, so agent-skill/, guides/ and tools/ ship as files.
"""
import os, re, shutil, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
DOCS = os.path.join(ROOT, "docs")
WS = os.path.join(HERE, "Workshop")
SHIP = os.environ.get("TG_SHIP")
CAPTURE_IN = os.environ.get("TG_CAPTURE_IN", "PZHarness")   # "PZHarness" or "PZHarnessDevAddon"
TAGS = {"Build 40", "Build 41", "Build 42", "Animals", "Audio", "Balance", "Building", "Clothing/Armor",
        "Farming", "Food", "Framework", "Hardmode", "Interface", "Items", "Language/Translation", "Literature",
        "Map", "Military", "Misc", "Models", "Multiplayer", "Pop Culture", "Realistic", "Silly/Fun", "Skills",
        "Textures", "Traits", "Vehicles", "QoL", "WIP", "Weapons"}   # media/WorkshopTags.txt
BANNED = (".exe", ".dll", ".bat", ".app", ".dylib", ".sh", ".so", ".zip")
VISIBILITY = "unlisted"

def d(*p): return os.path.join(DOCS, *p)
SK_CORE = {"agent-skill/pz-run-benchmark": d("skills", "pz-run-benchmark"),
           "agent-skill/pz-read-test-report": d("skills", "pz-read-test-report"),
           "agent-skill/pz-mod-test-step": d("skills", "pz-mod-test-step"),
           "guides/quick-start.md": d("guides", "quick-start.md"),
           "tools/compare.py": os.path.join(ROOT, "compare.py")}
SK_BRIDGE = {"agent-skill/pz-test-ground": os.path.join(HERE, "skill", "pz-test-ground"),
             "agent-skill/pz-mod-writing": d("skills", "pz-mod-writing"),
             "agent-skill/pz-mod-performance": d("skills", "pz-mod-performance"),
             "guides/how-to-build-a-bridge.md": d("guides", "dev-addon", "how-to-build-a-bridge.md"),
             "guides/how-to-build-capture.md": d("guides", "dev-addon", "how-to-build-capture.md"),
             "guides/how-to-build-autopilot.md": d("guides", "dev-addon", "how-to-build-autopilot.md"),
             "tools/compare.py": os.path.join(ROOT, "compare.py")}

MODS = {"TestGround": SK_CORE, "TestGroundMemory": {}, "TestGroundCapture": {},
        "TestGroundBridge": SK_BRIDGE, "TestGroundAutorun": {}}
ITEMS = [
    {"key": "PZHarness", "title": "PZ Harness (B42 performance test bench)", "tags": "Build 42;Misc",
     "mods": ["TestGround", "TestGroundMemory"] + (["TestGroundCapture"] if CAPTURE_IN == "PZHarness" else [])},
    {"key": "PZHarnessDevAddon", "title": "PZ Harness Dev Add-on (for scripts and AI agents)", "tags": "Build 42;Misc",
     "mods": ["TestGroundBridge", "TestGroundAutorun"] + (["TestGroundCapture"] if CAPTURE_IN != "PZHarness" else [])},
]
JAVA = {"TestGroundMemory", "TestGroundCapture"}
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

def source(mid):
    for p in (os.environ.get("TG_SRC_" + mid), SHIP and os.path.join(SHIP, mid), os.path.join(ROOT, mid)):
        if p and os.path.isdir(os.path.join(p, "42")):
            return p
    return None

def kv(text):
    out = {}
    for l in text.splitlines():
        if "=" in l and not l.startswith("#"):
            k, v = l.split("=", 1)
            out[k.strip()] = v.strip()
    return out

def build_mod(item, mid, out):
    src = source(mid)
    if not src:
        blockers.append("%s: no sources found (TG_SHIP, TG_SRC_%s or test-ground/%s)" % (mid, mid, mid))
        return None
    ov = os.path.join(HERE, "overlay", "mods", mid)
    mod = os.path.join(out, "Contents", "mods", mid)
    shutil.copytree(os.path.join(src, "42", "media"), os.path.join(mod, "42", "media"))
    if os.path.isdir(os.path.join(src, "common")):
        shutil.copytree(os.path.join(src, "common"), os.path.join(mod, "common"))
    else:
        os.makedirs(os.path.join(mod, "common"))
        shutil.copy(os.path.join(ROOT, "TestGround", "common", "README.txt"), os.path.join(mod, "common", "README.txt"))
    # mod.info: the source's own keys (id, version, require, java*), with the overlay's name, description and
    # versionMin, plus poster and icon
    info = kv(read(os.path.join(src, "42", "mod.info")))
    info.update(kv(read(os.path.join(ov, "info.txt"))))
    info["poster"], info["icon"] = "poster.png", "icon.png"
    order = ["name", "id", "require", "description", "poster", "icon", "modversion", "versionMin", "javaJarFile", "javaPkgName"]
    keys = [k for k in order if k in info] + [k for k in info if k not in order]
    with open(os.path.join(mod, "42", "mod.info"), "w", encoding="utf-8", newline="\n") as f:
        f.write("".join("%s=%s\n" % (k, info[k]) for k in keys))
    for img in ("poster.png", "icon.png"):
        shutil.copy(os.path.join(ov, img), os.path.join(mod, "42", img))
    for dst, s in MODS[mid].items():
        dd = os.path.join(mod, dst)
        if os.path.isdir(s):
            shutil.copytree(s, dd)
        elif os.path.isfile(s):
            os.makedirs(os.path.dirname(dd), exist_ok=True)
            shutil.copy(s, dd)
        else:
            blockers.append("%s: missing %s" % (mid, s))
    if info.get("id") != mid:
        blockers.append("%s: mod.info id is %r" % (mid, info.get("id")))
    if "(dev tool)" in info.get("name", ""):
        blockers.append('%s: mod name still says "(dev tool)"' % mid)
    if mid in JAVA:
        jar = os.path.join(mod, "42", info.get("javaJarFile", "?"))
        if not os.path.isfile(jar):
            blockers.append("%s: javaJarFile %s is missing" % (mid, info.get("javaJarFile")))
        if "ZombieBuddy" not in info.get("description", ""):
            blockers.append("%s: the description doesn't say it needs ZombieBuddy" % mid)
    for p in ("42/mod.info", "42/poster.png", "42/icon.png", "common"):
        if not os.path.exists(os.path.join(mod, p)):
            blockers.append("%s: missing %s" % (mid, p))
    print("  %-18s %s  (from %s)" % (mid, info.get("modversion"), src))
    return {"mod": mod, "info": info, "lua": lua_files(mod)}

def build_item(item):
    key = item["key"]
    out = os.path.join(WS, key)
    ov = os.path.join(HERE, "overlay", "items", key)
    if os.path.isdir(out):
        shutil.rmtree(out)
    print("built Workshop/%s" % key)
    mods = {m: build_mod(item, m, out) for m in item["mods"]}
    shutil.copy(os.path.join(ov, "preview.png"), os.path.join(out, "preview.png"))
    # workshop.txt: one description= line per line of description.txt, as the game's template does. No id= line:
    # the game writes the published id into it after the first upload; copy that file to
    # overlay/items/<key>/workshop.id.txt and the build keeps the id from then on.
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
        blockers.append("%s: preview.png must be a 256x256 or 512x512 PNG (is %s)" % (key, size))
    if os.path.getsize(os.path.join(out, "preview.png")) > 1024000:
        blockers.append("%s: preview.png is over 1,024,000 bytes" % key)
    for t in item["tags"].split(";"):
        if t not in TAGS:
            blockers.append("%s: tag %r is not in the game's tag list" % (key, t))
    if "@REPO_URL@" in read(os.path.join(out, "workshop.txt")):
        blockers.append("%s: the description still has the @REPO_URL@ placeholder" % key)
    for root, _, files in os.walk(os.path.join(out, "Contents")):
        for n in files:
            if n.lower().endswith(BANNED):
                blockers.append("%s: the uploader refuses %s" % (key, os.path.relpath(os.path.join(root, n), out)))
    for ent in os.listdir(os.path.join(out, "Contents", "mods")):
        if not os.path.isdir(os.path.join(out, "Contents", "mods", ent)):
            blockers.append("%s: Contents/mods holds a file: %s" % (key, ent))
    for root, _, files in os.walk(out):
        for n in files:
            p = os.path.join(root, n)
            if p.endswith((".lua", ".md", ".txt", ".info", ".py")):
                t = read(p)
                for pat, why in ((r"[A-Za-z]:\\\\?Users\\\\?(?!<)", "a Windows user path"), (r"tony6", "the PC's user name"),
                                 (r"perf-logs", "this PC's log folder")):
                    if re.search(pat, t):
                        blockers.append("%s: %s in %s" % (key, why, os.path.relpath(p, out)))
                if re.search(r"Lumberjack", t):   # the user's test save name, in comments and UI-tour test data
                    notes.append("%s: the test save's name appears in %s (a comment or test data; scrub in a later build)" % (key, os.path.relpath(p, out)))
    return mods

def main():
    if os.path.isdir(WS):
        shutil.rmtree(WS)
    built = {}
    for it in ITEMS:
        built.update(build_item(it))
    core = built.get("TestGround")
    if core:
        lua = core["lua"]
        # the core must not run Lua from a file: that lives in the bridge, and only with -debug or the sandbox option
        if re.search(r'cmd == "lua"|loadstring\(|dofile\(', lua):
            blockers.append("TestGround: runs Lua from a file (the lua command belongs in the bridge)")
        if re.search(r"TestGround_cmd\.txt", lua):
            blockers.append("TestGround: polls TestGround_cmd.txt (the bridge does that)")
        if not re.search(r"isClient\(\)", lua) or not re.search(r"isServer\(\)", lua):
            blockers.append("TestGround: no isClient()/isServer() guard, so a run could start in multiplayer")
        if not re.search(r"ISModalDialog|ISTextBox|confirm", lua):
            blockers.append("TestGround: no first-run warning that a run changes the save")
        roads = os.path.join(core["mod"], "42", "media", "lua", "shared", "TestGroundRoads.lua")
        if not os.path.isfile(roads) or not re.search(r"scanned", read(roads)):
            blockers.append("TestGround: tree-road list is not from a real treescan")
        if not re.search(r"getModFileReader", lua):
            blockers.append("TestGround: the fixed baseline isn't read with getModFileReader")
        if not os.path.isfile(os.path.join(core["mod"], "42", "media", "TestGround", "quick.txt")):
            blockers.append("TestGround: no quick.txt, but the page promises a quick test")
        if not re.search(r"Benchmark Save", lua):
            blockers.append("TestGround: no Benchmark Save button in the core, but the page describes it")
        if re.search(r"TestGroundAutorun\.lua", "".join(os.listdir(os.path.join(core["mod"], "42", "media", "lua", "client")))):
            notes.append("TestGround holds the flag-file engine (TestGround_autorun.txt); the page must disclose it")
    br = built.get("TestGroundBridge")
    if br:
        lua = br["lua"]
        if not re.search(r"^require=\\TestGround\s*$", read(os.path.join(br["mod"], "42", "mod.info")), re.M):
            blockers.append("TestGroundBridge: mod.info must have require=\\TestGround")
        if not re.search(r"isClient\(\)", lua) or not re.search(r"isServer\(\)", lua):
            blockers.append("TestGroundBridge: no isClient()/isServer() guard; it must do nothing in multiplayer")
        so = os.path.join(br["mod"], "42", "media", "sandbox-options.txt")
        if os.path.isfile(so):
            keys = ["Sandbox_" + k for k in re.findall(r"(?:translation|page)\s*=\s*(\w+)", read(so))]
            tr = ""
            for root, _, files in os.walk(os.path.join(br["mod"], "42", "media", "lua", "shared", "Translate")):
                tr += "".join(read(os.path.join(root, n)) for n in files)
            missing = sorted(set(k for k in keys if k not in tr))
            if missing:
                notes.append("TestGroundBridge: no EN translation for sandbox keys %s" % ", ".join(missing))
        skill = os.path.join(br["mod"], "agent-skill", "pz-test-ground", "SKILL.md")
        if not os.path.isfile(skill) or not read(skill).startswith("---\nname: pz-test-ground\n"):
            blockers.append("TestGroundBridge: agent-skill/pz-test-ground/SKILL.md missing or without front matter")
    for b in blockers: print("BLOCKER: " + b)
    for n in notes: print("note:    " + n)
    print("art: from overlay/mods/<id>/ (poster 512, icon 64) and overlay/items/<key>/preview.png (256); source files in art-v2/")
    return 1 if blockers else 0

if __name__ == "__main__":
    sys.exit(main())
