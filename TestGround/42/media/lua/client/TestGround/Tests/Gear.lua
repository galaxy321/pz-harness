-- Test Ground 1.13.2: gear and car loot: goggles on and off, and the loot window beside a parked car.
require "TestGround/Core"
require "TestGround/Tests/Drive"
local TG = TestGroundInternal
if TG.loaded.Gear then return end
TG.loaded.Gear = true
local K, Steps, T, floor = TG.K, TG.Steps, TG.T, TG.floor
local near, teleport, try = TG.near, TG.teleport, TG.try
table.insert(K.GROUPS.idle, "goggles")
table.insert(K.GROUPS.idle, "carloot")
table.insert(K.GROUPS.idle, "give")

-- goggles S [every] [item=Module.Name]: night-vision goggles are put on and taken off every
-- `every` seconds (default 3) for S seconds, the way the Wear menu does it (setWornItem, then
-- OnClothingUpdated), so whatever checks worn items for night vision (Night Vision Framework's
-- IsNVTaggedItem, Hitch Fix's cache of it) runs on each change. The item is the plan's, or the
-- first of K.GOGGLES that exists, or one Night Vision Framework has registered. Taken away after.
K.GOGGLES = { "Base.Glasses_NightVision", "Base.NightVisionGoggles", "Base.NVG_PNV-10T_DOWN", "Base.NVG_GPNVG-18_DOWN", "Base.NVG_ANPVS-14_DOWN" }
function K.findItemType(list)
	local sm = getScriptManager()
	for _, id in ipairs(list) do
		local ok, it = pcall(function() return sm:FindItem(id) end)
		if ok and it then return id end
	end
	return nil
end
function K.goggleType(want)
	if want then return K.findItemType({ want }) end
	local id = K.findItemType(K.GOGGLES)
	if id then return id end
	local reg = {}
	pcall(function() for ft in pairs(NV.Shared.REGISTERED_NIGHT_VISION_ITEMS) do reg[#reg + 1] = ft end end)
	table.sort(reg)
	return K.findItemType(reg)
end
local function wear(p, item, on)
	local ok = pcall(function()
		if on then p:setWornItem(item:getBodyLocation(), item) else p:removeWornItem(item) end
	end)
	pcall(function() triggerEvent("OnClothingUpdated", p) end)
	return ok
end
Steps.goggles = {
	begin = function(r, st)
		st.seconds = st.a or 30
		st.every = math.max(0.5, st.b or 3)
		local want = nil
		for w in string.gmatch(st.text or "", "%S+") do
			local k, v = string.match(w, "^([%w_]+)=(%S+)$")
			if k and string.lower(k) == "item" then want = v end
		end
		local id = K.goggleType(want)
		if not id then st.skip = "no night-vision goggles item found (" .. (want or table.concat(K.GOGGLES, ", ")) .. "; item=<id> names one)"; return end
		local ok, item = pcall(function() return r.p:getInventory():AddItem(id) end)
		if not ok or not item then st.skip = "could not add " .. id; return end
		st.id, st.item, st.ons, st.offs, st.fails, st.on = id, item, 0, 0, 0, false
		st.next = 1000
		r.cleanup = function() wear(r.p, item, false); pcall(function() r.p:getInventory():Remove(item) end) end
	end,
	tick = function(r, st, t)
		local el = t - st.t0
		if el >= st.next then
			st.next = el + st.every * 1000
			st.on = not st.on
			if wear(r.p, st.item, st.on) then
				if st.on then st.ons = st.ons + 1 else st.offs = st.offs + 1 end
			else
				st.fails = st.fails + 1
			end
		end
		if el < st.seconds * 1000 then return false end
		if r.cleanup then pcall(r.cleanup); r.cleanup = nil end
		local nv = NV and NV.Shared and NV.Shared.IsNVTaggedItem and "Night Vision Framework is loaded" or "no Night Vision Framework"
		st.result = string.format("%s put on %d times and taken off %d times (every %g s)%s; %s",
			st.id, st.ons, st.offs, st.every, st.fails > 0 and string.format(", %d FAILED", st.fails) or "", nv)
		return true
	end,
}

-- give <Module.Item> [wear] [keep] [S] [name]: the item is added to the player's inventory and, with
-- `wear`, put on the way the Wear menu does it (setWornItem, then OnClothingUpdated). The result says
-- whether it is worn after S seconds (default 5). Taken off and removed after, unless `keep`.
-- Skipped, with the reason, when the item isn't known to the game.
local function isWorn(p, item)
	local ok, v = pcall(function() return p:isEquippedClothing(item) end)
	if ok and v ~= nil then return v and true or false end
	ok, v = pcall(function() return p:getWornItem(item:getBodyLocation()) == item end)
	return ok and v or false
end
Steps.give = {
	begin = function(r, st)
		st.seconds = st.a or 5
		local id, wantWear, keep
		-- the item id comes from the step's own text: the parsed args are lower-cased and ids are not
		local words = {}
		for w in string.gmatch(st.text or "", "%S+") do words[#words + 1] = w end
		for i = 2, #words do
			local w = words[i]
			local lw = string.lower(w)
			if lw == "wear" then wantWear = true
			elseif lw == "keep" then keep = true
			elseif tonumber(w) then st.seconds = tonumber(w)
			elseif not id and string.find(w, ".", 1, true) then id = w end
		end
		if not id then st.skip = "give needs an item id, such as give Base.Pen wear"; return end
		if not K.findItemType({ id }) then st.skip = id .. " isn't known to the game"; return end
		local ok, item = pcall(function() return r.p:getInventory():AddItem(id) end)
		if not ok or not item then st.skip = "could not add " .. id; return end
		st.id, st.item, st.wantWear, st.keep, st.done = id, item, wantWear, keep, false
		r.cleanup = function()
			if not keep then
				wear(r.p, item, false)
				pcall(function() r.p:getInventory():Remove(item) end)
				local prev = st.prev
				if prev and prev ~= item then st.restored = wear(r.p, prev, true) end
			end
		end
		if wantWear then
			-- 1.13.24: what was worn in that slot is put back after, not left in the inventory
			pcall(function() st.prev = r.p:getWornItem(item:getBodyLocation()) end)
			st.wearOk = wear(r.p, item, true)
		end
	end,
	tick = function(r, st, t)
		if t - st.t0 < st.seconds * 1000 then return false end
		local inInv = false
		pcall(function() inInv = r.p:getInventory():contains(st.item) end)
		local worn = st.wantWear and isWorn(r.p, st.item)
		if r.cleanup then pcall(r.cleanup); r.cleanup = nil end
		-- 1.13.24: the removal is checked, not assumed
		local gone = true
		if not st.keep then pcall(function() gone = not r.p:getInventory():contains(st.item) end) end
		local what = st.id .. (inInv and " was in the inventory" or " was NOT in the inventory")
		if st.wantWear then
			what = what .. (worn and ", worn after " or ", NOT worn after ") .. string.format("%g s", st.seconds)
			if st.wearOk == false then what = what .. " (the wear call raised an error)" end
		end
		if st.prev and st.restored ~= nil and not st.keep then
			what = what .. (st.restored and ", the item worn before was put back" or ", the item worn before could NOT be put back")
		end
		st.result = what .. (st.keep and "; kept" or (gone and "; removed after" or "; NOT removed after (still in the inventory)"))
		return true
	end,
}

-- carloot S [N]: a car (the first of the fast drive's cars there is) is parked 2 tiles east of the
-- start, and you take a single step (one tile) along it every 1.5 s, back and forth over N squares
-- (default 6), so the loot window lists its containers again at each step. The car is removed after.
K.CARLOOT_STEP_MS = 1500
Steps.carloot = {
	begin = function(r, st)
		st.seconds = st.a or 30
		st.span = math.max(2, floor(st.b or 6))
		local home = r.plan.start or r.home
		if home and not near(r.p, home, 3) then teleport(r.p, home.x, home.y, home.z) end
		local x, y, z = floor(r.p:getX()), floor(r.p:getY()), floor(r.p:getZ())
		local sq = getCell():getGridSquare(x + 2, y, z)
		if not sq then st.skip = "the square beside the start isn't loaded"; return end
		local v, name = TG.spawnFastCar(sq, 0, 1)
		if not v then st.skip = "could not park a car"; return end
		st.car, st.name, st.x0, st.y0, st.z = v, name, x, y - floor(st.span / 2), z
		st.containers = 0
		pcall(function()
			for i = 0, v:getPartCount() - 1 do
				if v:getPartByIndex(i):getItemContainer() then st.containers = st.containers + 1 end
			end
		end)
		st.i, st.dir, st.steps, st.next = 0, 1, 0, 1000
		teleport(r.p, st.x0, st.y0, z)
		r.cleanup = function()
			if not pcall(function() v:permanentlyRemove() end) then pcall(function() v:removeFromWorld() end) end
		end
	end,
	tick = function(r, st, t)
		local el = t - st.t0
		if el >= st.next then
			st.next = el + K.CARLOOT_STEP_MS
			if st.i + st.dir < 0 or st.i + st.dir > st.span then st.dir = -st.dir end
			st.i = st.i + st.dir
			pcall(function()
				r.p:setX(st.x0 + 0.5); r.p:setY(st.y0 + st.i + 0.5)
				r.p:getForwardDirection():set(1, 0)
			end)
			st.steps = st.steps + 1
		end
		if el < st.seconds * 1000 then return false end
		if r.cleanup then pcall(r.cleanup); r.cleanup = nil end
		st.result = string.format("%s parked beside you (%d parts with a container), %d single steps along it over %d squares", tostring(st.name), st.containers, st.steps, st.span + 1)
		return true
	end,
}
