-- Test Ground 1.13.20: the end-of-run screen. A panel with the run's key numbers (the save tested, the
-- frame rate, the stutters, a line per step) and a countdown to closing the game, with a Pause button.
-- Shown by Runner's finish through T.endScreen(summary, plan). Not shown in an unattended Autorun run
-- (T.trusted) unless the flag says endscreen = 1; endscreen = off never shows it. The closing countdown
-- (30 s, or the plan's seconds) runs for Benchmark Save, menu starts and plans that set it; a run started by
-- a command (Bridge) gets the screen without it.
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "TestGround/Core"
local TG = TestGroundInternal
local T = TG.T
if TG.loaded.EndScreen then return end
TG.loaded.EndScreen = true

local FONT, SMALL = UIFont.Medium, UIFont.Small
local MAX_ROWS = 14
local WHITE, GREY, AMBER = { 1, 1, 1 }, { 0.65, 0.65, 0.65 }, { 0.95, 0.75, 0.3 }

TestGroundEndScreen = ISPanel:derive("TestGroundEndScreen")

-- 1.13.28: lines are wrapped to the panel's width and spaced by the font's height (at 2560x1440 the stats line
-- ran past the right edge and the fixed spacing was tight)
local function measure(t)
	local ok, w = pcall(function() return getTextManager():MeasureStringX(SMALL, t) end)
	return ok and w or string.len(t) * 7
end
local function lineHeight()
	local ok, h = pcall(function() return getTextManager():getFontHeight(SMALL) end)
	return math.max(18, ((ok and tonumber(h)) or 14) + 4)
end
local function wrap(text, maxW)
	local lines, cur = {}, ""
	for word in string.gmatch(text, "%S+") do
		local try = cur == "" and word or (cur .. " " .. word)
		if cur ~= "" and measure(try) > maxW then lines[#lines + 1] = cur; cur = word else cur = try end
	end
	if cur ~= "" then lines[#lines + 1] = cur end
	return lines
end

function TestGroundEndScreen:new(sum, seconds)
	local rows = math.min(MAX_ROWS, #sum.rows)
	local w, lh = 620, lineHeight()
	local head = {}   -- { text, colour } wrapped to the panel
	local function add(text, c) for _, l in ipairs(wrap(text, w - 40)) do head[#head + 1] = { l, c } end end
	add("Save tested: " .. tostring(sum.save) .. (sum.copyOf and "  (run in a throwaway copy)" or ""), AMBER)
	add(string.format("%d steps, %.0f s, %d frames", #sum.rows, sum.seconds, sum.frames), GREY)
	add(string.format("%.1f fps on average, %.1f ms a frame, worst step p99 %d ms, worst frame %d ms", sum.fps, sum.mean, sum.p99, sum.worst), WHITE)
	add(string.format("%d frames over 33 ms, %d hitches of 100 ms or more", sum.over33, sum.over100), WHITE)
	-- 1.13.30 (UI check, 1280x720): only as many step rows as fit on the screen; the rest are counted in one line
	local fixed = 50 + #head * lh + 8 + lh + 2 * lh + 50   -- the bottom 2 * lh + 50 holds the countdown line and the buttons
	local sh = 1080
	pcall(function() sh = getCore():getScreenHeight() end)
	rows = math.max(math.min(3, rows), math.min(rows, math.floor((sh - 40 - fixed - lh) / lh)))
	local h = fixed + rows * lh + (#sum.rows > rows and lh or 0)
	local o = ISPanel.new(self, (getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h)
	o.sum, o.rowsShown, o.head, o.lh = sum, rows, head, lh
	o.backgroundColor = { r = 0.04, g = 0.05, b = 0.07, a = 0.96 }
	o.borderColor = { r = 0.45, g = 0.6, b = 0.85, a = 0.9 }
	o.moveWithMouse = true
	o.left = seconds                     -- nil: no countdown
	o.lastMs = getTimestampMs()
	o.paused = false
	-- 1.13.30: the first end screen of a session checks its own layout (console and TestGround_uicheck.txt only)
	if TestGroundUICheck then TestGroundUICheck.selfCheck(o, "end_screen", { { "getTextManager", "MeasureStringX" }, { "getCore", "quitToDesktop" } }) end
	return o
end

-- 1.13.33 (PC UI tour of 1.13.32, 2560x1440): "Resume countdown" needed 172 px in a 160 px button. Each button is
-- as wide as its longest label plus 12 px a side, as tall as the font plus 8, and the countdown line sits above them.
local function btnW(...)
	local w = 0
	for _, t in ipairs({ ... }) do w = math.max(w, measure(t)) end
	return math.max(100, w + 24)
end
function TestGroundEndScreen:buttonRow()
	local fh = lineHeight() - 4
	local bh = math.max(26, fh + 8)
	return self.height - 12 - bh, bh, fh
end
function TestGroundEndScreen:createChildren()
	local y, bh = self:buttonRow()
	local bwP, bwC, bwK = btnW("Pause countdown", "Resume countdown"), btnW("Close game now", "Close game"), btnW("Keep playing")
	self.pauseBtn = ISButton:new(20, y, bwP, bh, "Pause countdown", self, TestGroundEndScreen.onPause)
	self.pauseBtn:initialise(); self.pauseBtn:instantiate(); self:addChild(self.pauseBtn)
	self.closeBtn = ISButton:new(20 + bwP + 10, y, bwC, bh, "Close game now", self, TestGroundEndScreen.onCloseGame)
	self.closeBtn:initialise(); self.closeBtn:instantiate(); self:addChild(self.closeBtn)
	self.keepBtn = ISButton:new(self.width - bwK - 20, y, bwK, bh, "Keep playing", self, TestGroundEndScreen.onKeep)
	self.keepBtn:initialise(); self.keepBtn:instantiate(); self:addChild(self.keepBtn)
	if not self.left then self.pauseBtn:setVisible(false); self.closeBtn:setTitle("Close game") end
end

function TestGroundEndScreen:onPause()
	self.paused = not self.paused
	self.pauseBtn:setTitle(self.paused and "Resume countdown" or "Pause countdown")
end
function TestGroundEndScreen:onKeep() self:setVisible(false); self:removeFromUIManager() end
function TestGroundEndScreen:onCloseGame()
	self:onKeep()
	pcall(function() getCore():quitToDesktop() end)
end

function TestGroundEndScreen:line(text, x, y, c, font)
	self:drawText(text, x, y, c[1], c[2], c[3], 1, font or SMALL)
end

function TestGroundEndScreen:prerender()
	ISPanel.prerender(self)
	local now = getTimestampMs()
	if self.left and not self.paused then
		self.left = self.left - (now - self.lastMs) / 1000
		if self.left <= 0 then self.left = 0; self:onCloseGame(); return end
	end
	self.lastMs = now
end

function TestGroundEndScreen:render()
	local s, lh = self.sum, self.lh or 18
	local x, y = 20, 12
	self:line("Test Ground run finished" .. (s.stopped and (" (" .. tostring(s.stopped) .. ")") or ""), x, y, WHITE, FONT); y = y + 38
	for _, h in ipairs(self.head or {}) do self:line(h[1], x, y, h[2]); y = y + lh end
	y = y + 8
	self:line("Test", x, y, GREY); self:line("fps", 420, y, GREY); self:line("p99 ms", 480, y, GREY); self:line("hitches", 550, y, GREY); y = y + lh
	for i = 1, self.rowsShown do
		local e = s.rows[i]
		local nm = e.name
		local tag = e.skipped and "  (skipped)" or ""
		-- the name is cut to the column before the numbers; the "(skipped)" tag is kept (1.13.29)
		if measure(nm .. tag) > 390 then
			while string.len(nm) > 1 and measure(nm .. "." .. tag) > 390 do nm = string.sub(nm, 1, string.len(nm) - 1) end
			while string.len(nm) > 1 and string.byte(nm, string.len(nm)) >= 128 do nm = string.sub(nm, 1, string.len(nm) - 1) end   -- not inside a multi-byte character
			nm = nm .. "."
		end
		nm = nm .. tag
		if e.skipped then
			self:line(nm, x, y, GREY)
		else
			local c = e.f.over100 > 0 and AMBER or WHITE
			self:line(nm, x, y, c)
			self:line(string.format("%.1f", e.f.fps), 420, y, c); self:line(tostring(e.f.p99), 480, y, c); self:line(tostring(e.f.over100), 550, y, c)
		end
		y = y + lh
	end
	if #s.rows > self.rowsShown then self:line(string.format("... and %d more steps in the report", #s.rows - self.rowsShown), x, y, GREY); y = y + lh end
	if self.left then
		local txt = self.paused and "Countdown paused" or string.format("Closing the game in %d s", math.ceil(self.left))
		local by, _, fh = self:buttonRow()
		self:line(txt, x, by - 6 - fh, self.paused and AMBER or WHITE)
	end
end

function T.endScreen(sum, plan)
	local e = plan and plan.endscreen
	if e == false then return end
	if e == nil and T.trusted and not T.wantEndScreen then return end
	if #sum.rows == 0 then return end
	-- 1.13.21 (review of 1.13.20): the game is closed by the countdown only when the run asks for it: a
	-- plan's endscreen = <seconds>, Benchmark Save, or a run started from Test Ground's own menu. A run
	-- started by a command (Bridge) shows the screen with no countdown.
	local seconds
	if e ~= nil then seconds = e > 0 and e or nil
	elseif T.wantEndScreen or not T.commandStart then seconds = 30 end
	T.commandStart = nil
	local ok, err = pcall(function()
		local w = TestGroundEndScreen:new(sum, seconds)
		w:initialise(); w:instantiate(); w:addToUIManager(); w:bringToTop()
	end)
	if not ok then print("[TestGround] end screen failed: " .. tostring(err)) end
end
