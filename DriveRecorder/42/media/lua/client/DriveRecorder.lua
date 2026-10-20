-- Drive Recorder 1.0.0: records how you drive, for comparing against Test Ground's scripted drives.
-- Every 250 ms while the player is in a driver's seat one CSV line goes to
-- Zomboid/Lua/DriveRecorder_<epoch ms>.txt (one file per drive): the car's position, heading,
-- speed, pedals, steering, engine speed, the driver's health, the vehicles within 40 tiles and
-- a knock flag. Starts on getting in the driver's seat, stops on getting out; F9 turns it off and on.
-- Lines are buffered and appended every 5 s, so a crash loses at most that much.
DriveRecorder = DriveRecorder or {}
local R = DriveRecorder
R.VERSION = "1.0.0"
R.SAMPLE_MS = 250
R.FLUSH_MS = 5000
R.NEAR = 40
R.KNOCK_DEG_S = 45
R.KNOCK_DROP_KMH = 15
R.KEY = Keyboard and Keyboard.KEY_F9 or 67
R.enabled = true
R.HEADER = "t_ms,x,y,z,heading_deg,move_deg,kmh,gas,brake,braking,steer,engine,health,cars_near,knock"

local now = getTimestampMs

local function say(p, text)
	print("[DriveRecorder] " .. text)
	pcall(function() HaloTextHelper.addText(p, text, HaloTextHelper.getColorWhite()) end)
end

local function call(f, ...)
	local ok, v = pcall(f, ...)
	if ok then return v end
	return nil
end

local function b(v) if v == nil then return "" end return v and "1" or "0" end
local function n(v, fmt) if v == nil then return "" end return string.format(fmt or "%.2f", v) end

function R.write(append)
	local rec = R.rec
	if not rec or #rec.buf == 0 then return end
	pcall(function()
		local w = getFileWriter(rec.file, true, append)
		for _, l in ipairs(rec.buf) do w:writeln(l) end
		w:close()
	end)
	rec.buf = {}
	rec.flushed = now()
end

function R.carsNear(v, x, y)
	local count = 0
	pcall(function()
		local list = getCell():getVehicles()
		for i = 0, list:size() - 1 do
			local o = list:get(i)
			if o ~= v then
				local dx, dy = o:getX() - x, o:getY() - y
				if dx * dx + dy * dy <= R.NEAR * R.NEAR then count = count + 1 end
			end
		end
	end)
	return count
end

local function angDiff(a, b2)
	local d = (a - b2) % 360
	if d > 180 then d = d - 360 end
	return d
end

function R.start(p, v)
	local t = now()
	R.rec = { car = v, file = "DriveRecorder_" .. tostring(t) .. ".txt", t0 = t, next = t, flushed = t, buf = {}, lines = 0, knocks = 0 }
	local name = call(function() return v:getScript():getFullName() end) or "?"
	local stamp = call(function() return os.date("%Y-%m-%d %H:%M:%S") end) or ""
	R.rec.buf[1] = string.format("# Drive Recorder %s, %s, car %s, started %s (epoch ms %d)", R.VERSION, call(function() return getCore():getVersion() end) or "?", name, stamp, t)
	R.rec.buf[2] = "# heading_deg is the car's yaw (getAngleY); move_deg is the direction it moved since the last line (0 = east, 90 = south); knock = the heading turned faster than " .. R.KNOCK_DEG_S .. " deg/s or the speed fell " .. R.KNOCK_DROP_KMH .. " km/h in one line"
	R.rec.buf[3] = R.HEADER
	R.write(false)
	say(p, "Drive Recorder: recording")
end

function R.stop(p)
	local rec = R.rec
	if not rec then return end
	rec.buf[#rec.buf + 1] = string.format("# stopped after %.1f s, %d lines, %d knocks", (now() - rec.t0) / 1000, rec.lines, rec.knocks)
	R.write(true)
	R.rec = nil
	say(p, string.format("Drive Recorder: saved %s (%d lines)", rec.file, rec.lines))
end

function R.sample(p, v, t)
	local rec = R.rec
	local x, y, z = v:getX(), v:getY(), v:getZ()
	local kmh = call(function() return v:getCurrentSpeedKmHour() end)
	local yaw = call(function() return v:getAngleY() end)
	local move, knock = nil, false
	if rec.last then
		local dx, dy = x - rec.last.x, y - rec.last.y
		if dx * dx + dy * dy > 0.01 then move = math.deg(math.atan2(dy, dx)) % 360 end
		local dt = (t - rec.last.t) / 1000
		if dt > 0 and yaw and rec.last.yaw and kmh and math.abs(kmh) > 5 then
			if math.abs(angDiff(yaw, rec.last.yaw)) / dt > R.KNOCK_DEG_S then knock = true end
		end
		if kmh and rec.last.kmh and rec.last.kmh - kmh > R.KNOCK_DROP_KMH then knock = true end
	end
	if knock then rec.knocks = rec.knocks + 1 end
	rec.buf[#rec.buf + 1] = table.concat({
		tostring(t - rec.t0), n(x), n(y), n(z, "%d"), n(yaw, "%.1f"), n(move, "%.1f"), n(kmh, "%.1f"),
		b(call(function() return v:isGasPedalPressed() end)),
		b(call(function() return v:isBrakePedalPressed() end)),
		b(call(function() return v:isBraking() end)),
		n(call(function() return v:getCurrentSteering() end), "%.3f"),
		n(call(function() return v:getEngineSpeed() end), "%.0f"),
		n(call(function() return p:getHealth() end), "%.3f"),
		tostring(R.carsNear(v, x, y)), knock and "1" or "0",
	}, ",")
	rec.lines = rec.lines + 1
	rec.last = { x = x, y = y, t = t, yaw = yaw, kmh = kmh }
end

function R.tick()
	local p = getPlayer()
	if not p then return end
	local v = call(function() return p:getVehicle() end)
	local driving = v and R.enabled and call(function() return v:getDriver() == p end)
	local rec = R.rec
	if rec and (not driving or rec.car ~= v) then R.stop(p); rec = nil end
	if not driving then return end
	if not rec then R.start(p, v); rec = R.rec end
	local t = now()
	if t >= rec.next then
		rec.next = t + R.SAMPLE_MS
		R.sample(p, v, t)
	end
	if t - rec.flushed >= R.FLUSH_MS then R.write(true) end
end

function R.key(key)
	if key ~= R.KEY then return end
	local p = getPlayer()
	R.enabled = not R.enabled
	if not R.enabled then
		if R.rec then R.stop(p) end
		if p then say(p, "Drive Recorder: off (F9 turns it on)") end
	elseif p then
		say(p, "Drive Recorder: on, records while you drive")
	end
end

Events.OnTick.Add(R.tick)
Events.OnKeyPressed.Add(R.key)
