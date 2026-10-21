-- Test Ground 1.13.43 (Autorun engine 1.5.22; moved here from the Autorun mod): "Benchmark Save" on the main menu. A button opens a window with your saves
-- and "New vanilla save". The run happens in a throwaway copy (made by Test Ground Capture's copySave),
-- or in a new vanilla save, never in the save you chose; the copy is deleted the next time the main
-- menu shows. The report and the end screen name the save you chose. The fixed baseline plan runs.
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "TestGroundAutorun"

local A = TestGroundAutorun
if A.benchLoaded then return end
A.benchLoaded = true

local VANILLA = "New vanilla save"
local function say(s) print("[TestGroundAutorun] benchmark: " .. s) end

-- every save as { mode, name }, newest first. 1.5.1 (review of 1.5.0): from getFullSaveDirectoryTable(), which
-- lists the Saves folder; getSaveDirectory(mode) takes a path, not a mode name. An entry may be a File of a
-- save (its folder's parent is the game mode) or a "Mode/Name" string; anything else is skipped.
local function savesList()
	local out, seen = {}, {}
	-- 1.5.3: only the recorded copy is hidden (not every save whose name looks like one)
	local copyName = A.benchCopyName()
	local function add(mode, name, t)
		-- the harness's own scratch copies (named "... - PerfTest") are not saves to benchmark
		if mode and name and A.BENCH_MODES[mode] and name ~= copyName and not seen[mode .. "/" .. name] then
			seen[mode .. "/" .. name] = true
			-- 1.5.3: marked, not hidden: a copy left by a crash, or the harness's own test copy
			local mark = (A.isBenchName(name) and "old benchmark copy") or (string.find(name, " %- PerfTest$") and "test copy") or nil
			out[#out + 1] = { mode = mode, name = name, t = t or 0, mark = mark }
		end
	end
	pcall(function()
		local tbl = getFullSaveDirectoryTable()
		local function take(e)
			if type(e) == "string" then
				local mode, name = string.match(e, "^([^/\\]+)[/\\](.+)$")
				add(mode, name)
			elseif e ~= nil then
				pcall(function()
					local name = e:getName()
					local parent = e:getParentFile()
					local mode = parent and parent:getName()
					local t = 0
					pcall(function() t = e:lastModified() end)
					add(mode, name, t)
				end)
			end
		end
		if tbl.size and type(tbl.size) == "function" and tbl:size() > 0 then
			for i = 1, tbl:size() do take(tbl:get(i - 1) or tbl:rawget(i)) end
		else
			for _, e in ipairs(tbl) do take(e) end
		end
	end)
	-- 1.5.9: the UI tour adds worst-case rows (long, multi-byte, marked, enough to scroll); never set otherwise
	for _, e in ipairs(A.benchFixtureRows or {}) do out[#out + 1] = e end
	table.sort(out, function(a, b) return a.t > b.t end)
	return out
end

local function stampName()
	local t = getTimestamp and getTimestamp() or os.time()
	return tostring(t)
end

TestGroundBenchWindow = ISPanel:derive("TestGroundBenchWindow")

-- 1.5.3: sizes come from the font height (at 2560x1440 the fixed 28 px rows left names on the divider lines)
local function fontH()
	local ok, h = pcall(function() return getTextManager():getFontHeight(UIFont.Small) end)
	return (ok and tonumber(h)) or 14
end

-- text broken into lines that fit width px, at spaces
local function wrapText(text, width)
	local function measure(t)
		-- 1.5.11: a character the font has no glyph for is drawn as "?" but measured as 0 px (PC tour of 1.5.9)
		if TestGroundUICheck and TestGroundUICheck.textWidth then return (TestGroundUICheck.textWidth(UIFont.Small, t)) end
		local ok, w = pcall(function() return getTextManager():MeasureStringX(UIFont.Small, t) end)
		return ok and w or string.len(t) * 7
	end
	local lines, cur = {}, ""
	for word in string.gmatch(text, "%S+") do
		local try = cur == "" and word or (cur .. " " .. word)
		if cur ~= "" and measure(try) > width then lines[#lines + 1] = cur; cur = word else cur = try end
	end
	if cur ~= "" then lines[#lines + 1] = cur end
	return lines
end

-- 1.5.8: a button is as wide as its label (measured) plus padding; the window widens to hold all three
local BTN_FULL, BTN_QUICK, BTN_CANCEL = "Start full benchmark (about 15 min)", "Quick test (about 5 min)", "Cancel"
local function btnW(text)
	local ok, w = pcall(function() return getTextManager():MeasureStringX(UIFont.Small, text) end)
	return math.max(80, ((ok and tonumber(w)) or string.len(text) * 7) + 32)
end

-- 1.5.12 (PC UI tour of 1.5.11): the intro sat at y 40 under a 33 px title drawn at y 12; it now starts below the title
local function introTop()
	local ok, h = pcall(function() return getTextManager():getFontHeight(UIFont.Medium) end)
	return 12 + ((ok and tonumber(h)) or 24) + 4
end

function TestGroundBenchWindow:new()
	local fh = fontH()
	local need = btnW(BTN_FULL) + btnW(BTN_QUICK) + btnW(BTN_CANCEL) + 2 * 10 + 40
	local w, h = math.max(760, need), math.max(460, 330 + fh * 8) + math.max(0, introTop() - 40)
	local o = ISPanel.new(self, (getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h)
	o.backgroundColor = { r = 0.04, g = 0.05, b = 0.07, a = 0.97 }
	o.borderColor = { r = 0.45, g = 0.6, b = 0.85, a = 0.9 }
	o.moveWithMouse = true
	o.note = ""
	return o
end

function TestGroundBenchWindow:createChildren()
	local fh = fontH()
	self.fh = fh
	self.footer = wrapText("The copy is deleted the next time this menu shows. The full test takes about 15 minutes, the quick one about 5; the results show at the end.", self.width - 40)
	self.intro = wrapText("Pick a save to test. The run happens in a throwaway copy of it; your save is not opened.", self.width - 40)
	local top = introTop() + fh * #self.intro + 12
	self.list = ISScrollingListBox:new(20, top, self.width - 40, self.height - 80 - fh * (#self.footer + 1) - top)
	self.list:initialise(); self.list:instantiate()
	self.list.itemheight = fh + 14
	self.list.font = UIFont.Small
	self.list.drawBorder = true
	self:addChild(self.list)
	self.list:addItem(VANILLA, { vanilla = true })
	-- 1.5.2: a long save name is cut to the row's width (with "...") and the game mode stays visible after it
	local maxW = self.list.width - 40
	local function measure(t)
		-- 1.5.11: a character the font has no glyph for is drawn as "?" but measured as 0 px (PC tour of 1.5.9)
		if TestGroundUICheck and TestGroundUICheck.textWidth then return (TestGroundUICheck.textWidth(UIFont.Small, t)) end
		local ok, w = pcall(function() return getTextManager():MeasureStringX(UIFont.Small, t) end)
		return ok and w or string.len(t) * 7
	end
	for _, s in ipairs(savesList()) do
		local tail = "   (" .. s.mode .. (s.mark and (", " .. s.mark) or "") .. ")"
		local nm = s.name
		if measure(nm .. tail) > maxW then
			-- 1.5.3: the longest prefix that fits, by bisection (a name of hundreds of characters took a pass per character)
			local lo, hi = 1, string.len(nm)
			while lo < hi do
				local mid = math.floor((lo + hi + 1) / 2)
				if measure(string.sub(nm, 1, mid) .. "..." .. tail) <= maxW then lo = mid else hi = mid - 1 end
			end
			nm = string.sub(nm, 1, lo)
			while string.len(nm) > 1 and string.byte(nm, string.len(nm)) >= 128 do nm = string.sub(nm, 1, string.len(nm) - 1) end   -- not inside a multi-byte character
			nm = nm .. "..."
		end
		self.list:addItem(nm .. tail, s)
	end
	self.list.selected = 1
	local bh, y = 26, self.height - 40
	local bwF, bwQ, bwC = btnW(BTN_FULL), btnW(BTN_QUICK), btnW(BTN_CANCEL)
	-- 1.5.6: two suites: the full baseline (about 15 minutes) and a quick one (about 5)
	self.startBtn = ISButton:new(20, y, bwF, bh, BTN_FULL, self, TestGroundBenchWindow.onStartFull)
	self.startBtn:initialise(); self.startBtn:instantiate(); self:addChild(self.startBtn)
	self.quickBtn = ISButton:new(20 + bwF + 10, y, bwQ, bh, BTN_QUICK, self, TestGroundBenchWindow.onStartQuick)
	self.quickBtn:initialise(); self.quickBtn:instantiate(); self:addChild(self.quickBtn)
	self.cancelBtn = ISButton:new(self.width - bwC - 20, y, bwC, bh, BTN_CANCEL, self, TestGroundBenchWindow.onCancel)
	self.cancelBtn:initialise(); self.cancelBtn:instantiate(); self:addChild(self.cancelBtn)
end

function TestGroundBenchWindow:onCancel() self:setVisible(false); self:removeFromUIManager(); A.benchWindow = nil end

function TestGroundBenchWindow:render()
	self:drawText("Benchmark Save", 20, 12, 1, 1, 1, 1, UIFont.Medium)
	for i, l in ipairs(self.intro or {}) do self:drawText(l, 20, introTop() + (i - 1) * (self.fh or 14), 0.75, 0.75, 0.75, 1, UIFont.Small) end
	local fh = self.fh or 14
	local y = self.height - 56 - fh * (#(self.footer or {}) + 1)
	for _, l in ipairs(self.footer or {}) do
		self:drawText(l, 20, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
		y = y + fh
	end
	if self.note ~= "" then self:drawText(self.note, 20, y + 2, 0.95, 0.5, 0.4, 1, UIFont.Small) end
end

local function cut(name, n)   -- at most n bytes, never inside a multi-byte character
	if string.len(name) <= n then return name end
	local c = string.sub(name, 1, n)
	while string.len(c) > 0 and string.byte(c, string.len(c)) >= 128 do c = string.sub(c, 1, string.len(c) - 1) end
	return c
end

local function flagLines(win, save, mode, origin, plan)
	plan = plan or "baseline"
	local lines = { "save = " .. save, "mode = " .. mode, "origin = " .. string.gsub(origin, "#", "_") }
	-- the copy keeps the original's mod list, which may lack the test mods: they are added to the copy's list
	-- 1.13.43: Test Ground alone is enough; the other test mods are added to the copy's list only when they are installed
	-- (a missing one stops the load), so a PC with Bridge, Autorun and Capture keeps them in the copy as before
	local mods = { "TestGround" }
	for _, id in ipairs({ "TestGroundBridge", "TestGroundAutorun", "TestGroundCapture" }) do
		if A.modId(id) then mods[#mods + 1] = id end
	end
	for _, l in ipairs({ "plan = " .. plan, "timeout = " .. (plan == "quick" and 600 or 1500), "start = westpoint", "quit = 0", "endscreen = 1", "delay = 20",
		"addmods = " .. table.concat(mods, ",") }) do lines[#lines + 1] = l end
	return lines
end

function TestGroundBenchWindow:begin(lines)
	A.writeFlagLines(lines)
	A.benchBusy = true
	self.copying = nil
	self:onCancel()
	A.kick()
end

function TestGroundBenchWindow:onStartFull() self:onStart("baseline") end
function TestGroundBenchWindow:onStartQuick() self:onStart("quick") end

function TestGroundBenchWindow:onStart(plan)
	plan = (plan == "quick") and "quick" or "baseline"
	if self.copying then return end
	-- 1.5.3: a busy mark with no flag behind it is stale; otherwise say why nothing starts
	if A.benchBusy and not A.readFlag() then A.benchBusy = false end
	if A.benchBusy then self.note = "A benchmark run is already starting; wait for it, or restart the game if it is stuck."; return end
	local row = self.list.items[self.list.selected]
	local pick = row and row.item
	if not pick then self.note = "Pick a save first."; return end
	local stamp = stampName()
	if pick.vanilla then
		local name = A.BENCH_PREFIX .. "Vanilla " .. stamp
		-- 1.5.2: the game makes the folder under its own spelling of the name (spaces become underscores);
		-- the record, the new save and the load all use that spelling, so the load finds the save
		if sanitizeWorldName then
			local okS, clean = pcall(sanitizeWorldName, name)
			if okS and clean and tostring(clean) ~= "" then name = tostring(clean) end
		end
		A.recordBench("Sandbox", name, VANILLA)
		say("starting on " .. VANILLA)
		local lines = flagLines(self, name, "Sandbox", VANILLA, plan)
		table.insert(lines, 1, "newsave = " .. name)
		return self:begin(lines)
	end
	if not (TGCapture and TGCapture.copySaveStart) then
		self.note = "Copying a save needs the Test Ground Capture mod (1.0.7 or later); it isn't loaded. \"New vanilla save\" works without it."
		return
	end
	local copy = string.gsub(A.BENCH_PREFIX .. cut(pick.name, 40) .. " " .. stamp, "#", "_")
	local okC, err = pcall(function() return TGCapture.copySaveStart(pick.mode, pick.name, copy) end)
	if not okC or (err ~= nil and err ~= "") then
		self.note = "Could not copy: " .. tostring(err)
		say("copy not started: " .. tostring(err))
		return
	end
	A.recordBench(pick.mode, copy, pick.name)   -- recorded as soon as the copy starts, so a half-made one is cleaned up too
	self.copying = { mode = pick.mode, src = pick.name, copy = copy, nextPoll = 0, plan = plan }
	self.startBtn:setEnable(false)
	self.quickBtn:setEnable(false)
	self.cancelBtn:setEnable(false)
	say("copying " .. pick.name .. " to " .. copy)
end

function TestGroundBenchWindow:prerender()
	ISPanel.prerender(self)
	local c = self.copying
	if not c or getTimestampMs() < c.nextPoll then return end
	c.nextPoll = getTimestampMs() + 300
	local ok, st = pcall(function() return TGCapture.copySaveStatus() end)
	st = ok and tostring(st) or "failed: status unreadable"
	if st == "done" then
		say("copy done")
		self:begin(flagLines(self, c.copy, c.mode, c.src, c.plan))
	elseif string.sub(st, 1, 6) == "failed" or st == "idle" then
		self.note = "Could not copy: " .. st
		say(self.note)
		self.copying = nil
		self.startBtn:setEnable(true)
		self.quickBtn:setEnable(true)
		self.cancelBtn:setEnable(true)
	else
		self.note = "Copying the save for the test: " .. st
	end
end

-- the button on the main menu
local function showWindow()
	if A.benchWindow then return end
	local w = TestGroundBenchWindow:new()
	w:initialise(); w:instantiate(); w:addToUIManager(); w:bringToTop()
	A.benchWindow = w
	-- 1.5.9: the first time it opens, the window checks its own layout (console and TestGround_uicheck.txt only)
	if TestGroundUICheck then TestGroundUICheck.selfCheck(w, "picker", { { "getTextManager", "MeasureStringX" }, { "getFullSaveDirectoryTable" } }) end
	return w
end
A.showBenchWindow = function() showWindow(); return A.benchWindow end

local function addButton()
	A.benchBusy = false
	local ms = MainScreen and MainScreen.instance
	if not ms or ms.testGroundBenchBtn then return end
	local ok, err = pcall(function()
		local btn = ISButton:new(20, getCore():getScreenHeight() - 56, 170, 30, "Benchmark Save", ms, function() showWindow() end)
		btn:initialise(); btn:instantiate()
		btn.borderColor = { r = 0.45, g = 0.6, b = 0.85, a = 1 }
		ms:addChild(btn)
		btn.tgName = "benchmark_save"
		ms.testGroundBenchBtn = btn
	end)
	if not ok then say("could not add the menu button: " .. tostring(err)) end
end

Events.OnMainMenuEnter.Add(addButton)
if MainScreen and MainScreen.instance then addButton() end
