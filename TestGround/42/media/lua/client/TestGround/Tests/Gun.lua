-- Test Ground 1.13.2: ranged fighting: the gun fight.
require "TestGround/Core"
require "TestGround/Tests/Melee"
local TG = TestGroundInternal
if TG.loaded.Gun then return end
TG.loaded.Gun = true
local K, Steps, T, floor, isDead = TG.K, TG.Steps, TG.T, TG.floor, TG.isDead
local near, now, removeZombies, teleport, try, zombiesList = TG.near, TG.now, TG.removeZombies, TG.teleport, TG.try, TG.zombiesList

-- gunfight N S: N zombies spawned in a ring K.GUN_RANGE tiles out (range=R to change it) come at
-- you; you stand and shoot them with the plan's gun (default K.GUN_WEAPON, a 9 mm pistol, loaded),
-- aiming and firing through the attack input like a player, in "can't die" mode. Ammo is topped up
-- by script when the gun runs dry (counted as reloads, so the reload animation isn't measured), a
-- jam is cleared the same way. At most K.GUN_CROWD at arm's length (the rest are put down). The
-- shots are loud: the world's own zombies are kept away by the usual sweep.
K.GUN_WEAPON = "Base.Pistol"
K.GUN_RANGE = 15
K.GUN_CROWD = 1
K.GUN_GROUP = "ranged"
-- 1.13.10 (1.13.2's gunfight: 2 hits in 101 shots, none past a tile). In build 42 a shot goes where
-- the reticle is (BallisticsController reads the mouse; the target must be within 2.75 tiles of it
-- or of the muzzle line), not where the player faces, and accuracy drops with the aiming delay,
-- which only falls while aiming and climbs with each shot. So: the mouse is put on the target's
-- chest every tick, and a shot waits until the aiming delay is down (or K.GUN_AIM_WAIT_MS passed).
K.GUN_AIM_DELAY_OK = 1      -- fire once getAimingDelay() is at or below this
K.GUN_AIM_WAIT_MS = 2000    -- or after this long since the aim was last put on a target or a shot left (1.13.42: was counted from the lock)
K.GUN_CHEST_Z = 0.5         -- the mouse goes this far above the zombie's feet
-- Puts the mouse on the zombie; returns true when the game took it (the mouse reads back near it).
function K.gunAtan2(y, x)
	if math.atan2 then return math.atan2(y, x) end
	if x > 0 then return math.atan(y / x) end
	if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
	return y > 0 and math.pi / 2 or (y < 0 and -math.pi / 2 or 0)
end
-- 1.13.38: the game aims a ranged weapon at the real mouse (AimingReticle, read from the game's jar), and setMouseXY does
-- not move it while the window is unfocused. Test Ground Capture 1.0.8 patches the reticle: TGCapture.aimAt(player, x, y)
-- gives it a point in the game's mouse pixels (isoToScreenX at the aim origin's height, which is
-- what XToIso inverts; the game's own function already divides by the zoom). Returns true when the point was handed over; false when Capture is missing or older.
function K.gunJavaAim(p, z)
	local ok, res = pcall(function()
		if not (TGCapture and TGCapture.aimAt) then return false end
		local pn = p:getPlayerNum()
		local z0 = p:getAimOriginPosZ()
		-- 1.13.39: isoToScreenX/Y already divide by the camera's zoom and add the viewport's left/top (read from the game's
		-- bytecode after the 1.13.38 run: dividing again put the point at half the distance from the screen's corner, 70 deg off)
		local sx = isoToScreenX(pn, z:getX(), z:getY(), z0)
		local sy = isoToScreenY(pn, z:getX(), z:getY(), z0)
		TGCapture.aimAt(pn, floor(sx), floor(sy))
		return floor(sx) .. "," .. floor(sy)
	end)
	if ok and res then return true, res end
	return false
end
-- 1.13.42: the same, for a point in the world at an absolute height (the aim sweep's ladder), not at the aim origin's.
function K.gunJavaAimAt(p, x, y, zAbs)
	local ok, res = pcall(function()
		if not (TGCapture and TGCapture.aimAt) then return false end
		local pn = p:getPlayerNum()
		local sx, sy = isoToScreenX(pn, x, y, zAbs), isoToScreenY(pn, x, y, zAbs)
		TGCapture.aimAt(pn, floor(sx), floor(sy))
		return floor(sx) .. "," .. floor(sy)
	end)
	if ok and res then return true, res end
	return false
end
function K.gunJavaClear()
	pcall(function() if TGCapture and TGCapture.aimClear then TGCapture.aimClear() end end)
end
-- 1.13.39 (the user: a gun can't be fired with a zombie too close): a standing zombie nearer than the weapon's minimum range
-- plus a tile is put back to a tile and a half beyond it, along the line from the character. Returns how many were moved.
function K.gunKeepAway(p, list, minR, seen)
	local px, py = p:getX(), p:getY()
	local keep, n, closest = minR + 1, 0, nil
	for _, z in ipairs(list) do
		if not isDead(z) then
			local dx, dy = z:getX() - px, z:getY() - py
			local d = math.sqrt(dx * dx + dy * dy)
			if not closest or d < closest then closest = d end
			if d < keep then
				if d < 0.05 then dx, dy, d = 1, 0, 1 end
				local nx, ny = px + dx / d * (minR + 1.5), py + dy / d * (minR + 1.5)
				-- 1.13.40: setLx/setNx and the like don't exist in B42 (review of 1.13.39); only the position is set
				local ok = pcall(function() z:setX(nx); z:setY(ny) end)
				if ok then
					n = n + 1
					if seen then seen[z] = true end
				end
			end
		end
	end
	return n, closest
end
function K.gunMouseOn(p, z)
	local ok, hit, mx, my = pcall(function()
		local pn = p:getPlayerNum()
		local zz = (z.getZ and z:getZ() or p:getZ()) + K.GUN_CHEST_Z
		local x = isoToScreenX(pn, z:getX(), z:getY(), zz)
		local y = isoToScreenY(pn, z:getX(), z:getY(), zz)
		setMouseXY(floor(x), floor(y))
		return math.abs(getMouseX() - floor(x)) <= 2 and math.abs(getMouseY() - floor(y)) <= 2, floor(x), floor(y)
	end)
	return ok and hit, (not ok) and tostring(hit) or nil, ok and mx or nil, ok and my or nil
end
K.GROUPS[K.GUN_GROUP] = K.GROUPS[K.GUN_GROUP] or {}
table.insert(K.GROUPS[K.GUN_GROUP], "gunfight")

local function gunOpts(st)
	local o = K.stepOpts(st)
	for w in string.gmatch(st.text or "", "%S+") do
		local k, v = string.match(w, "^([%w_]+)=(%S+)$")
		if k and string.lower(k) == "range" and tonumber(v) then o.range = math.max(3, tonumber(v)) end
	end
	-- stepOpts reads any Perk=number pair as a skill; range isn't one
	local skills = {}
	for _, sk in ipairs(o.skills) do if string.lower(sk.name) ~= "range" then skills[#skills + 1] = sk end end
	-- 1.13.36 PC run: 4 hits of 70 shots, mean damage 0.72; a character with no Aiming skill misses most shots at range, which says
	-- nothing about the game's performance, so the step runs at Aiming 6 unless the plan names a level
	local named = false
	for _, sk in ipairs(skills) do if string.lower(sk.name) == "aiming" then named = true end end
	if not named then skills[#skills + 1] = { name = "Aiming", level = 6 } end
	o.skills = skills
	return o
end

-- Full magazine, round chambered, not jammed. Returns true when anything had to be done.
-- 1.13.33: returns true when anything had to be done, and a second value: "ammo" for a refilled magazine (a
-- real reload), "reseat" for a clip or chamber round put back (not a reload)
function K.gunLoad(w)
	local did, kind = false, nil
	pcall(function()
		local max = w:getMaxAmmo()
		if max and max > 0 and w:getCurrentAmmoCount() <= 0 then
			w:setCurrentAmmoCount(max)
			did, kind = true, "ammo"
		end
		if w.setContainsClip and w.isContainsClip and not w:isContainsClip() then w:setContainsClip(true); did, kind = true, kind or "reseat" end
		if w.haveChamber and w:haveChamber() and not w:isRoundChambered() then w:setRoundChambered(true); did, kind = true, kind or "reseat" end
	end)
	return did, kind
end

-- 1.13.33 (68 shots of 183 tries on the PC): why a trigger pull did not fire. Read at the pull, judged 700 ms later
-- when no OnWeaponSwing came: no round, no chambered round, not aiming, or something else.
function K.gunTry(p, w, st)
	local c = { t = now() }
	pcall(function() c.ammo = w:getCurrentAmmoCount() end)
	pcall(function() c.chamber = (not w.haveChamber) or (not w:haveChamber()) or w:isRoundChambered() end)
	pcall(function() c.aiming = p:isAiming() end)
	c.off = st.animErr or st.angleErr
	c.near = st.rawNearest or st.nearest
	c.rec = nil
	pcall(function() c.rec, c.md, c.ad, c.rdy = p:getRecoilDelay(), p:getMeleeDelay(), p:getAimingDelay(), p:isWeaponReady() end)
	st.tries = st.tries or {}
	st.tries[#st.tries + 1] = c
end
-- 1.13.35 (review of 1.13.34: one pending try, overwritten every 220 ms, so nothing was ever judged): every try is
-- queued. A try is fired when an OnWeaponSwing came within 700 ms of it that no earlier try used; when the step ends,
-- tries younger than 700 ms are judged on what has come so far.
function K.gunJudge(st, final)
	local q = st.tries
	if not q or #q == 0 then return end
	st.unfired = st.unfired or { empty = 0, nochamber = 0, notaiming = 0, offangle = 0, other = 0, tooclose = 0 }
	local swings = st.swingLog or {}
	local keep = {}
	for _, c in ipairs(q) do
		local fired = false
		for i, ts in ipairs(swings) do
			if ts >= c.t and ts <= c.t + 700 and not swings.used[i] then swings.used[i] = true; fired = true; break end
		end
		if fired then
			st.firedTries = (st.firedTries or 0) + 1
		elseif final or now() - c.t >= 700 then
			local why = ((c.near and st.minRange and st.minRange > 0 and c.near < st.minRange) and "tooclose") or (c.ammo and c.ammo <= 0 and "empty") or (c.chamber == false and "nochamber") or (c.aiming == false and "notaiming") or (c.off and c.off > 25 and "offangle") or "other"
			st.unfired[why] = st.unfired[why] + 1
			if why == "other" then
				st.otherN = (st.otherN or 0) + 1
				if st.otherN <= 6 then
					T.trace(string.format("gunfight: try %d did not fire: recoil %s, melee delay %s, aiming delay %s, weapon ready %s, ammo %s, facing %s deg off", st.otherN,
						tostring(c.rec), tostring(c.md), tostring(c.ad), tostring(c.rdy), tostring(c.ammo), c.off and string.format("%.0f", c.off) or "?"))
				end
			end
		else
			keep[#keep + 1] = c
		end
	end
	st.tries = keep
end
-- 1.13.42 (1.13.41: 5 and 7 zombies added where 15 to 35 were expected; shot zombies kept counting as alive, killed + standing
-- came to more than spawned): a zombie that can still be shot at is not dead, has health above 0 and is not on the floor.
function K.gunStanding(z)
	if isDead(z) or K.zProne(z) then return false end
	local ok, h = pcall(function() return z:getHealth() end)
	if ok and tonumber(h) and tonumber(h) <= 0 then return false end
	return true
end
function K.gunStandingOf(list)
	local n = 0
	for _, z in ipairs(list or {}) do if K.gunStanding(z) then n = n + 1 end end
	return n
end
function K.gunUnjam(w)
	local ok, jam = pcall(function() return w:isJammed() end)
	if ok and jam then pcall(function() w:setJammed(false) end); return true end
	return false
end

local function spawnRing(c, count, radius, phase)
	if TG.S.run then TG.S.run.spawnedZombies = true end
	for i = 1, count do
		local angle = (i / count) * 2 * math.pi + (phase or 0)
		local x = floor(c.x + math.cos(angle) * radius)
		local y = floor(c.y + math.sin(angle) * radius)
		try("spawn zombie", function()
			addZombiesInOutfit(x, y, c.z, 1, nil, 50, false, false, false, false, false, false, 1, false, 0, false, false)
		end)
	end
end

function K.gunHook(r, st)
	st.ghooks = {}
	local p = r.p
	local function add(name, fn)
		if Events[name] and Events[name].Add then Events[name].Add(fn); st.ghooks[name] = fn end
	end
	add("OnWeaponSwing", function(c)
		if c ~= p then return end
		st.shots = st.shots + 1
		st.swungAt = now()
		local bm = st.byMode and st.byMode[st.mode or "?"]
		if bm then bm.shots = bm.shots + 1 end
		local sb = st.settleBuckets and st.settleBuckets[st.fireSettled and "settled" or "unsettled"]
		if sb then sb.shots = sb.shots + 1; st.hitBucket = sb end
		if st.swingLog then st.swingLog[#st.swingLog + 1] = st.swungAt end
	end)
	add("OnWeaponHitCharacter", function(w, target, weapon, dmg)
		if w ~= p then return end
		st.hits = st.hits + 1
		local bm = st.byMode and st.byMode[st.mode or "?"]
		if bm then bm.hits = bm.hits + 1 end
		if st.hitBucket then st.hitBucket.hits = st.hitBucket.hits + 1 end
		-- 1.13.39: which body part the game says it hit (IsoGameCharacter.getLastHitPart, read right in the hit event)
		local okP, part = pcall(function() return target:getLastHitPart() end)
		part = (okP and part and part ~= "") and tostring(part) or "?"
		st.parts = st.parts or {}
		st.parts[part] = (st.parts[part] or 0) + 1
		st.dmg = st.dmg + (tonumber(dmg) or 0)
		pcall(function()
			local d = math.sqrt((target:getX() - p:getX()) ^ 2 + (target:getY() - p:getY()) ^ 2)
			st.hitDist = st.hitDist + d
			if d > st.farHit then st.farHit = d end
		end)
	end)
end
function K.gunUnhook(st)
	for name, fn in pairs(st.ghooks or {}) do pcall(function() Events[name].Remove(fn) end) end
	st.ghooks = {}
end

Steps.gunfight = {
	begin = function(r, st)
		st.count = math.max(1, floor(st.a or 8))
		st.seconds = st.b or 40
		local o = gunOpts(st)
		local txt = " " .. (st.text or "") .. " "
		-- 1.13.36: the PC showed setMouseXY not taking (read back 172 px off on every tick), so by default the first half
		-- of the step aims with the mouse and the second half only faces the zombie, each counted on its own
		st.aim = string.find(txt, " aim=face ", 1, true) and "face" or string.find(txt, " aim=mouse ", 1, true) and "mouse" or string.find(txt, " aim=java ", 1, true) and "java" or string.find(txt, " aim=dir ", 1, true) and "dir" or string.find(txt, " aim=ab ", 1, true) and "ab" or "java"
		-- 1.13.37: the mouse never moved (setMouseXY does not take), so "ab" is now: first half faces the zombie, second half
		-- also sets the forward direction by hand; "mouse" is kept for a plan that asks for it
		st.byMode = {}
		st.range = o.range or K.GUN_RANGE
		r.holdSweep = true
		removeZombies()
		pcall(function() r.p:setGhostMode(false) end)
		local home = r.plan.start
		if home and not near(r.p, home, 3) then teleport(r.p, home.x, home.y, home.z) end
		local c = { x = floor(r.p:getX()), y = floor(r.p:getY()), z = floor(r.p:getZ()) }
		st.c = c
		spawnRing(c, st.count, st.range)
		r.fightAt, r.fightRadius = c, st.range + 10
		st.mine = {}
		st.known = {}
		for _, z in ipairs(zombiesList()) do st.mine[#st.mine + 1] = z; st.known[z] = true end
		st.spawned = #st.mine
		-- 1.13.41 (the user's choice after 1.13.40: 8 zombies died in 11 to 18 s and the other 22 s had nothing to shoot): while the
		-- step runs, the ring is topped up to the zombie count about once a second, so every run shoots for the whole time
		-- ("refill=0" in the step turns it off)
		st.refill = not string.find(txt, " refill=0 ", 1, true)
		st.refilled, st.nextRefill = 0, 2000
		st.swingLog = { used = {} }
		st.settleBuckets = { settled = { shots = 0, hits = 0 }, unsettled = { shots = 0, hits = 0 } }
		st.shots, st.hits, st.dmg, st.hitDist, st.farHit, st.reloads, st.unjams, st.attempts = 0, 0, 0, 0, 0, 0, 0, 0
		st.heals, st.nextLure = 0, 500
		st.mouseSet, st.mouseMiss, st.delaySum, st.delayN, st.waitedOut = 0, 0, 0, 0, 0
		pcall(function() st.mouse0 = { getMouseX(), getMouseY() } end)   -- 1.13.11: put back at the end
		st.weapon = K.armWeapon(r, st, o.weapon or K.GUN_WEAPON)
		st.skillSet = K.setSkills(r, o.skills)
		local w = r.weaponItem
		st.ranged = false
		if w then pcall(function() st.ranged = w:isRanged() == true end) end
		if w and st.ranged then K.gunLoad(w) end
		pcall(function() st.maxRange = w and w:getMaxRange(r.p) end)
		-- the weapon's minimum range: the ranged one when it has one, else the general one
		st.minRange = 0
		pcall(function()
			local a, b = w:getMinRangeRanged(), w:getMinRange()
			st.minRange = math.max(tonumber(a) or 0, tonumber(b) or 0)
		end)
		st.pushed = 0
		st.maxRange = tonumber(st.maxRange) or st.range
		pcall(function() st.weapon = st.weapon .. " (" .. tostring(w:getDisplayName()) .. ")" end)
		st.hits0 = r.hitsTaken or 0
		local okK, k0 = K.tryOnce("zombie kills", function() return r.p:getZombieKills() end)
		st.kills0 = okK and k0 or nil
		K.gunHook(r, st)
		-- 1.13.33: a stop in the middle of the fight leaves no counting hooks and puts the mouse back
		if not r.cleanup then
			st.ownCleanup = true
			r.cleanup = function()
				K.gunUnhook(st)
				pcall(function() K.releaseAim(r.p) end)
				K.gunJavaClear()
				if st.mouse0 and st.mouseTried then pcall(setMouseXY, st.mouse0[1], st.mouse0[2]) end
			end
		end
		if not st.ranged then T.trace("gunfight: " .. tostring(st.weapon) .. " isn't a ranged weapon; it is swung like a melee one") end
	end,
	tick = function(r, st, t)
		local el = t - st.t0
		local p = r.p
		TG.cantDie(r, st)
		st.thinned = (st.thinned or 0) + K.crowdCap(p, K.GUN_CROWD)
		if not st.clearedAt and el > 1000 and K.aliveOf(st.mine) == 0 then st.clearedAt = el end
		K.holdAim(p, st)
		if el >= st.nextLure then
			st.nextLure = el + TG.FIGHT_LURE_MS
			TG.lure(p, zombiesList())
		end
		local w = r.weaponItem
		if w and st.ranged then
			local did, kind = K.gunLoad(w)
			if did then
				if kind == "ammo" then st.reloads = st.reloads + 1 else st.reseats = (st.reseats or 0) + 1 end
			end
			K.gunJudge(st)
			if K.gunUnjam(w) then st.unjams = st.unjams + 1 end
		end
		-- 1.13.41: zombies that appeared since the last tick (the refill's) join the step's own; the ring is topped up once a second
		for _, z in ipairs(zombiesList()) do
			if not st.known[z] then st.known[z] = true; st.mine[#st.mine + 1] = z; st.spawned = st.spawned + 1 end
		end
		if st.refill and el >= st.nextRefill and el < st.seconds * 1000 - 3000 then
			st.nextRefill = el + 1000
			local alive = K.gunStandingOf(st.mine)
			-- 1.13.42: zombies on the floor still count towards a cap of twice the ring, so a knocked-down crowd is not doubled
			local live = K.aliveOf(st.mine)
			local add = math.min(st.count - alive, math.max(0, st.count * 2 - live))
			if add > 0 then
				spawnRing(st.c, add, st.range, ZombRand(628) / 100)
				st.refilled = st.refilled + add
			end
			if el >= 10000 then
				st.aliveN, st.aliveSum = (st.aliveN or 0) + 1, (st.aliveSum or 0) + alive
				st.aliveMin = math.min(st.aliveMin or 99, alive)
				st.aliveMax = math.max(st.aliveMax or 0, alive)
			end
		end
		-- 1.13.39: keep the zombies out of the weapon's minimum range
		if st.ranged and (st.minRange or 0) > 0 then
			st.pushedSet = st.pushedSet or {}
			local moved, closest = K.gunKeepAway(p, zombiesList(), st.minRange, st.pushedSet)
			st.pushed = st.pushed + moved
			-- the closest zombie before the push, for "a zombie inside the minimum range" (1.13.39 judged it after the push)
			st.rawNearest = closest
			if closest and closest < st.minRange then st.closeTicks = (st.closeTicks or 0) + 1 end
		end
		-- the nearest standing zombie in range: face it and fire when the gun is ready
		local px, py = p:getX(), p:getY()
		local best, bd = nil, 1e9
		for _, z in ipairs(zombiesList()) do
			if not isDead(z) and not K.zProne(z) then
				local d = math.sqrt((z:getX() - px) ^ 2 + (z:getY() - py) ^ 2)
				if d < bd then best, bd = z, d end
			end
		end
		-- 1.13.40: stay on one zombie until it dies, goes prone or leaves the weapon's range, so the aim point doesn't jump between
		-- the zombies of the ring (the 1.13.39 animation was 0 to 1 deg off once locked, 70 to 130 deg off after a switch)
		local lk = st.target
		if lk and not isDead(lk) and not K.zProne(lk) then
			local d = math.sqrt((lk:getX() - px) ^ 2 + (lk:getY() - py) ^ 2)
			if d <= st.maxRange then best, bd = lk, d end
		end
		if best ~= st.target then
			-- 1.13.41: the first lock and losing the target are not switches (review of 1.13.40), nor do they start the "first second" bucket
			if st.target and best then
				st.switches = (st.switches or 0) + 1
				st.switchAt = t
			end
			st.target = best
		end
		st.nearest = best and bd or nil
		if best and bd <= st.maxRange then
			K.tryOnce("face zombie", function() p:faceThisObject(best) end)
			local mode = st.aim
			if mode == "ab" then
				-- first half: the character only faces the zombie; second half: the aim point goes to the game's reticle through
				-- Capture 1.0.8, or by hand in the forward direction when Capture is older or missing
				local haveJava = TGCapture and TGCapture.aimAt and true or false
				mode = el < st.seconds * 500 and "face" or (haveJava and "java" or "dir")
			end
			if mode == "java" then
				local okJ, pt = K.gunJavaAim(p, best)
				if okJ then
					st.javaSets = (st.javaSets or 0) + 1
					st.javaPoint = pt
				else
					st.javaFails = (st.javaFails or 0) + 1
					mode = "dir"
				end
			end
			st.mode = mode
			st.byMode[mode] = st.byMode[mode] or { ticks = 0, tries = 0, shots = 0, hits = 0, errN = 0, errSum = 0, near = 0 }
			local bm = st.byMode[mode]
			bm.ticks = bm.ticks + 1
			if mode == "dir" then
				K.gunJavaClear()
				pcall(function()
					local dx, dy = best:getX() - px, best:getY() - py
					local l = math.sqrt(dx * dx + dy * dy)
					if l > 0 then p:setForwardDirection(dx / l, dy / l) end
				end)
			end
			-- how far the character's facing is from the zombie, in degrees
			st.angleErr = nil
			pcall(function()
				local f = p:getForwardDirection()
				local a1 = K.gunAtan2(f:getY(), f:getX())
				local a2 = K.gunAtan2(best:getY() - py, best:getX() - px)
				local d = math.abs(a1 - a2) * 180 / math.pi
				if d > 180 then d = 360 - d end
				st.angleErr = d
				bm.errN, bm.errSum = bm.errN + 1, bm.errSum + d
				if d <= 25 then bm.near = bm.near + 1 end
			end)
			-- facing as the animation has it (the forward direction above is what faceThisObject just set, so it is always 0)
			st.animErr = nil
			pcall(function()
				local a1 = p:getAnimAngleRadians()
				local a2 = K.gunAtan2(best:getY() - py, best:getX() - px)
				local d = math.abs(a1 - a2) * 180 / math.pi % 360
				if d > 180 then d = 360 - d end
				st.animErr = d
				bm.animN, bm.animSum = (bm.animN or 0) + 1, (bm.animSum or 0) + d
				if d <= 25 then bm.animNear = (bm.animNear or 0) + 1 end
				bm.hist = bm.hist or { 0, 0, 0, 0, 0 }
				local hb = (d <= 5 and 1) or (d <= 25 and 2) or (d <= 60 and 3) or (d <= 120 and 4) or 5
				bm.hist[hb] = bm.hist[hb] + 1
				-- error in the first second after the aim moved to another zombie, and later
				local key = (t - (st.switchAt or t) < 1000) and "sw" or "st"
				bm[key .. "N"], bm[key .. "Near"] = (bm[key .. "N"] or 0) + 1, (bm[key .. "Near"] or 0) + (d <= 25 and 1 or 0)
				bm.t0, bm.t1 = bm.t0 or t, t
			end)
			if mode == "mouse" then
				-- 1.13.35: the read-back right after setMouseXY is the old position (the game updates the mouse once a
				-- frame), so "off it" in 1.13.34 may have been a false negative; the previous tick's target is read now
				if st.mouseTarget then
					local okM, dx, dy = pcall(function() return math.abs(getMouseX() - st.mouseTarget[1]), math.abs(getMouseY() - st.mouseTarget[2]) end)
					if okM then
						st.mouseNext = (st.mouseNext or 0) + 1
						local e = math.max(dx, dy)
						st.mouseErrSum = (st.mouseErrSum or 0) + e
						if e <= 3 then st.mouseLanded = (st.mouseLanded or 0) + 1 end
					end
				end
				local on, err, mx, my = K.gunMouseOn(p, best)
				st.mouseTried = true
				-- 1.13.36: once a second, the numbers behind the transform (target, where the mouse reads, screen, zoom, facing)
				if not st.lastDiag or t - st.lastDiag >= 1000 then
					st.lastDiag = t
					st.diagN = (st.diagN or 0) + 1
					if st.diagN <= 12 then
						local sw, sh, zm, ui = "?", "?", "?", "?"
						pcall(function() sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight() end)
						pcall(function() zm = string.format("%.2f", getCore():getZoom(p:getPlayerNum())) end)
						pcall(function() ui = string.format("%.2f", getCore().getOptionUIScale and getCore():getOptionUIScale() or 1) end)
						local gx, gy = "?", "?"
						pcall(function() gx, gy = getMouseX(), getMouseY() end)
						T.trace(string.format("gunfight aim: target on screen %s,%s; mouse reads %s,%s; screen %sx%s, zoom %s, ui scale %s; facing %.0f deg off the zombie",
							tostring(mx), tostring(my), tostring(gx), tostring(gy), tostring(sw), tostring(sh), zm, ui, st.angleErr or -1))
					end
				end
				st.mouseTarget = mx and { mx, my } or nil
				if on then st.mouseSet = st.mouseSet + 1 else
					st.mouseMiss = st.mouseMiss + 1
					if err and not st.mouseErr then st.mouseErr = err; T.trace("gunfight: can't move the mouse onto the target: " .. err) end
				end
			end
			if mode ~= "mouse" and (not st.lastDiag2 or t - st.lastDiag2 >= 1000) then
				st.lastDiag2 = t
				st.diag2 = st.diag2 or {}
				st.diag2[mode] = (st.diag2[mode] or 0) + 1
				if st.diag2[mode] <= 8 then
					local function g(f) local ok, v = pcall(f); return ok and v ~= nil and tostring(v) or "?" end
					T.trace(string.format("gunfight aim (%s): %.1f tiles away; facing %s deg off (forward direction), %s deg off (animation); aiming delay %s; recoil %s; hit chance %s; Aiming %s; aiming %s; Capture point %s",
						mode, bd, st.angleErr and string.format("%.0f", st.angleErr) or "?", st.animErr and string.format("%.0f", st.animErr) or "?",
						g(function() return p:getAimingDelay() end), g(function() return p:getRecoilDelay() end),
						g(function() return w:getHitChance() end), g(function() return p:getPerkLevel(K.perk("Aiming")) end), g(function() return p:isAiming() end),
						st.javaPoint and (tostring(st.javaPoint) .. "") or "-"))
				end
			end
			if best ~= st.aimAt then st.aimAt, st.aimSince = best, t end
			local okD, delay = pcall(function() return p:getAimingDelay() end)
			delay = okD and tonumber(delay) or nil
			local steady = (not st.ranged) or delay == nil or delay <= K.GUN_AIM_DELAY_OK or t - st.aimSince >= K.GUN_AIM_WAIT_MS
			if steady and K.readyToSwing(p, st) then
				st.fireSettled = (delay == nil) or delay <= K.GUN_AIM_DELAY_OK
				if delay then st.delaySum, st.delayN = st.delaySum + delay, st.delayN + 1 end
				if delay and delay > K.GUN_AIM_DELAY_OK then st.waitedOut = st.waitedOut + 1 end
				if w and st.ranged then K.gunTry(p, w, st); bm.tries = bm.tries + 1 end
				local ok, err = K.swing(p, st)
				if ok then st.attempts = st.attempts + 1; st.aimSince = t   -- 1.13.42: the wait for the next shot starts here
				elseif not st.fireFails then
					st.fireFails = tostring(err)
					T.trace("gunfight: the attack input fails: " .. st.fireFails)
				end
			end
		end
		if el >= st.seconds * 1000 then
			K.releaseAim(p)
			K.gunJavaClear()
			if st.mouse0 and st.mouseTried then pcall(setMouseXY, st.mouse0[1], st.mouse0[2]) end
			K.gunUnhook(st)
			if st.ownCleanup then r.cleanup = nil end
			K.gunJudge(st, true)
			local up = K.gunStandingOf(st.mine)
			removeZombies()
			TG.removeCorpses(st.c, st.range + 10)
			r.fightAt, r.fightRadius = nil, nil
			r.holdSweep = false
			TG.keepAlive(p)
			local kills = "?"
			if st.kills0 then
				local okK, k1 = K.tryOnce("zombie kills", function() return p:getZombieKills() end)
				if okK then kills = tostring(k1 - st.kills0) end
			end
			st.result = string.format("%d spawned %d tiles out, %s, %d shots fired of %d tries (OnWeaponSwing), %d hits (%.0f%%, mean damage %s, mean distance %s, farthest %.1f tiles), %s killed by you, %d put down by script at arm's length (at most %d), %d still standing (removed); %d reloads and %d jams cleared by script; %s; %s; hits taken %d%s",
				st.spawned, st.range, st.weapon, st.shots, st.attempts, st.hits, st.shots > 0 and 100 * st.hits / st.shots or 0,
				st.hits > 0 and string.format("%.2f", st.dmg / st.hits) or "-", st.hits > 0 and string.format("%.1f tiles", st.hitDist / st.hits) or "-", st.farHit,
				kills, st.thinned or 0, K.GUN_CROWD, up, st.reloads, st.unjams,
				st.clearedAt and string.format("cleared in %.1f s", st.clearedAt / 1000) or "not cleared",
				st.guarding and string.format("can't-die mode gave way (%s)", st.guarding) or string.format("can't-die mode held (%d heals)", st.heals or 0),
				(r.hitsTaken or 0) - (st.hits0 or 0),
				(#st.skillSet > 0 and ("; skills " .. table.concat(st.skillSet, " ")) or "") ..
				(st.fireFails and ("; ATTACK INPUT FAILED: " .. st.fireFails) or "") ..
				(function()
					local u = st.unfired
					if not u then return "" end
					return string.format("; %d tries did not fire (%d empty, %d no chambered round, %d not aiming, %d facing more than 25 deg off, %d other, %d with a zombie inside the weapon's minimum range; %d fired; %d clip or chamber re-seats are not counted as reloads)",
						u.empty + u.nochamber + u.notaiming + u.offangle + u.other + u.tooclose, u.empty, u.nochamber, u.notaiming, u.offangle, u.other, u.tooclose, st.firedTries or 0, st.reseats or 0)
				end)() ..
				(st.mouseNext and string.format("; mouse read back a frame later: on the previous target %d of %d ticks, mean error %.0f px",
					st.mouseLanded or 0, st.mouseNext, (st.mouseErrSum or 0) / st.mouseNext) or "") ..
				(function()
					local parts = {}
					for _, m in ipairs({ "mouse", "face", "dir", "java" }) do
						local b = st.byMode and st.byMode[m]
						if b then
							local hh = b.hist or { 0, 0, 0, 0, 0 }
							local spread = string.format("; animation error spread (to 5 deg %d, to 25 %d, to 60 %d, to 120 %d, over %d); first second after a switch %d ticks, %d%% within 25 deg, later %d ticks, %d%% within 25 deg; %.0f s in this mode",
								hh[1], hh[2], hh[3], hh[4], hh[5], b.swN or 0, (b.swN or 0) > 0 and floor(100 * (b.swNear or 0) / b.swN) or 0,
								b.stN or 0, (b.stN or 0) > 0 and floor(100 * (b.stNear or 0) / b.stN) or 0, b.t0 and (b.t1 - b.t0) / 1000 or 0)
							parts[#parts + 1] = string.format("%s: %d ticks, %d tries, %d shots, %d hits, facing %s deg off on average and within 25 deg on %d%%, animation %s deg off and within 25 deg on %d%%",
								m, b.ticks, b.tries, b.shots, b.hits, b.errN > 0 and string.format("%.0f", b.errSum / b.errN) or "?", b.errN > 0 and floor(100 * b.near / b.errN) or 0,
								(b.animN or 0) > 0 and string.format("%.0f", b.animSum / b.animN) or "?", (b.animN or 0) > 0 and floor(100 * (b.animNear or 0) / b.animN) or 0) .. spread
						end
					end
					return #parts > 0 and ("; by aim mode (" .. table.concat(parts, "; ") .. ")") or ""
				end)() ..
				(function()
					if not st.javaSets and not st.javaFails then return "" end
					local ok, s2 = pcall(function() return TGCapture.aimStatus() end)
					return string.format("; Capture aim point set %d times%s (%s)", st.javaSets or 0, st.javaFails and (", " .. st.javaFails .. " failed") or "", ok and tostring(s2) or "no aimStatus")
				end)() ..
				(function()
					if not st.parts then return "" end
					local names = {}
					for k in pairs(st.parts) do names[#names + 1] = k end
					table.sort(names)
					local out = {}
					for _, k in ipairs(names) do out[#out + 1] = k .. " " .. st.parts[k] end
					return "; hits by body part (" .. table.concat(out, ", ") .. ")"
				end)() ..
				(function()
					local n = 0
					for _ in pairs(st.pushedSet or {}) do n = n + 1 end
					return string.format("; minimum range %.2f tiles, %d moves out of it on %d zombies, a zombie inside it before the move on %d ticks; %d target switches (a switch is from one zombie to another); %s", st.minRange or 0, st.pushed or 0, n, st.closeTicks or 0, st.switches or 0,
						st.refill and string.format("ring topped up to %d about once a second: %d zombies added", st.count, st.refilled or 0) or "no top-up (refill=0)")
				end)() ..
				string.format("; aim by %s%s, aiming delay at the trigger %s%s", st.aim,
					st.aim == "mouse" and string.format(" (mouse on the target %d ticks, %s %d)", st.mouseSet, st.mouseErr and ("FAILED: " .. st.mouseErr .. ",") or "off it", st.mouseMiss) or "",
					st.delayN > 0 and string.format("%.1f mean", st.delaySum / st.delayN) or "not read",
					st.waitedOut > 0 and string.format(", %d shots fired after %.1f s without it settling", st.waitedOut, K.GUN_AIM_WAIT_MS / 1000) or "") ..
				(function()
					local b = st.settleBuckets
					if not b then return "" end
					local function pc(x) return x.shots > 0 and string.format("%.0f%%", 100 * x.hits / x.shots) or "-" end
					return string.format("; shots fired with the aim settled: %d, %d hits (%s); fired before it settled: %d, %d hits (%s)", b.settled.shots, b.settled.hits, pc(b.settled), b.unsettled.shots, b.unsettled.hits, pc(b.unsettled))
				end)() ..
				(st.aliveN and string.format("; standing and alive after 10 s (counted once a second): %d to %d, mean %.1f", st.aliveMin, st.aliveMax, st.aliveSum / st.aliveN) or "") ..
				(st.ranged and "" or "; NOT A RANGED WEAPON"))
			return true
		end
		return false
	end,
}

-- aimsweep P S: research step, 1.13.42. One zombie at a time is put 4, 8 and 12 tiles east of the character and held still;
-- the reticle (TGCapture.aimAt) goes through a ladder of heights from below its feet to above its head, P shots per rung
-- (default 2), a fresh zombie for every shot, S seconds at most (default 180). Per shot: whether it fired, the hit and the
-- body part the game says (getLastHitPart). DebugType.Combat is turned on for the step, and a marker line goes to the console
-- before and after every shot, so the game's "isCameraTarget" lines between them (console.txt) say which path the hit took:
-- research/aimsweep-console.py counts them. The ladder is in z levels above the zombie's feet (a floor is 1), the
-- character is about 0.6 tall.
K.SWEEP_DISTS = { 4, 8, 12 }
K.SWEEP_RUNGS = { -0.15, 0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9 }
K.SWEEP_JUDGE_MS = 900
K.SWEEP_AIM_MIN_MS = 700
K.SWEEP_AIM_MAX_MS = 2500
local function sweepMark(st, text)
	st.marks = (st.marks or 0) + 1
	pcall(print, "[TestGround] aimsweep " .. text)
end
function K.sweepJobs(per)
	local jobs = {}
	for _, d in ipairs(K.SWEEP_DISTS) do
		for _, h in ipairs(K.SWEEP_RUNGS) do
			for k = 1, per do jobs[#jobs + 1] = { d = d, h = h } end
		end
	end
	return jobs
end
function K.sweepDebug(st, on)
	pcall(function()
		if on then
			st.dbgWas = DebugLog.isEnabled(DebugType.Combat)
			DebugLog.setLogEnabled(DebugType.Combat, true)
			st.dbgOn = true
		elseif st.dbgOn then
			DebugLog.setLogEnabled(DebugType.Combat, st.dbgWas == true)
			st.dbgOn = false
		end
	end)
end
-- Puts the one test zombie on its spot and keeps it there.
function K.sweepPin(st)
	local z = st.z
	if not z or not st.home then return end
	pcall(function() z:setX(st.home.x); z:setY(st.home.y) end)
	pcall(function() z:setMoving(false) end)
end
Steps.aimsweep = {
	begin = function(r, st)
		st.per = math.max(1, floor(st.a or 2))
		st.seconds = st.b or 180
		local o = gunOpts(st)
		r.holdSweep = true
		removeZombies()
		pcall(function() r.p:setGhostMode(false) end)
		local home = r.plan.start
		if home and not near(r.p, home, 3) then teleport(r.p, home.x, home.y, home.z) end
		st.c = { x = floor(r.p:getX()), y = floor(r.p:getY()), z = floor(r.p:getZ()) }
		r.fightAt, r.fightRadius = st.c, 30
		st.jobs = K.sweepJobs(st.per)
		st.i, st.phase, st.phaseAt = 0, "spawn", 0
		st.shots, st.hits, st.notFired, st.spawnFails, st.reloads = 0, 0, 0, 0, 0
		st.cells = {}
		st.weapon = K.armWeapon(r, st, o.weapon or K.GUN_WEAPON)
		st.skillSet = K.setSkills(r, o.skills)
		local w = r.weaponItem
		st.ranged = false
		if w then pcall(function() st.ranged = w:isRanged() == true end) end
		if w and st.ranged then K.gunLoad(w) end
		pcall(function() st.weapon = st.weapon .. " (" .. tostring(w:getDisplayName()) .. ")" end)
		pcall(function() st.originZ = r.p:getAimOriginPosZ() - r.p:getZ() end)
		st.hooks = {}
		local p = r.p
		local function add(name, fn)
			if Events[name] and Events[name].Add then Events[name].Add(fn); st.hooks[name] = fn end
		end
		add("OnWeaponSwing", function(c)
			if c == p then st.swungAt = now() end
		end)
		add("OnWeaponHitCharacter", function(c, target)
			if c ~= p or not st.shot then return end
			local okP, part = pcall(function() return target:getLastHitPart() end)
			st.hitPart = (okP and part and part ~= "") and tostring(part) or "?"
			st.hitAt = now()
		end)
		K.sweepDebug(st, true)
		if not r.cleanup then
			st.ownCleanup = true
			r.cleanup = function()
				for name, fn in pairs(st.hooks or {}) do pcall(function() Events[name].Remove(fn) end) end
				st.hooks = {}
				pcall(function() K.releaseAim(r.p) end)
				K.gunJavaClear()
				K.sweepDebug(st, false)
			end
		end
		if not st.ranged then T.trace("aimsweep: " .. tostring(st.weapon) .. " isn't a ranged weapon") end
	end,
	tick = function(r, st, t)
		local el = t - st.t0
		local p = r.p
		TG.cantDie(r, st)
		K.holdAim(p, st)
		local w = r.weaponItem
		if w and st.ranged then
			local did, kind = K.gunLoad(w)
			if did and kind == "ammo" then st.reloads = st.reloads + 1 end
			K.gunUnjam(w)
		end
		local done = st.i >= #st.jobs and st.phase == "spawn"
		if done or el >= st.seconds * 1000 then
			K.releaseAim(p)
			K.gunJavaClear()
			K.sweepDebug(st, false)
			for name, fn in pairs(st.hooks or {}) do pcall(function() Events[name].Remove(fn) end) end
			st.hooks = {}
			if st.ownCleanup then r.cleanup = nil end
			removeZombies()
			TG.removeCorpses(st.c, 20)
			r.fightAt, r.fightRadius = nil, nil
			r.holdSweep = false
			TG.keepAlive(p)
			local lines = {}
			for _, d in ipairs(K.SWEEP_DISTS) do
				local rungs = {}
				for _, h in ipairs(K.SWEEP_RUNGS) do
					local cell = st.cells[d .. "/" .. h]
					if cell then
						local names = {}
						for k in pairs(cell.parts) do names[#names + 1] = k end
						table.sort(names)
						local ps = {}
						for _, k in ipairs(names) do ps[#ps + 1] = k .. " " .. cell.parts[k] end
						rungs[#rungs + 1] = string.format("%+.2f: %d shots, %d fired, %d hits%s", h, cell.n, cell.fired, cell.hits, #ps > 0 and (" (" .. table.concat(ps, ", ") .. ")") or "")
					end
				end
				lines[#lines + 1] = string.format("%d tiles [%s]", d, table.concat(rungs, "; "))
			end
			st.result = string.format("%s, %d of %d planned shots taken (%d per rung), %d fired, %d hits, %d not fired, %d zombies that did not appear; Combat debug %s, %d marker lines (console.txt, '[TestGround] aimsweep'); aim origin %s above the feet; rungs are heights above the zombie's feet in floors; by distance and rung: %s%s",
				st.weapon, st.shots, #st.jobs, st.per, st.shots - st.notFired, st.hits, st.notFired, st.spawnFails,
				st.dbgWas ~= nil and "turned on" or "NOT turned on", st.marks or 0, st.originZ and string.format("%.2f", st.originZ) or "?",
				table.concat(lines, "; "), (#st.skillSet > 0 and ("; skills " .. table.concat(st.skillSet, " ")) or ""))
			if el >= st.seconds * 1000 and st.i < #st.jobs then st.result = st.result .. "; STOPPED BY THE TIME LIMIT" end
			return true
		end
		local job = st.jobs[st.i]
		if st.phase == "spawn" then
			if st.i > 0 and t - st.phaseAt < 300 then return false end
			removeZombies()
			TG.removeCorpses(st.c, 20)
			st.i = st.i + 1
			job = st.jobs[st.i]
			if not job then return false end
			st.z, st.home = nil, nil
			local c = st.c
			
			if TG.S.run then TG.S.run.spawnedZombies = true end
			try("spawn zombie", function()
				addZombiesInOutfit(c.x + job.d, c.y, c.z, 1, nil, 50, false, false, false, false, false, false, 1, false, 0, false, false)
			end)
			st.phase, st.phaseAt = "find", t
			return false
		end
		if st.phase == "find" then
			for _, z in ipairs(zombiesList()) do
				if K.gunStanding(z) then st.z = z; break end
			end
			if st.z then
				st.home = { x = st.z:getX(), y = st.z:getY() }
				st.phase, st.phaseAt = "aim", t
				st.shot = nil
			elseif t - st.phaseAt > 1500 then
				st.spawnFails = st.spawnFails + 1
				st.phase, st.phaseAt = "spawn", t
			end
			return false
		end
		local z = st.z
		K.sweepPin(st)
		K.tryOnce("face zombie", function() p:faceThisObject(z) end)
		local zx, zy = z:getX(), z:getY()
		local zz = z:getZ()
		local okJ, pt = K.gunJavaAimAt(p, zx, zy, zz + job.h)
		st.javaPoint = okJ and pt or st.javaPoint
		if st.phase == "aim" then
			local waited = t - st.phaseAt
			local okD, delay = pcall(function() return p:getAimingDelay() end)
			delay = okD and tonumber(delay) or nil
			local settled = waited >= K.SWEEP_AIM_MIN_MS and ((not st.ranged) or delay == nil or delay <= K.GUN_AIM_DELAY_OK or waited >= K.SWEEP_AIM_MAX_MS)
			if settled and K.readyToSwing(p, st) then
				local d = math.sqrt((zx - p:getX()) ^ 2 + (zy - p:getY()) ^ 2)
				st.shot = { t = t, n = st.shots + 1, d = d, delay = delay }
				st.swungAt, st.hitPart, st.hitAt = nil, nil, nil
				sweepMark(st, string.format("shot %d begin: %d tiles (%.1f real), rung %+.2f, aim point %s, aiming delay %s", st.shot.n, job.d, d, job.h, tostring(st.javaPoint), delay and string.format("%.2f", delay) or "?"))
				local ok = K.swing(p, st)
				st.shots = st.shots + 1
				st.phase, st.phaseAt = "judge", t
				if not ok then st.swingFailed = true end
			end
			return false
		end
		if st.phase == "judge" and t - st.phaseAt >= K.SWEEP_JUDGE_MS then
			local key = job.d .. "/" .. job.h
			local cell = st.cells[key] or { n = 0, fired = 0, hits = 0, parts = {} }
			st.cells[key] = cell
			cell.n = cell.n + 1
			local fired = st.swungAt ~= nil
			if fired then cell.fired = cell.fired + 1 else st.notFired = st.notFired + 1 end
			if st.hitPart then
				cell.hits, st.hits = cell.hits + 1, st.hits + 1
				cell.parts[st.hitPart] = (cell.parts[st.hitPart] or 0) + 1
			end
			sweepMark(st, string.format("shot %d end: %s", st.shot.n, not fired and "did not fire" or (st.hitPart and ("hit " .. st.hitPart) or "fired, no hit")))
			st.phase, st.phaseAt = "spawn", t
		end
		return false
	end,
}
K.GROUPS[K.GUN_GROUP] = K.GROUPS[K.GUN_GROUP] or {}
table.insert(K.GROUPS[K.GUN_GROUP], "aimsweep")
