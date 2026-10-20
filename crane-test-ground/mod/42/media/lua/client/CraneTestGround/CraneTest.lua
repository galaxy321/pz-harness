-- Crane Test Ground 0.2.1 (dev tool): a Test Ground step for the Crane mod.
--
--   step = crane [cycles] [seconds] [phase]      e.g. step = crane 2 90 crane_lift
--
-- Needs an upper floor with an open edge: the structure an earlier "build" step put up in the
-- same run (e.g. build mod:shell2), or a plan line "crane.winch = x,y,z" (the landing square, on
-- an upper floor) with "crane.facing = N|E|S|W". The spot and facing are checked with the Crane
-- mod's own placement check (CraneMod.Build.OnIsValidWinch / OnIsValidBox). The winch, landing
-- and box are made as the build menu makes them (an IsoThumpable with the mod's sprite, then the
-- mod's OnCreate callback), the box gets a fixed load, and the player cranks it up and down with
-- the mod's own CraneCrankAction, standing behind the winch. At the end every crane object is
-- taken off again and the result says whether the load came back.
-- Only acts when Test Ground and Crane are both loaded.
-- 0.1.1 (review of 18 Oct): the crane is registered as the run's clean-up as soon as anything is
-- placed, so a run stopped mid-step (or a step that throws) still takes it off; a failed build
-- takes off whatever it placed; placement also refuses solid, blocked and stair squares (the
-- build menu's collision check, which OnIsValid alone doesn't cover); no free square to stand on
-- skips the step instead of teleporting the player into the air.
-- 0.1.2 (review of 18 Oct): begin and tick run under pcall; an error takes the crane off at once
-- (a later step, such as drivefast, reuses the run's clean-up slot). Each collision check runs on
-- its own: one that errors in game is left out with a trace line instead of refusing every square.
-- 0.1.3 (trial of 18 Oct: the shell build placed nothing): with no usable build site the step looks
-- for an upper-floor edge of the existing buildings around the player (K.SCAN_RADIUS tiles,
-- nearest first), with the same checks. "crane.scan = 0" in the plan turns that off.
-- 0.1.4 (review of 18 Oct): the scan walks only each ring's edge (it walked the whole box every
-- ring), and calls the Crane mod's check only where there is a floor below the rope square, so a
-- scan that finds nothing doesn't fill the console with "winch placement" lines.

-- 0.2.0 (the user, on the showcase film: the crank ran on the ground floor, and items weren't checked):
-- (1) The step used to teleport the player onto the upper floor and crank at once. In the film the
-- player fell to the ground floor 2.5 s later (trace: PlayerFallingState, z 1 to 0) and the crank went
-- on from there. The Crane mod's menu only offers the crank to a player standing on the winch's floor
-- (CraneMenu.lua:92) but CraneCrankAction itself checks nothing about where the player is, so queuing
-- the action directly cranked from anywhere. The step now checks the player stays standing on the
-- winch's floor for K.STAND_MS before every crank (up to K.STAND_TRIES teleports), and says in the
-- result which floor each crank was made from. (2) Items: with the crane built, three test items go from
-- the player into the box on the ground floor by the game's own transfer action, the box is raised,
-- the same items are found on the landing and taken out of it by the transfer action standing upstairs,
-- the box is lowered and must hold only the fixed load. "crane.items = 0" in the plan leaves it out.

local K = {}
K.VERSION = "0.2.1"
K.ITEMS = { "Base.Pencil", "Base.Pen", "Base.Nails" }
K.STAND_MS = 3000   -- the film's fall came 2.5 s after the teleport
K.STAND_TRIES = 3
K.TRANSFER_TIMEOUT_MS = 20000
K.LOAD = { { "Base.Plank", 6 }, { "Base.Log", 1 }, { "Base.Nails", 2 } }
K.FACES = { "W", "N", "E", "S" }
K.HOLD_UP_MS = 3000      -- the box hangs this long before it goes back down
K.HOLD_DOWN_MS = 2000
K.START_MS = 2000        -- after the build, before the first crank (camera settles on the player)
K.CRANK_TIMEOUT_MS = 40000
K.SCAN_RADIUS = 40
K.SCAN_MAX_Z = 3

local function say(s) print("[CraneTestGround] " .. s) end

local function itemCount(c)
    if not c then return 0 end
    local n = 0
    pcall(function() n = c:getItems():size() end)
    return n
end

local function square(x, y, z) return getCell():getGridSquare(x, y, z) end

-- The build menu's collision check: nothing solid, no stairs, free to stand in.
K.CHECKS = {
    { "isSolid", function(sq) return sq:isSolid() end },
    { "isSolidTrans", function(sq) return sq:isSolidTrans() end },
    { "HasStairs", function(sq) return sq:HasStairs() end },
    { "isFree", function(sq) return not sq:isFree(false) end },
}
K.brokenCheck = {}
function K.clearSquare(sq)
    if not sq then return false end
    for _, c in ipairs(K.CHECKS) do
        if not K.brokenCheck[c[1]] then
            local ok, bad = pcall(c[2], sq)
            if not ok then
                K.brokenCheck[c[1]] = true
                say("placement check " .. c[1] .. " errors here, left out: " .. tostring(bad))
                pcall(function() TestGround.trace("crane: placement check " .. c[1] .. " errors, left out") end)
            elseif bad then
                return false
            end
        end
    end
    return true
end

-- A stand-in for the build menu's tileInfo: OnIsValidWinch only asks for the sprite name.
local function tileInfo(name) return { getSpriteName = function() return name end } end

local function sprites(letter)
    local l = string.lower(letter)
    local winch = (l == "e" or l == "w") and ("cranemod_winch_" .. l .. "_53") or ("cranemod_winch_" .. l .. "_52")
    return winch, "cranemod_column_" .. l .. "_48"
end

-- Is the landing square (x,y,z) with this facing a place the build menu would allow?
function K.valid(x, y, z, letter)
    local C = CraneMod
    local d = C.DIRS[letter]
    local lsq, wsq = square(x, y, z), square(x - d[1], y - d[2], z)
    if not lsq or not wsq then return false, "square not loaded" end
    local wn, cn = sprites(letter)
    local okW, vW = pcall(C.Build.OnIsValidWinch, { square = wsq, facing = letter, tileInfo = tileInfo(wn) })
    if not okW or not vW then return false, "winch square refused" end
    local okL, vL = pcall(C.Build.OnIsValidWinch, { square = lsq, facing = letter, tileInfo = tileInfo(cn) })
    if not okL or not vL then return false, "landing square refused" end
    if not K.clearSquare(wsq) or not K.clearSquare(lsq) then return false, "winch or landing square not free (solid, stairs or blocked)" end
    local g = square(x + d[1], y + d[2], z - 1)
    if not K.clearSquare(g) then return false, "box square not free (solid, stairs or blocked)" end
    return true
end

-- Every upper-floor square of the run's build site, with each facing, until one is valid.
function K.findSpot(site)
    for z = (site.zmax or site.z), site.z + 1, -1 do
        for _, letter in ipairs(K.FACES) do
            for x = site.x, site.x + site.w - 1 do
                for y = site.y, site.y + site.h - 1 do
                    if K.valid(x, y, z, letter) then return x, y, z, letter end
                end
            end
        end
    end
    return nil
end

-- Upper-floor edges of the buildings around (px,py), nearest first. A cheap test first (a floor
-- here, none on the rope square beyond), then the full check.
function K.scan(px, py, radius)
    local C = CraneMod
    local cell = getCell()
    for rad = 1, radius do
        for z = 1, K.SCAN_MAX_Z do
            -- the ring's edge: top and bottom rows, then the two sides without their corners
            for i = 0, 8 * rad - 1 do
                local dx, dy
                if i <= 2 * rad then dx, dy = i - rad, -rad
                elseif i <= 4 * rad + 1 then dx, dy = i - 3 * rad - 1, rad
                elseif i <= 6 * rad then dx, dy = -rad, i - 5 * rad - 1
                else dx, dy = rad, i - 7 * rad end
                local x, y = px + dx, py + dy
                local sq = cell:getGridSquare(x, y, z)
                if sq and sq:getFloor() then
                    for _, letter in ipairs(K.FACES) do
                        local d = C.DIRS[letter]
                        local ax, ay = x + d[1], y + d[2]
                        local air = cell:getGridSquare(ax, ay, z)
                        local below = cell:getGridSquare(ax, ay, z - 1)
                        if not (air and air:getFloor()) and below and below:getFloor() and K.valid(x, y, z, letter) then return x, y, z, letter end
                    end
                end
            end
        end
    end
    return nil
end

local function newThumpable(sq, sprite)
    local t = IsoThumpable.new(getCell(), sq, sprite, false, {})
    t:setIsDismantable(false)
    t:setCanBarricade(false)
    t:setIsHoppable(false)
    return t
end

-- The winch and its landing, then the box on the hook square, through the mod's callbacks.
function K.build(x, y, z, letter)
    local C = CraneMod
    local d = C.DIRS[letter]
    local wn, cn = sprites(letter)
    local wsq, lsq = square(x - d[1], y - d[2], z), square(x, y, z)
    local winch = newThumpable(wsq, wn)
    wsq:AddSpecialObject(winch)
    C.Build.OnCreateWinch({ thumpable = winch })
    local landing = newThumpable(lsq, cn)
    lsq:AddSpecialObject(landing)
    C.Build.OnCreateWinch({ thumpable = landing })
    local L = C.layout(winch)
    if not L then return nil, "the winch didn't link to its landing" end
    C.state(L)
    if not L.hook then return nil, "no hook under the jib after the build" end
    local okB, vB = pcall(C.Build.OnIsValidBox, { square = L.groundSq })
    if not okB or not vB then return nil, "the box isn't allowed on the hook square" end
    local box = newThumpable(L.groundSq, C.BOX_SPRITE)
    box:setCanPassThrough(false)
    box:setIsThumpable(true)
    box:setBlockAllTheSquare(true)
    box:setMaxHealth(200)
    box:setHealth(200)
    L.groundSq:AddSpecialObject(box)
    C.Build.OnCreateBox({ thumpable = box })
    C.state(L)
    if not L.box then return nil, "no box after OnCreateBox" end
    return L
end

function K.fill(L)
    local c = L.box:getContainer()
    local n = 0
    for _, e in ipairs(K.LOAD) do
        for _ = 1, e[2] do
            if pcall(function() c:AddItem(e[1]) end) then n = n + 1 end
        end
    end
    pcall(function() c:setExplored(true) end)
    return n, c:getCapacityWeight()
end

-- Every object of this step's crane (landing x,y,z; winch one tile back), load included, found
-- by the Crane mod's data within 3 tiles: catches a half-built crane too. Another crane in the
-- save is left alone (its parts point at another winch).
function K.clearAround(x, y, z, letter)
    local C = CraneMod
    local d = C.DIRS[letter]
    local wx, wy = x - d[1], y - d[2]
    local function ours(o, xx, yy, zz)
        local dd = C.data(o)
        if not dd then return false end
        if dd.wx then return dd.wx == wx and dd.wy == wy and dd.wz == z end
        return zz == z and ((xx == wx and yy == wy) or (xx == x and yy == y))
    end
    local n = 0
    for zz = z - 1, z do
        for xx = x - 3, x + 3 do
            for yy = y - 3, y + 3 do
                local sq = square(xx, yy, zz)
                if sq then
                    pcall(function()
                        local objs = sq:getObjects()
                        for i = objs:size() - 1, 0, -1 do
                            local o = objs:get(i)
                            if ours(o, xx, yy, zz) then
                                local c = o:getContainer()
                                if c then c:removeAllItems() end
                                sq:transmitRemoveItemFromSquare(o)
                                n = n + 1
                            end
                        end
                    end)
                end
            end
        end
    end
    pcall(function() ISInventoryPage.dirtyUI() end)
    return n
end

-- Every crane object off its square again, load included (no materials dropped).
function K.clear(L)
    local C = CraneMod
    local n = 0
    pcall(function() C.state(L) end)
    local function rm(sq, o)
        if sq and o then
            pcall(function()
                local c = o:getContainer()
                if c then c:removeAllItems() end
            end)
            if pcall(function() sq:transmitRemoveItemFromSquare(o) end) then n = n + 1 end
        end
    end
    rm(L.groundSq, L.box); rm(L.groundSq, L.hook)
    rm(L.airSq, L.hanging); rm(L.airSq, L.chain)
    rm(L.landingSq, L.landing)
    rm(L.winch and L.winch:getSquare(), L.winch)
    pcall(function() ISInventoryPage.dirtyUI() end)
    return n
end

local function onFloor(p, z)
    local pz = 0
    pcall(function() pz = p:getZ() end)
    return math.floor(pz + 0.05) == z and (z - pz) < 0.3
end

local function holds(c, it)
    if not c then return false end
    local ok, has = pcall(function() return c:contains(it) end)
    if ok and has ~= nil then return has and true or false end
    local n = 0
    pcall(function()
        local l = c:getItems()
        for i = 0, l:size() - 1 do if l:get(i) == it then n = 1 end end
    end)
    return n == 1
end

local function countHeld(c, items)
    local n = 0
    for _, it in ipairs(items or {}) do if holds(c, it) then n = n + 1 end end
    return n
end

-- A square with a floor to stand on next to (x,y,z), free, not a stair, not in the excluded list.
local function standNear(x, y, z, skip)
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
        local sx, sy = x + d[1], y + d[2]
        local bad = false
        for _, e in ipairs(skip or {}) do if e[1] == sx and e[2] == sy then bad = true end end
        local sq = square(sx, sy, z)
        local okS, stairs = false, false
        if sq then okS, stairs = pcall(function() return sq:HasStairs() end) end
        if not bad and sq and sq:getFloor() and sq:isFree(false) and not (okS and stairs) then return sx, sy end
    end
    return nil
end

local function queueTransfer(r, it, from, to)
    local TG = TestGroundInternal
    local a
    if TG and TG.transferAction then a = TG.transferAction(r.p, it, from, to)
    else a = ISInventoryTransferAction:new(r.p, it, from, to) end
    ISTimedActionQueue.add(a)
end

-- The test items out of the player's inventory again (the step's end, a skip, an error, a stopped run).
function K.dropMarked(r, st)
    if not st or not st.marked then return end
    local inv = r.p:getInventory()
    for _, it in ipairs(st.marked) do pcall(function() inv:Remove(it) end) end
    st.marked = nil
    pcall(function() ISInventoryPage.dirtyUI() end)
end

-- behind the winch, facing it and the drop beyond; beside it if there's no floor behind
local function behindSpot(L)
    local spots = { { L.x - L.dx, L.y - L.dy }, { L.x + L.dy, L.y + L.dx }, { L.x - L.dy, L.y - L.dx } }
    for _, s in ipairs(spots) do
        local sq = square(s[1], s[2], L.z)
        if sq and sq:getFloor() and sq:isFree(false) then return s[1], s[2] end
    end
    return nil
end
local function standBehind(r, L)
    local TG = TestGroundInternal
    local x, y = behindSpot(L)
    if x then TG.teleport(r.p, x, y, L.z) end
    return x, y
end

local Step = {}
local Impl = {}

function Impl.begin(r, st)
    local T = TestGround
    if not CraneMod or not CraneMod.Build or not CraneMod.layout then st.skip = "Crane mod not loaded"; return end
    st.cycles = math.max(1, math.floor(st.a or 1))
    st.seconds = st.b or 90
    local x, y, z, letter
    local px = r.plan.extra and r.plan.extra["crane.winch"]
    if px and px[1] then
        x, y, z = string.match(px[1], "(%-?%d+)%s*,%s*(%-?%d+)%s*,%s*(%-?%d+)")
        x, y, z = tonumber(x), tonumber(y), tonumber(z)
        local f = r.plan.extra["crane.facing"]
        letter = f and f[1] and string.upper(string.sub(f[1], 1, 1)) or "W"
        if not x then st.skip = "crane.winch isn't x,y,z"; return end
        local ok, why = K.valid(x, y, z, letter)
        if not ok then st.skip = string.format("crane.winch %d,%d,%d %s: %s", x, y, z, letter, why); return end
        st.where = "crane.winch in the plan"
    else
        local why = "no build site in this run"
        if r.buildSite then
            x, y, z, letter = K.findSpot(r.buildSite)
            if x then st.where = "the run's build site"
            else why = string.format("no upper-floor edge on the build site at %d,%d passes the crane's placement check", r.buildSite.x, r.buildSite.y) end
        end
        local sc = r.plan.extra and r.plan.extra["crane.scan"]
        if not x and not (sc and sc[1] == "0") then
            local px, py = math.floor(r.p:getX()), math.floor(r.p:getY())
            local w0 = getTimestampMs()
            x, y, z, letter = K.scan(px, py, K.SCAN_RADIUS)
            T.trace(string.format("crane: %s; scanned %d tiles round %d,%d in %d ms: %s", why, K.SCAN_RADIUS, px, py, getTimestampMs() - w0, x and "found an edge" or "none"))
            if x then st.where = "a building near the player (" .. why .. ")" end
        end
        if not x then st.skip = why .. (sc and sc[1] == "0" and "" or string.format("; no upper-floor edge within %d tiles either", K.SCAN_RADIUS)); return end
    end
    -- from here on, whatever happens, the run's end takes the crane off again
    st.spot = { x, y, z, letter }
    r.cleanup = function() K.clearAround(x, y, z, letter); K.dropMarked(r, st) end
    local okB, L, why = pcall(K.build, x, y, z, letter)
    if not okB or not L then
        local n = K.clearAround(x, y, z, letter)
        r.cleanup = nil
        st.skip = "crane build failed: " .. tostring(okB and why or L) .. " (" .. n .. " placed objects taken off)"
        return
    end
    st.L = L
    st.loadN, st.loadW = K.fill(L)
    local itemsOff = r.plan.extra and r.plan.extra["crane.items"] and r.plan.extra["crane.items"][1] == "0"
    st.items = not itemsOff
    if st.items then
        local gx, gy = standNear(L.ax, L.ay, L.bz)
        if not gx then
            st.items = false
            T.trace("crane: no free square with a floor beside the box on the ground; the item check is left out")
        else
            st.gx, st.gy = gx, gy
            TestGroundInternal.teleport(r.p, gx, gy, L.bz)
            st.marked = {}
            local inv = r.p:getInventory()
            for _, id in ipairs(K.ITEMS) do
                local okA, it = pcall(function() return inv:AddItem(id) end)
                if okA and it then st.marked[#st.marked + 1] = it end
            end
            pcall(function() ISInventoryPage.dirtyUI() end)
        end
    end
    if st.items then st.sx, st.sy = behindSpot(L) else st.sx, st.sy = standBehind(r, L) end
    if not st.sx then
        local n = K.clearAround(x, y, z, letter)
        K.dropMarked(r, st)
        r.cleanup = nil
        st.skip = "no free square with a floor next to the winch to stand on (" .. n .. " crane objects taken off)"
        return
    end
    pcall(function() ISTimedActionQueue.clear(r.p) end)
    st.phase, st.at, st.cycle, st.log = "start", 0, 0, {}
    T.trace(string.format("crane: winch at %d,%d,%d facing %s (landing %d,%d, from %s), box at %d,%d,%d with %d items (%.1f weight); player at %d,%d",
        L.x, L.y, L.z, letter, L.lx, L.ly, st.where, L.ax, L.ay, L.bz, st.loadN, st.loadW, st.sx, st.sy))
end

local function crank(r, st, mode)
    local a = CraneCrankAction:new(r.p, st.L.winch, mode)
    ISTimedActionQueue.add(a)
    st.crankAt = getTimestampMs()
    st.want = mode == "raise" and "up" or "down"
end

-- The queue is empty (an action just finished) or the wait ran out.
local function actionsDone(r, st, t)
    local busy = false
    pcall(function() busy = ISTimedActionQueue.isPlayerDoingAction(r.p) end)
    return (not busy and t - st.wait0 >= 600) or t - st.wait0 > K.TRANSFER_TIMEOUT_MS
end

function Impl.tick(r, st, t)
    local T, C = TestGround, CraneMod
    local L = st.L
    local el = t - st.t0
    local function finish(why)
        pcall(function() ISTimedActionQueue.clear(r.p) end)
        local state = "?"
        pcall(function() state = C.state(L) end)
        local back = (state == "down" and L.box) and itemCount(L.box:getContainer()) or -1
        K.dropMarked(r, st)
        local n = K.clear(L)
        n = n + K.clearAround(st.spot[1], st.spot[2], st.spot[3], st.spot[4])
        r.cleanup = nil
        local itemsTxt = ""
        if st.items then
            itemsTxt = string.format("; items %s", st.itemLog and table.concat(st.itemLog, ", ") or "not reached")
        end
        st.result = string.format("crane facing %s at %d,%d,%d: %d of %d cycles (%s); cranked from floor %s (winch floor %d); box %s, %s of %d items back; per crank %s%s; %d crane objects taken off%s",
            C.faceLetter(L), L.x, L.y, L.z, st.cycle, st.cycles, table.concat(st.log, ", "), table.concat(st.crankFloors or {}, " "), L.z, state,
            back >= 0 and tostring(back) or "none", st.loadN, st.crankTimes or "none", itemsTxt, n, why and (" [" .. why .. "]") or "")
        T.trace("crane: " .. st.result)
        return true
    end
    if el >= st.seconds * 1000 then return finish("out of time") end

    -- stand upstairs, behind the winch: the player must stay on the winch's floor before a crank
    local function beginStand(where, x, y, next)
        st.stand = { x = x, y = y, z = L.z, next = next, tries = 0, at = t, where = where }
        TestGroundInternal.teleport(r.p, x, y, L.z)
        st.phase = "stand"
    end

    if st.phase == "start" then
        if el < K.START_MS then return false end
        if not st.items then beginStand("behind the winch", st.sx, st.sy, "raise"); return false end
        st.itemLog = {}
        local box = L.box:getContainer()
        local inv = r.p:getInventory()
        for _, it in ipairs(st.marked) do queueTransfer(r, it, inv, box) end
        st.wait0 = t
        st.phase = "store"
        return false
    end
    if st.phase == "store" then
        if not actionsDone(r, st, t) then return false end
        local stored = countHeld(L.box:getContainer(), st.marked)
        st.itemLog[#st.itemLog + 1] = string.format("stored %d of %d in the box", stored, #st.marked)
        T.note("crane", st.itemLog[#st.itemLog])
        beginStand("behind the winch", st.sx, st.sy, "raise")
        return false
    end
    if st.phase == "stand" then
        local sd = st.stand
        if onFloor(r.p, sd.z) then
            if t - sd.at >= K.STAND_MS then
                st.crankFloors = st.crankFloors or {}
                if sd.next == "raise" then crank(r, st, "raise"); st.phase = "crank"
                elseif sd.next == "lower" then crank(r, st, "lower"); st.phase = "crank"
                elseif sd.next == "retrieve" then
                    local lc = L.landing and L.landing:getContainer()
                    local inv = r.p:getInventory()
                    for _, it in ipairs(st.marked) do if holds(lc, it) then queueTransfer(r, it, lc, inv) end end
                    st.wait0 = t
                    st.phase = "retrieve"
                end
            end
            return false
        end
        -- fell, or the teleport didn't take: stand again, a few times
        if t - sd.at > 600 then
            sd.tries = sd.tries + 1
            if sd.tries > K.STAND_TRIES then return finish("the player could not stand on floor " .. sd.z .. " " .. sd.where) end
            sd.at = t
            TestGroundInternal.teleport(r.p, sd.x, sd.y, sd.z)
            T.trace(string.format("crane: the player was not on floor %d %s; teleported again (%d)", sd.z, sd.where, sd.tries))
        end
        return false
    end
    if st.phase == "retrieve" then
        if not actionsDone(r, st, t) then return false end
        local lc = L.landing and L.landing:getContainer()
        local inv = r.p:getInventory()
        local got = countHeld(inv, st.marked)
        st.itemLog[#st.itemLog + 1] = string.format("taken from the landing by the transfer action %d of %d, %d left on the landing", got, #st.marked, countHeld(lc, st.marked))
        T.note("crane", st.itemLog[#st.itemLog])
        st.retrieved = true
        st.phase, st.at = "up", t
        return false
    end
    if st.phase == "crank" then
        local state = C.state(L)
        -- 0.2.1 (review of 0.2.0): the floor is read all through the crank, not only before it; a fall
        -- stops the crank and the player is stood up again (K.STAND_TRIES falls at most)
        if state ~= st.want and not onFloor(r.p, L.z) then
            st.falls = (st.falls or 0) + 1
            pcall(function() ISTimedActionQueue.clear(r.p) end)
            T.trace(string.format("crane: the player left floor %d during a crank (fall %d)", L.z, st.falls))
            if st.falls > K.STAND_TRIES then return finish("the player kept falling off floor " .. L.z .. " during the crank") end
            beginStand("behind the winch", st.sx, st.sy, st.want == "up" and "raise" or "lower")
            return false
        end
        if state == st.want then
            local flr = 0
            pcall(function() flr = math.floor(r.p:getZ() + 0.05) end)
            st.crankFloors = st.crankFloors or {}
            st.crankFloors[#st.crankFloors + 1] = tostring(flr)
            local ms = getTimestampMs() - st.crankAt
            st.crankTimes = (st.crankTimes and (st.crankTimes .. " ") or "") .. string.format("%.1fs", ms / 1000)
            if state == "up" then
                st.log[#st.log + 1] = string.format("up %d items on the landing", itemCount(L.landing and L.landing:getContainer()))
                if st.items and not st.retrieved then
                    st.itemLog[#st.itemLog + 1] = string.format("%d of %d on the landing after the lift", countHeld(L.landing and L.landing:getContainer(), st.marked), #st.marked)
                    local lx, ly = standNear(L.lx, L.ly, L.z, { { L.x, L.y } })
                    if lx then
                        T.note("crane", st.log[#st.log])
                        beginStand("beside the landing", lx, ly, "retrieve")
                        return false
                    end
                    st.itemLog[#st.itemLog + 1] = "no free floor square beside the landing: retrieve left out"
                end
                st.phase, st.at = "up", t
            else
                st.cycle = st.cycle + 1
                st.log[#st.log + 1] = string.format("down %d items", itemCount(L.box and L.box:getContainer()))
                st.phase, st.at = "down", t
            end
            T.note("crane", st.log[#st.log])
            return false
        end
        if getTimestampMs() - st.crankAt > K.CRANK_TIMEOUT_MS then return finish("a crank didn't finish in " .. K.CRANK_TIMEOUT_MS / 1000 .. " s, state " .. tostring(state)) end
        -- the queue emptied without the state changing: the action was refused or interrupted
        local busy = false
        pcall(function() busy = ISTimedActionQueue.isPlayerDoingAction(r.p) end)
        if not busy and getTimestampMs() - st.crankAt > 1500 then
            st.retries = (st.retries or 0) + 1
            if st.retries > 2 then return finish("the crank action stopped without moving the box") end
            beginStand("behind the winch", st.sx, st.sy, st.want == "up" and "raise" or "lower")
        end
        return false
    end
    if st.phase == "up" then
        if t - st.at >= K.HOLD_UP_MS then
            -- back behind the winch for the lowering (the item check may have moved the player)
            beginStand("behind the winch", st.sx, st.sy, "lower")
        end
        return false
    end
    if st.phase == "down" then
        if t - st.at < K.HOLD_DOWN_MS then return false end
        if st.cycle >= st.cycles then return finish() end
        beginStand("behind the winch", st.sx, st.sy, "raise")
        return false
    end
    return finish("unknown phase " .. tostring(st.phase))
end

-- An error anywhere in the step takes the crane off at once and ends the step.
local function failed(r, st, err)
    local n = 0
    if st.spot then n = K.clearAround(st.spot[1], st.spot[2], st.spot[3], st.spot[4]) end
    pcall(K.dropMarked, r, st)
    r.cleanup = nil
    pcall(function() ISTimedActionQueue.clear(r.p) end)
    local msg = "crane step error: " .. tostring(err) .. " (" .. n .. " crane objects taken off)"
    say(msg)
    pcall(function() TestGround.trace("crane: " .. msg) end)
    return msg
end
function Step.begin(r, st)
    local ok, err = pcall(Impl.begin, r, st)
    if not ok then st.skip = failed(r, st, err) end
end
function Step.tick(r, st, t, dt)
    local ok, done = pcall(Impl.tick, r, st, t, dt)
    if ok then return done end
    st.result = failed(r, st, done)
    return true
end

CraneTestGround = K
K.Step = Step

local function register()
    if K.registered then return end
    if not TestGround or not TestGround.addStep or not CraneMod then
        say(K.VERSION .. " idle: " .. (TestGround and "" or "Test Ground ") .. (CraneMod and "" or "Crane ") .. "not loaded")
        return
    end
    K.registered = TestGround.addStep("crane", Step, "build")
    say(K.VERSION .. " active: step 'crane' added to Test Ground")
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(register) end
