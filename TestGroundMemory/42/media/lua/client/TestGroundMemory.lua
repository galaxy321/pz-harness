-- Test Ground Memory 1.0.0: puts a memory line under each Test Ground step, from the Java
-- sampler in tgmemory.jar (the global TGMemory, exposed by ZombieBuddy). Without the jar it
-- says once that the Java part is missing and adds nothing.
TestGroundMemory = TestGroundMemory or {}
local M = TestGroundMemory
M.VERSION = "1.0.0"

local function J() return rawget(_G, "TGMemory") end
local function get(name)
	local j = J()
	if not j or not j[name] then return -1 end
	local ok, v = pcall(j[name])
	if ok and type(v) == "number" then return v end
	return -1
end
local function mb(v) if v < 0 then return "?" end return string.format("%.0f", v) end
local function gb(v) if v < 0 then return "?" end return string.format("%.1f", v / 1024) end

function M.snapshot()
	return {
		proc = get("processMB"), procPeak = get("processPeakMB"),
		heap = get("heapUsedMB"), heapPeak = get("heapPeakMB"), heapMax = get("heapMaxMB"),
		sysTotal = get("systemTotalMB"), sysFree = get("systemFreeMB"), sysLow = get("systemFreeLowMB"),
		vramTotal = get("vramTotalMB"), vramFree = get("vramFreeMB"), vramLow = get("vramFreeLowMB"),
		vramSrc = (function() local j = J(); local ok, s = pcall(function() return j.vramSource() end); return ok and tostring(s) or "?" end)(),
	}
end

-- "memory: game RAM 3120 MB at the end (peak 3300, +180 over the step), Java heap 1800 MB (peak 2100 of 3072 max),
--  system free 9.1 of 31.9 GB (lowest 8.8), VRAM free 4100 MB (lowest 3900) of 8192 [nvx]"
function M.line(a, b)
	local vram
	if b.vramFree >= 0 then
		vram = string.format("VRAM free %s MB (lowest %s)%s [%s]", mb(b.vramFree), mb(b.vramLow),
			b.vramTotal >= 0 and (" of " .. mb(b.vramTotal)) or "", b.vramSrc)
	else
		vram = "VRAM " .. b.vramSrc
	end
	return string.format("memory: game RAM %s MB at the end (peak %s, %s over the step), Java heap %s MB (peak %s of %s max), system free %s of %s GB (lowest %s), %s",
		mb(b.proc), mb(b.procPeak), (a.proc >= 0 and b.proc >= 0) and string.format("%+.0f", b.proc - a.proc) or "?",
		mb(b.heap), mb(b.heapPeak), mb(b.heapMax), gb(b.sysFree), gb(b.sysTotal), gb(b.sysLow), vram)
end

M.module = {
	stepStart = function(r, st)
		if not J() then return end
		pcall(function() J().mark() end)
		st.memStart = M.snapshot()
	end,
	stepEnd = function(r, st, add)
		if not J() or not st.memStart then return end
		local b = M.snapshot()
		add(M.line(st.memStart, b))
		r.memPeak = math.max(r.memPeak or -1, b.procPeak)
		r.heapPeak = math.max(r.heapPeak or -1, b.heapPeak)
		if b.vramLow >= 0 then r.vramLow = math.min(r.vramLow or 1e12, b.vramLow) end
	end,
	finish = function(r, add)
		if not J() then
			add("memory: Test Ground Memory is on but its Java part isn't loaded (ZombieBuddy missing, or the jar not allowed)")
			return
		end
		add(string.format("memory: run peak game RAM %s MB, Java heap %s MB, lowest free VRAM %s MB (%s)",
			mb(r.memPeak or -1), mb(r.heapPeak or -1), mb(r.vramLow or -1), tostring((function() local ok, s = pcall(function() return J().status() end); return ok and s or "?" end)())))
	end,
}

function M.register()
	if M.registered then return true end
	if not (TestGround and TestGround.addReportModule) then return false end
	M.registered = TestGround.addReportModule("memory", M.module)
	local j = J()
	local ok, s = pcall(function() return j and j.status() end)
	print("[TestGroundMemory] " .. (j and ("Lua " .. M.VERSION .. ", " .. tostring(ok and s or "?")) or "Lua " .. M.VERSION .. ": the Java part (TGMemory) is missing, so no memory lines"))
	return M.registered
end

if not M.register() then Events.OnGameStart.Add(M.register) end
