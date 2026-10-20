# Mock test for Crane Test Ground: the real CraneCore and CraneCrankAction against a fake
# two-floor shell, then the crane step's begin/tick until it finishes. Run: python3 mock_test.py
import os, sys, lupa.lua51 as lupa
here = os.path.dirname(os.path.abspath(__file__))
crane = "/mnt/project-files/crane-mod/CraneMod/42/media/lua/shared/"
step = os.path.join(here, "..", "CraneTestGround", "42", "media", "lua", "client", "CraneTestGround", "CraneTest.lua")
fails = []
def check(ok, what):
    print(("ok   " if ok else "FAIL ") + what)
    if not ok: fails.append(what)

LAST = {}
def lupa_inv(r): return LAST['inv']

def run(case, structure, stopAt=None, site=True):
    L = lupa.LuaRuntime()
    g = L.globals()
    g.LUAROOT = crane
    L.execute(open(os.path.join(here, "mock.lua")).read())
    L.execute(structure)
    L.execute(open(crane + "CraneMod/CraneCore.lua").read())
    L.execute(open(crane + "TimedActions/CraneCrankAction.lua").read())
    L.execute(open(step).read())
    g.STOPAT = stopAt
    g.NOSITE = not site
    L.execute("for _, f in ipairs(StartFns) do f() end")
    res = L.execute("""
        local r = { p = PLAYER, plan = { extra = {} }, buildSite = (not NOSITE) and { x = 10, y = 10, z = 0, w = 4, h = 3, zmax = 1 } or nil }
        local st = { a = 2, b = 120, t0 = CLOCK, args = {} }
        STEP.begin(r, st)
        if st.skip then
            local left = 0
            for x = 8, 15 do for y = 8, 14 do for z = 0, 1 do
                local sq = getCell():getGridSquare(x, y, z)
                if sq then for _, o in ipairs(sq.objs) do if o.md and o.md.CraneMod then left = left + 1 end end end
            end end end
            return "skip", st.skip .. " |left " .. left, ""
        end
        local mid = {}
        for i = 1, 20000 do
            CLOCK = CLOCK + 33
            runQueue()
            if STOPAT and i == STOPAT then if r.cleanup then r.cleanup(); r.cleanup = nil end; st.result = "stopped"; break end
            if BOOM_AT and i == BOOM_AT then CraneMod.state = function() error("boom") end end
            if STEP.tick(r, st, CLOCK, 33) then break end
            local okS, s = pcall(CraneMod.state, st.L)
            if okS then mid[s] = true end
        end
        local left = 0
        for x = 8, 15 do for y = 8, 14 do for z = 0, 1 do
            local sq = getCell():getGridSquare(x, y, z)
            if sq then for _, o in ipairs(sq.objs) do if o.md and o.md.CraneMod then left = left + 1 end end end
        end end end
        INVLEFT = #PLAYER.inv.items
        return st.result or "no result", tostring(mid.up) .. " " .. tostring(left), table.concat(TRACE, "\\n")
    """)
    LAST['inv'] = g.INVLEFT
    print("--", case); print(res[0]); print(res[2])
    return res

shell = """
for x = 10, 13 do for y = 10, 12 do newSquare(x, y, 0, true); newSquare(x, y, 1, true) end end
for x = 8, 15 do for y = 8, 14 do if not getCell():getGridSquare(x, y, 0) then newSquare(x, y, 0, true) end end end
"""
r = run("shell", shell)
check(r[0].startswith("crane facing"), "the step builds a crane on the shell's upper floor")
check("2 of 2 cycles" in r[0], "two raise/lower cycles")
check("9 of 9 items back" in r[0], "the load comes back down")
check("cranked from floor 1 1 1 1 (winch floor 1)" in r[0], "every crank is made from the winch's floor (floor 1)")
check("stored 3 of 3 in the box" in r[0] and "3 of 3 on the landing after the lift" in r[0] and "taken from the landing by the transfer action 3 of 3, 0 left on the landing" in r[0],
      "items: stored in the box by the transfer action, found on the landing after the lift, taken out upstairs")
up, left = r[1].split()
check(up == "true", "the box was up at some point")
check(left == "0", "no crane objects left after the step")
r = run("player falls once after the teleport", shell + "FALL_ONCE = true")
check(r[0].startswith("crane facing") and "cranked from floor 1 1 1 1" in r[0] and "2 of 2 cycles" in r[0] and "player was not on floor 1" in r[2], "a fall after the teleport: stood up again, every crank still on floor 1")
r = run("player always falls", shell + "FALL_ALWAYS = true")
check("could not stand on floor 1" in r[0] and "cranked from floor  (winch" in r[0] and "0 of 2 cycles" in r[0], "never able to stand upstairs: the step ends without cranking, says why")
r = run("transfers refused", shell + "TRANSFER_REFUSED = true")
check("stored 0 of 3 in the box" in r[0] and r[0].startswith("crane facing"), "a refused transfer is reported as 0 of 3, the lift still runs")
r = run("items off", shell, None)
r = run("player falls in the middle of a crank", shell + "FALL_MID = true; MIDCRANK = 1000 + 33 * 220")
check(r[0].startswith("crane facing") and "left floor 1 during a crank" in r[2] and "cranked from floor 1 1 1 1 (winch floor 1)" in r[0], "a fall during a crank: noticed, stood up again, floors read at the end of each crank")
check(lupa_inv(r) == 0, "the test items are out of the player's inventory after the step")
r = run("no ground", "for x = 10, 13 do for y = 10, 12 do newSquare(x, y, 1, true) end end")
check(r[0] == "skip" and "no upper-floor edge" in r[1] and "error" not in r[1], "no floor below: skipped with the reason, not the error path")
r = run("stopped mid-step", shell, 150)
check(r[0] == "stopped" and r[1].split()[1] == "0", "a run stopped while the box is up: the clean-up takes every crane object off")
check(lupa_inv(r) == 0, "a stopped run: the test items are out of the inventory too")
r = run("stairs on the box square", shell + "getCell():getGridSquare(9, 10, 0).stairs = true; getCell():getGridSquare(9, 11, 0).stairs = true; getCell():getGridSquare(9, 12, 0).stairs = true", None)
check(r[0] == "skip" or "facing w" not in r[0], "no box on a stairs square (the west edge is refused)")
r = run("nowhere to stand", shell + "for x = 10, 13 do for y = 10, 12 do getCell():getGridSquare(x, y, 1).blocked = true end end", None)
check(r[0] == "skip" and r[1].endswith("|left 0"), "everything blocked: skipped, nothing left behind")
foreign = shell + "local sq = getCell():getGridSquare(9, 12, 0); local o = IsoThumpable.new(nil, sq, 'cranemod_hook_57'); o:getModData().CraneMod = { role = 'hook', wx = 99, wy = 99, wz = 1 }; sq:AddTileObject(o)"
r = run("another crane's part nearby", foreign, 150)
check(r[1].split()[1] == "1", "a part of another crane within 3 tiles is left alone")
r = run("tick throws with the box up", shell + "BOOM_AT = 150", None)
check(r[0].startswith("crane step error") and r[1].split()[1] == "0", "an error mid-step takes the crane off at once")
check(lupa_inv(r) == 0, "an error mid-step: the test items are out of the inventory too")
r = run("HasStairs errors in game", shell + "STAIRS_ERR = true", None)
check(r[0].startswith("crane facing"), "a placement check that errors is left out, the crane is still built")
r = run("no build site: a building nearby", shell + "PLAYER.x, PLAYER.y = 20, 20; function PLAYER:getX() return self.x end; function PLAYER:getY() return self.y end", None, False)
check(r[0].startswith("crane facing") and "a building near the player" in r[2], "no build site: the scan finds the nearby upper floor")
print("ALL OK" if not fails else "FAILED: " + ", ".join(fails))
sys.exit(1 if fails else 0)
