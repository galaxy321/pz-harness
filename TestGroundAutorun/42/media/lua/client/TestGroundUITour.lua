--
-- Test Ground Autorun 1.5.9: the UI tour (1.5.11: the review and PC-tour fixes are marked) (flag "uitour = 1"; design: test-ground/docs/UI-CHECKS.md).
-- Opens every Test Ground and Autorun screen in turn with worst-case contents, runs the UI check on it,
-- takes a Test Ground Capture screenshot of it and closes it, so one PC job gives a checked shot of every
-- screen at the game's own resolution setting. At the main menu: the Benchmark Save button and the picker
-- (long names, then the copying state). Then the save loads as usual; in game: the settle banner, the confirm
-- dialog, the run banner (three states) and the end screen (four states). Nothing is clicked but Cancel,
-- No and Keep playing. Writes Zomboid/Lua/TestGround_uitour.txt (the manifest) and TestGround_uicheck.txt.
--
require "TestGroundAutorun"
require "TestGroundUICheck"

local A = TestGroundAutorun
if A.tourLoaded then return end
A.tourLoaded = true
local U = TestGroundUICheck
local V = {}
A.Tour = V

V.MANIFEST = "TestGround_uitour.txt"
V.STEP_TIMEOUT_MS = 10000
V.SETTLE_FRAMES = 3            -- frames drawn after the probe frame before the check and shot
local function say(s) print("[TestGroundAutorun] ui tour: " .. s) end
local now = getTimestampMs

local function writeLines(name, lines, append)
	pcall(function()
		local w = getFileWriter(name, true, append == true)
		for _, l in ipairs(lines) do w:writeln(l) end
		w:close()
	end)
end

function V.build()
	local tg = (TestGround and TestGround.VERSION) or "tg-unknown"
	return tostring(tg) .. "-" .. tostring(A.VERSION or "ar")
end

-- ---------------------------------------------------------------------------------------------
-- Fixtures: the worst cases a real user can reach
V.LONG_NAME = string.rep("Lumberjack Long Save Name ", 8)   -- 208 characters
V.WIDE_NAME = "\229\164\167\233\149\135\231\148\159\229\173\152 \208\154\208\190\208\191\208\184\209\143 " .. string.rep("W", 60)   -- multi-byte, then wide letters
function V.pickerRows()
	local rows = {
		{ mode = "Sandbox", name = V.LONG_NAME, t = 30 },
		{ mode = "Apocalypse", name = V.WIDE_NAME, t = 29 },
		{ mode = "Sandbox", name = "TG_Benchmark_Vanilla_1792140000", t = 28, mark = "old benchmark copy" },
		{ mode = "Sandbox", name = "Lumberjack - Copy - PerfTest", t = 27, mark = "test copy" },
	}
	for i = 1, 26 do rows[#rows + 1] = { mode = "Survivor", name = "Tour row " .. i, t = 26 - i } end
	return rows
end
function V.endSummary(stopped)
	local rows = {}
	local names = { "Idle look (720 degrees, commanded)", "Walk the West Point loop, single lap", "Drive fast on the highway to Muldraugh",
		"Fight 40 zombies in the open (large)", "Fight with a swing weapon, guarded", "Stress: 500 zombies around the player",
		"Glide over the trees near the river", "Build a room with Better Building Plus", "Gun range: 30 shots",
		"Gear: equip and remove a full set", "Station: crafting at the workbench", "Zombies: spawn and remove 200",
		"Melee at the fence line, standing", "A step with a very long name that runs on past the column before the numbers", "Overflow row 15", "Overflow row 16" }
	for i, n in ipairs(names) do
		rows[i] = { name = n, skipped = (i == 5 or i == 14), f = { fps = 59.9 - i, p99 = 20 + i * 7, over100 = (i % 4 == 0) and i or 0 } }
	end
	return { save = V.LONG_NAME, copyOf = true, rows = rows, seconds = 912, frames = 51234, fps = 56.2, mean = 17.8, p99 = 165,
		worst = 1187, over33 = 1234, over100 = 56, stopped = stopped }
end
local function fakeRun(phase)
	local st = { tag = "stress_500", kind = "zombies", pass = 2, t0 = now() - 47000,
		text = "500 zombies around the player for 60 s while walking a figure eight through the town square" }
	return { phase = phase, plan = { label = "baseline", rep = 2 }, steps = { st, st, st, st, st, st, st, st, st, st, st, st, st }, si = 13,
		loadingSince = phase == "settle" and now() or nil }
end

-- ---------------------------------------------------------------------------------------------
-- The screens. Each: name (screen/state), expect (one line for the PC thread's look), open() -> window or
-- true (drawn without a window), check(win) -> result, close(win).
local function K() return TestGroundInternal and TestGroundInternal.K end
local function closeWin(w) pcall(function() w:setVisible(false); w:removeFromUIManager() end) end
local function bannerCheck(name, big, small)
	local d1, w1 = U.checkText(name .. "/big", big or "", UIFont.Large)
	local d2, w2 = U.checkText(name .. "/small", small or "", UIFont.Medium)
	local d = {}
	for _, l in ipairs(d1) do d[#d + 1] = l end
	for _, l in ipairs(d2) do d[#d + 1] = l end
	local sw, sh = U.screen()
	local fl = U.fontHeight(UIFont.Large) + 4 + U.fontHeight(UIFont.Medium)
	local wmax = math.max(w1 or 0, w2 or 0)
	return { defects = d, warnings = {}, rect = { x = (sw - wmax) / 2, y = sh * 0.1, w = wmax, h = fl }, kids = {} }
end

V.MENU = {
	{ name = "menu_button/normal", expect = "a 'Benchmark Save' button at the bottom left of the main menu, label whole and centred",
		open = function() local ms = MainScreen and MainScreen.instance; return ms and ms.testGroundBenchBtn or nil end,
		check = function(btn) return U.checkControl("menu_button/normal", btn) end, close = function() end, noArm = true },
	{ name = "picker/long_names", expect = "window centred; title top left; two intro lines; list of 31 rows, long names end in '...' with the mode in brackets visible; footer lines between list and buttons; three buttons in one row at the bottom, every label whole, none overlapping; without the Save Copier mod loaded, a red note of two lines between the footer and the buttons (copying needs the Test Ground Save Copier mod and ZombieBuddy; 'New vanilla save' works without it), whole and inside the window; with it loaded, no note",
		open = function() A.benchFixtureRows = V.pickerRows(); return A.showBenchWindow and A.showBenchWindow() end,
		needs = { { "getTextManager", "MeasureStringX" }, { "getTextManager", "getFontHeight" }, { "getFullSaveDirectoryTable" } },
		close = function() end },   -- stays open for the next state
	{ name = "picker/copying", expect = "as long_names, plus a red 'Copying the save for the test' line under the footer, inside the window; the two start buttons greyed out",
		open = function()
			local w = A.benchWindow
			if not w then A.benchFixtureRows = nil; return nil end
			w.note = "Copying the save for the test: 18234 of 40211 files (2.31 GB of 5.07 GB), about 1 min left"
			pcall(function() w.startBtn:setEnable(false); w.quickBtn:setEnable(false) end)
			return w
		end,
		close = function(w) pcall(function() w:onCancel() end); A.benchFixtureRows = nil end,
		onFail = function() V.cleanMenu() end },
}

V.GAME = {
	{ name = "confirm/dialog", expect = "a dialog centred on screen with the whole 'Test Ground changes this save' text inside it and Yes and No buttons at the bottom",
		open = function() local k = K(); return k and k.confirmDialog and k.confirmDialog(function() end) end,
		close = function(w) closeWin(w); local k = K(); if k then k.asking = false end end },
	{ name = "run_banner/settle", banner = "settle" },
	{ name = "run_banner/gap", banner = "gap" },
	{ name = "run_banner/step", banner = "step" },
	{ name = "end_screen/countdown", endscreen = { seconds = 120 },   -- 1.5.11: 120 s, so a slow shot never lets it close the game
		expect = "panel centred; title; save line wrapped inside the panel; stats lines inside; 14 step rows and a '... and 2 more' line; columns fps, p99 ms, hitches aligned; 'Closing the game in N s' above three buttons; nothing past the right edge" },
	{ name = "end_screen/paused", endscreen = { seconds = 120, pause = true }, expect = "as countdown, with 'Countdown paused' in amber and the button reading 'Resume countdown'" },
	{ name = "end_screen/no_countdown", endscreen = {}, expect = "as countdown, with no countdown line, no Pause button and the left button reading 'Close game'" },
	{ name = "end_screen/stopped", endscreen = { stopped = "stopped by the user" }, expect = "as no_countdown, with the title ending '(stopped by the user)' and still inside the panel" },
}
for _, s in ipairs(V.GAME) do
	if s.banner then
		s.expect = "two centred lines near the top of the screen (amber, white under it), both whole and inside the screen"
		s.open = function()
			local k = K()
			if not (k and k.bannerText) then return nil end
			k.tourRun = fakeRun(s.banner)
			return true
		end
		s.check = function()
			local k = K()
			local big, small = k.bannerText(k.tourRun, now())
			return bannerCheck(s.name, big, small)
		end
		s.close = function() local k = K(); if k then k.tourRun = nil end end
		s.noArm = true
	elseif s.endscreen then
		local e = s.endscreen
		s.needs = { { "getTextManager", "MeasureStringX" }, { "getCore", "quitToDesktop" } }
		s.open = function()
			if not TestGroundEndScreen then return nil end
			local w = TestGroundEndScreen:new(V.endSummary(e.stopped), e.seconds)
			w:initialise(); w:instantiate(); w:addToUIManager(); w:bringToTop()
			if e.pause then w:onPause() end
			return w
		end
		s.close = function(w) pcall(function() w:onKeep() end) end
	end
end

-- ---------------------------------------------------------------------------------------------
-- The runner: one screen at a time, driven by OnFETick at the menu and OnTick in game
local tour = nil   -- { list, i, phase, win, t0, frames, done, results }

local function rectLine(r) return string.format("%d %d %d %d", math.floor(r.x or 0), math.floor(r.y or 0), math.floor(r.w or 0), math.floor(r.h or 0)) end
local function manifest(step, res, shot)
	local l = { "shot " .. step.name, "file = " .. shot, "expect = " .. (step.expect or "") }
	if res then
		if res.rect then l[#l + 1] = "window = " .. rectLine(res.rect) end
		local ax, ay = res.rect and res.rect.x or 0, res.rect and res.rect.y or 0
		for i, c in ipairs(res.kids or {}) do
			-- 1.5.12: a list's rectangle ends where it clips its rows (the scroll bar's x + 3), so uishots' edge test
			-- looks at the rows, not at the scroll bar (a LOOK on every picker shot of the 1.5.11 tour)
			local cw = c.width or 0
			if c.items and c.vscroll and c.vscroll.x then cw = math.min(cw, c.vscroll.x + 3) end
			l[#l + 1] = string.format("element %s = %d %d %d %d", string.gsub(tostring(c.tgName or c.title or c.Type or ("child" .. i)), "%s+", "_"),
				math.floor(ax + (c.x or 0)), math.floor(ay + (c.y or 0)), math.floor(cw), math.floor(c.height or 0))
		end
		l[#l + 1] = string.format("defects = %d, warnings = %d", #res.defects, #(res.warnings or {}))
		for _, d in ipairs(res.defects) do l[#l + 1] = d end
		for _, w in ipairs(res.warnings or {}) do l[#l + 1] = w end
	else
		l[#l + 1] = "defects = 1, warnings = 0"
		l[#l + 1] = "UICHECK DEFECT " .. step.name .. " NOT_OPENED the screen could not be opened"
	end
	l[#l + 1] = "end"
	writeLines(V.MANIFEST, l, true)
end

local function captureBusy()
	local ok, b = pcall(function() return TGCapture.busy() end)
	return ok and b == true
end

local function advance(t)
	local s = tour.list[tour.i]
	if not s then
		local cb = tour.done
		local stats = tour.stats
		tour = nil
		U.quiet = nil
		if cb then cb(stats) end
		return
	end
	if tour.phase == "open" then
		local ok, w = pcall(s.open)
		if not ok or not w then
			say(s.name .. ": could not open (" .. tostring(w) .. ")")
			if s.onFail then pcall(s.onFail) end
			manifest(s, nil, "NO SHOT (not opened)")
			tour.stats.defects = tour.stats.defects + 1
			tour.stats.missing = tour.stats.missing + 1
			tour.i, tour.phase = tour.i + 1, "open"
			return
		end
		tour.win, tour.t0, tour.frames = w, t, 0
		if type(w) == "table" and not s.noArm then U.arm(w, s.name, { needs = s.needs }) end
		tour.phase = "wait"
	elseif tour.phase == "wait" then
		local w = tour.win
		local probed = s.noArm or type(w) ~= "table" or U.ready(w)
		if probed then tour.frames = tour.frames + 1 end
		if tour.frames >= V.SETTLE_FRAMES or t - tour.t0 > V.STEP_TIMEOUT_MS then
			local res
			if s.check then res = s.check(w) elseif U.ready(w) then res = U.evaluate(w) end
			if not res then
				res = { defects = { "UICHECK DEFECT " .. s.name .. " NO_PROBE the window drew no frame in " .. V.STEP_TIMEOUT_MS / 1000 .. " s" }, warnings = {} }
			end
			tour.res = res
			tour.shotName = string.format("TG_ui_%s_%s", V.build(), string.gsub(s.name, "/", "_"))
			local okC, taken = pcall(function() return TGCapture.request(tour.shotName, "back") end)
			if not okC or not taken then
				tour.shotFile = "NO SHOT (" .. (okC and "capture busy" or ("Test Ground Capture: " .. tostring(taken))) .. "); take it with Steam F12"
				tour.phase = "close"
			else
				tour.shotFile = tour.shotName .. ".png"
				tour.phase, tour.t0 = "shoot", t
			end
		end
	elseif tour.phase == "shoot" then
		if captureBusy() and t - tour.t0 < V.STEP_TIMEOUT_MS then return end
		local okL, lr = pcall(function() return TGCapture.lastResult() end)
		if okL and lr and string.find(tostring(lr), "NOT captured", 1, true) then tour.shotFile = "NO SHOT (" .. tostring(lr) .. ")" end
		tour.phase = "close"
	elseif tour.phase == "close" then
		manifest(s, tour.res, tour.shotFile)
		tour.stats.shots = tour.stats.shots + (string.find(tour.shotFile, "^NO SHOT") and 0 or 1)
		tour.stats.screens = tour.stats.screens + 1
		tour.stats.defects = tour.stats.defects + #tour.res.defects
		tour.stats.warnings = tour.stats.warnings + #(tour.res.warnings or {})
		say(string.format("%s: %d defects, shot %s", s.name, #tour.res.defects, tour.shotFile))
		pcall(s.close, tour.win)
		tour.win, tour.res = nil, nil
		tour.i, tour.phase = tour.i + 1, "open"
	end
end

local function onTourTick()
	if not tour then
		pcall(function() Events.OnFETick.Remove(onTourTick) end)
		pcall(function() Events.OnTick.Remove(onTourTick) end)
		return
	end
	local ok, err = pcall(advance, now())
	if not ok then
		say("error: " .. tostring(err))
		if tour then
			pcall(function() local s = tour.list[tour.i]; if s and tour.win then s.close(tour.win) end end)
			manifest(tour.list[tour.i] or { name = "?" }, { defects = { "UICHECK DEFECT tour ERROR " .. tostring(err) }, warnings = {} }, "NO SHOT (tour error)")
			tour.stats.defects = tour.stats.defects + 1
			tour.i, tour.phase = tour.i + 1, "open"
		end
	end
end

function V.saveName()
	local n = nil
	pcall(function() n = getWorld():getWorld() end)
	return n
end
-- a harness copy ("... - PerfTest"), a Benchmark Save copy, or a save the flag marks with closeui = 1
function V.isTestCopy()
	local n = tostring(V.saveName() or "")
	if string.find(n, " %- PerfTest$") then return true end
	if A.isBenchName and A.isBenchName(n) then return true end
	local job = A.currentJob and A.currentJob()
	return job and job.flag and job.flag.closeui == true or false
end

-- 1.5.11 (review of 1.5.9): no fixture rows or picker left behind, whatever happened at the menu
function V.cleanMenu()
	A.benchFixtureRows = nil
	if A.benchWindow then pcall(function() A.benchWindow:onCancel() end) end
	A.benchWindow = nil
end
-- the flag's time-out ran out mid-tour: close what is open and stop
function V.abort()
	if not tour then return end
	local s = tour.list[tour.i]
	if s and tour.win then pcall(s.close, tour.win) end
	pcall(V.cleanMenu)
	local k = TestGroundInternal and TestGroundInternal.K
	if k then k.tourRun = nil end
	tour = nil
	U.quiet = nil
	writeLines(V.MANIFEST, { "aborted: the flag's time-out ran out" }, true)
end

local function start(list, done, ev)
	U.quiet = true
	tour = { list = list, i = 1, phase = "open", done = done, stats = { screens = 0, shots = 0, defects = 0, warnings = 0, missing = 0 } }
	pcall(function() Events[ev].Add(onTourTick) end)
end

function V.header(part)
	local sw, sh = U.screen()
	local cap = "not loaded"
	pcall(function() cap = tostring(TGCapture.status()) end)
	return { string.format("ui tour %s, part %s, screen %dx%d (the game's resolution setting)", V.build(), part, sw, sh), "capture = " .. cap }
end

-- At the main menu, before the load. Starts a new manifest and check file, and dumps the font widths.
function V.menu(f, thenLoad)
	U.reset("tour " .. V.build())
	U.dumpFontMetrics()
	writeLines(V.MANIFEST, V.header("menu"), false)
	say("main menu part (" .. #V.MENU .. " screens)")
	start(V.MENU, function(stats)
		V.cleanMenu()
		writeLines(V.MANIFEST, { string.format("part menu: %d screens, %d shots, %d defects, %d warnings", stats.screens, stats.shots, stats.defects, stats.warnings) }, true)
		thenLoad()
	end, "OnFETick")
end

-- In game, after the settle banner's shot. done(lines) gets the done file's lines.
function V.game(done)
	writeLines(V.MANIFEST, V.header("game"), true)
	-- 1.5.11 (PC tour of 1.5.9): the save's open Character Info window sat under the run banner's second line
	-- 1.5.12 (review of 1.5.11): closeUI closes the save's other windows too, so only in a test copy
	if V.isTestCopy() then
		pcall(function() local closed = A.closeUI(); if closed and #closed > 0 then say("closed before the in-game part: " .. table.concat(closed, ", ")) end end)
	else
		say("windows left open: this save is not a test copy (" .. tostring(V.saveName()) .. ")")
	end
	say("in-game part (" .. #V.GAME .. " screens)")
	start(V.GAME, function(stats)
		local all = V.totals(stats)
		writeLines(V.MANIFEST, { string.format("part game: %d screens, %d shots, %d defects, %d warnings", stats.screens, stats.shots, stats.defects, stats.warnings), all }, true)
		done({ "result = ui tour done", all, "manifest = " .. V.MANIFEST, "uicheck = " .. U.FILE })
	end, "OnTick")
end

-- the settle banner is real (Autorun's own, during the delay): checked and shot once, a few seconds before the start
function V.settleShot(big, small)
	local res = bannerCheck("settle_banner/waiting", big, small)
	local name = string.format("TG_ui_%s_settle_banner_waiting", V.build())
	local okC, taken = pcall(function() return TGCapture.request(name, "back") end)
	local file = (okC and taken) and (name .. ".png") or "NO SHOT (Test Ground Capture not available); take it with Steam F12"
	manifest({ name = "settle_banner/waiting", expect = "'Waiting for the world to settle...' in amber with the seconds left under it, centred near the top" }, res, file)
	V.settled = { shots = (okC and taken) and 1 or 0, defects = #res.defects }
end

-- every part's counts from the manifest's "part" lines
function V.totals(game)
	local shots, defects, screens = game.shots, game.defects, game.screens
	pcall(function()
		local r = getFileReader(V.MANIFEST, false)
		local line = r and r:readLine()
		while line do
			local sc, sh, de = string.match(line, "^part menu: (%d+) screens, (%d+) shots, (%d+) defects")
			if sc then screens, shots, defects = screens + tonumber(sc), shots + tonumber(sh), defects + tonumber(de) end
			line = r:readLine()
		end
		if r then r:close() end
	end)
	if V.settled then screens, shots, defects = screens + 1, shots + V.settled.shots, defects + V.settled.defects end
	return string.format("ui_tour = %d screens, %d shots, %d defects", screens, shots, defects)
end

function V.running() return tour ~= nil end
