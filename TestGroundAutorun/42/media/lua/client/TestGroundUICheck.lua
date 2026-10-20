--
-- Test Ground UI check (Autorun 1.5.9, dev tool).
--
-- Measures a live window with the game's own text manager and logs layout defects by name, so most
-- layout bugs are caught with no screenshot (design: test-ground/docs/UI-CHECKS.md):
--   TEXT_WIDE    a label wider than its control, or drawn text past its window's edge
--   ROW_SHORT    list rows or text lines closer than the font's height
--   OUTSIDE      a control (or drawn text) not inside its window
--   OFF_SCREEN   a window not inside the screen
--   OVERLAP      two controls, or two drawn texts, on top of each other
--   RENDER_ERROR render() failed in the probe frame
--   API_MISSING  a game call the window needs is not in this build
--   TIGHT        (warning) a button label or list row with under 10% spare width
--   GLYPH_MISSING (warning) characters the font has no glyph for: the game draws each as "?" (1.1.0)
-- 1.1.0 (PC tour of 1.13.30): widths count a missing glyph as the "?" the game draws (MeasureStringX gives it
-- 0 px, so a row with Chinese characters measured 679 px and was cut at 691); text drawn in prerender() is
-- recorded too (ISModalDialog draws its text there); a list row's room ends where the list clips it
-- (ISScrollingListBox: the scroll bar's x + 3); text with "\n" is measured line by line.
-- Use: U.arm(win, "end_screen/countdown", { needs = {...} }); after one frame has been drawn,
-- U.evaluate(win) returns the defects and writes them to the console and Zomboid/Lua/TestGround_uicheck.txt.
-- U.checkText(name, text, font, room) checks text drawn without a window (the run banner).
-- Every number comes from the game's resolution setting at the time of the check.

if TestGroundUICheck then return end
TestGroundUICheck = { VERSION = "1.2.0", FILE = "TestGround_uicheck.txt", METRICS = "TestGround_fontmetrics.txt" }
local U = TestGroundUICheck

U.BUTTON_PAD = 6      -- px each side of a button label
U.LIST_PAD = 15       -- px left of a list row's text (ISScrollingListBox draws at 15)
U.TEXT_MARGIN = 4     -- drawn text must end this far inside its window
U.TIGHT = 0.10
U.OVERLAP_PX = 3
-- 1.2.0 (PC UI tour of 1.5.11): 20% of the smaller font, not 15%: a 33 px title 5 px into the line under it was
-- reported and looked fine (a font's height includes room under the letters); rows 18 px apart in a 26 px font
-- (8 px, 31%) are still reported
U.OVERLAP_SHARE = 0.20
U.SAME_CODE_MAX = 5   -- per window and code; the rest are counted in one line

local function say(s) print("[TestGround] " .. s) end

function U.screen()
	local w, h = 0, 0
	pcall(function() w, h = getCore():getScreenWidth(), getCore():getScreenHeight() end)
	return w, h
end
function U.measure(font, text)
	local ok, w = pcall(function() return getTextManager():MeasureStringX(font, text) end)
	return (ok and tonumber(w)) or string.len(text) * 7
end
-- the width the game draws: like U.measure, but each character the font has no glyph for counts as the "?"
-- the game draws in its place. Returns the width and how many characters had no glyph. Works on Kahlua's
-- strings (one code per character) and on plain Lua's UTF-8 bytes (the mocks).
function U.textWidth(font, text)
	text = tostring(text or "")
	local w = U.measure(font, text)
	local i, n, missing = 1, string.len(text), 0
	while i <= n do
		local c = string.byte(text, i)
		local j = i
		if c >= 192 and c < 256 then   -- a UTF-8 lead byte: the character runs on over its continuation bytes
			while j < n do
				local d = string.byte(text, j + 1)
				if d >= 128 and d < 192 then j = j + 1 else break end
			end
		end
		if c >= 128 and U.measure(font, string.sub(text, i, j)) <= 0 then missing = missing + 1 end
		i = j + 1
	end
	if missing > 0 then w = w + missing * U.measure(font, "?") end
	return w, missing
end

function U.fontHeight(font)
	local ok, h = pcall(function() return getTextManager():getFontHeight(font) end)
	return (ok and tonumber(h)) or 14
end

-- 1.1.0 (review of 1.5.9): the file is trimmed to its last U.KEEP lines the first time a session writes to it
U.KEEP = 300
local function trimOnce()
	if U.trimmed then return end
	U.trimmed = true
	pcall(function()
		local r = getFileReader(U.FILE, false)
		if not r then return end
		local all, line = {}, r:readLine()
		while line do all[#all + 1] = line; line = r:readLine() end
		r:close()
		if #all <= U.KEEP * 2 then return end
		local w = getFileWriter(U.FILE, true, false)
		w:writeln(string.format("(trimmed: the %d lines before these were dropped)", #all - U.KEEP))
		for i = #all - U.KEEP + 1, #all do w:writeln(all[i]) end
		w:close()
	end)
end
local function append(lines)
	trimOnce()
	pcall(function()
		local w = getFileWriter(U.FILE, true, true)
		for _, l in ipairs(lines) do w:writeln(l) end
		w:close()
	end)
end
-- a new check file for a tour (the tour calls this once at its start)
function U.reset(header)
	U.trimmed = true
	pcall(function()
		local w = getFileWriter(U.FILE, true, false)
		local sw, sh = U.screen()
		w:writeln(string.format("ui check %s, screen %dx%d%s", U.VERSION, sw, sh, header and (", " .. header) or ""))
		w:close()
	end)
end

local function cut(s) s = tostring(s or ""); return string.len(s) > 60 and (string.sub(s, 1, 57) .. "...") or s end

U.stats = { windows = 0, defects = 0 }
function U.count(n) U.stats.windows = U.stats.windows + 1; U.stats.defects = U.stats.defects + n end

-- ---------------------------------------------------------------------------------------------
-- The probe frame: the window's own drawText calls are recorded for one render
local DRAWS = { "drawText", "drawTextCentre", "drawTextRight" }

function U.arm(win, name, opts)
	if not win then return false end
	win.tgUICheck = { name = name, opts = opts or {}, texts = {}, frames = 0 }
	local probe = win.tgUICheck
	for _, d in ipairs(DRAWS) do
		local orig = win[d]
		win[d] = function(self, text, x, y, r, g, b, a, font)
			if probe.recording then
				probe.texts[#probe.texts + 1] = { kind = d, text = tostring(text), x = x, y = y, font = font or UIFont.Small }
			end
			return orig(self, text, x, y, r, g, b, a, font)
		end
	end
	-- 1.1.0: prerender too (ISModalDialog draws its text there); the probe frame is the first render after it
	local origPre, origRender = win.prerender, win.render
	win.prerender = function(self)
		if probe.frames > 0 then return origPre(self) end
		probe.recording = true
		local ok, err = pcall(origPre, self)
		probe.recording = false
		if not ok then probe.renderError = tostring(err) end
	end
	win.render = function(self)
		if probe.frames > 0 then return origRender(self) end
		probe.recording = true
		local ok, err = pcall(origRender, self)
		probe.recording = false
		probe.frames = 1
		if not ok then probe.renderError = probe.renderError or tostring(err) end
	end
	return true
end

function U.ready(win) return win and win.tgUICheck and win.tgUICheck.frames > 0 end

-- ---------------------------------------------------------------------------------------------
local function visible(el)
	local ok, v = pcall(function() return el:isVisible() end)
	return not ok or v ~= false
end
local function rectOf(el) return { x = el.x or 0, y = el.y or 0, w = el.width or 0, h = el.height or 0 } end
local function inside(r, w, h) return r.x >= 0 and r.y >= 0 and r.x + r.w <= w + 0.5 and r.y + r.h <= h + 0.5 end
local function intersect(a, b) return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h end

-- the window's children in a stable order (by ID), visible ones only
function U.children(win)
	local list = {}
	for _, c in pairs(win.children or {}) do if visible(c) then list[#list + 1] = c end end
	table.sort(list, function(a, b) return tostring(a.ID or a.title or "") < tostring(b.ID or b.title or "") end)
	return list
end
local function elName(c, i)
	local n = c.tgName or c.title or c.Type or ("child" .. i)
	return string.gsub(tostring(n), "%s+", "_")
end
local function isList(c) return type(c.items) == "table" and c.itemheight ~= nil end
local function isButton(c) return c.title ~= nil and c.onclick ~= nil or c.Type == "ISButton" end

-- one java call per needed API, e.g. { "getCore", "quitToDesktop" } or { "getTextManager", "MeasureStringX" }
local function apiMissing(need)
	local g = need[1]
	local f = _G and _G[g] or nil
	if type(f) ~= "function" then return g end
	if not need[2] then return nil end
	local ok, m = pcall(function() local o = f(); return o and o[need[2]] end)
	if not ok or m == nil then return g .. "():" .. need[2] end
	return nil
end

function U.evaluate(win)
	local probe = win and win.tgUICheck
	if not probe then return nil end
	local name, d, warn = probe.name, {}, {}
	local seen = {}
	local function defect(code, el, msg)
		seen[code] = (seen[code] or 0) + 1
		if seen[code] <= U.SAME_CODE_MAX then d[#d + 1] = string.format("UICHECK DEFECT %s/%s %s %s", name, el, code, msg) end
	end
	local function warning(code, el, msg) warn[#warn + 1] = string.format("UICHECK WARN %s/%s %s %s", name, el, code, msg) end
	local sw, sh = U.screen()
	local W, H = win.width or 0, win.height or 0
	local ax, ay = win.x or 0, win.y or 0
	pcall(function() ax, ay = win:getAbsoluteX(), win:getAbsoluteY() end)

	if not inside({ x = ax, y = ay, w = W, h = H }, sw, sh) then
		defect("OFF_SCREEN", "window", string.format("%dx%d at %d,%d on a %dx%d screen", W, H, ax, ay, sw, sh))
	end
	if probe.renderError then defect("RENDER_ERROR", "window", cut(probe.renderError)) end
	for _, need in ipairs(probe.opts.needs or {}) do
		local miss = apiMissing(need)
		if miss then defect("API_MISSING", "window", miss .. " is not in this build") end
	end

	-- text drawn by the window itself
	local boxes = {}
	local lines = {}   -- 1.1.0: one entry per line of a text with "\n"
	for i, t in ipairs(probe.texts) do
		local k, fh = 0, U.fontHeight(t.font)
		for part in string.gmatch(t.text .. "\n", "([^\n]*)\n") do
			lines[#lines + 1] = { kind = t.kind, text = part, x = t.x, y = t.y + k * fh, font = t.font, label = "text" .. i .. (k > 0 and ("." .. (k + 1)) or "") }
			k = k + 1
		end
	end
	local glyphs = 0
	for _, t in ipairs(lines) do
		local tw, miss = U.textWidth(t.font, t.text)
		local fh = U.fontHeight(t.font)
		glyphs = glyphs + miss
		local left = t.x
		if t.kind == "drawTextCentre" then left = t.x - tw / 2 elseif t.kind == "drawTextRight" then left = t.x - tw end
		local b = { x = left, y = t.y, w = tw, h = fh, text = t.text }
		local label = t.label
		if t.text ~= "" then
			if left < 0 or left + tw > W - U.TEXT_MARGIN then
				defect("TEXT_WIDE", label, string.format("\"%s\" ends at %d px in a %d px window", cut(t.text), math.floor(left + tw), W))
			elseif t.y < 0 or t.y + fh > H then
				defect("OUTSIDE", label, string.format("\"%s\" at y %d-%d in a %d px window", cut(t.text), t.y, t.y + fh, H))
			end
			boxes[#boxes + 1] = b
		end
	end
	-- two lines overlap when they share more than U.OVERLAP_PX and U.OVERLAP_SHARE of the smaller font's height: a font's
	-- height includes its line gap, so a line 1 or 2 px into the next one's box does not touch its letters
	local function textClash(a, b)
		if not (a.x < b.x + b.w and b.x < a.x + a.w) then return false end
		local over = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
		return over > U.OVERLAP_PX and over >= U.OVERLAP_SHARE * math.min(a.h, b.h)
	end
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, b = boxes[i], boxes[j]
			if textClash(a, b) then
				local code = math.abs(a.x - b.x) < 2 and "ROW_SHORT" or "OVERLAP"
				defect(code, "text", string.format("\"%s\" and \"%s\" overlap (y %d and %d, font %d px)", cut(a.text), cut(b.text), a.y, b.y, a.h))
			end
		end
	end

	-- child controls
	local kids = U.children(win)
	for i, c in ipairs(kids) do
		local r, el = rectOf(c), elName(c, i)
		if not inside(r, W, H) then
			defect("OUTSIDE", el, string.format("%dx%d at %d,%d in a %dx%d window", r.w, r.h, r.x, r.y, W, H))
		end
		if isList(c) then
			local font = c.font or UIFont.Small
			local fh = U.fontHeight(font)
			if (c.itemheight or 0) < fh + 4 then
				defect("ROW_SHORT", el, string.format("rows %d px for a %d px font", c.itemheight or 0, fh))
			end
			-- 1.1.0: the list clips its rows at the scroll bar's x + 3 (ISScrollingListBox.prerender's stencil)
			local edge = r.w - 1
			if c.vscroll then edge = (c.vscroll.x and (c.vscroll.x + 3)) or (r.w - (c.vscroll.width or 0)) end
			local room = edge - U.LIST_PAD
			local worst = 0
			for k, it in ipairs(c.items) do
				local tw, miss = U.textWidth(font, tostring(it.text or ""))
				glyphs = glyphs + miss
				if tw > room then defect("TEXT_WIDE", el, string.format("row %d \"%s\" is %d px in %d px", k, cut(it.text), tw, room))
				elseif tw > worst then worst = tw end
			end
			if worst > 0 and room - worst < room * U.TIGHT then warning("TIGHT", el, string.format("widest row %d px in %d px", worst, room)) end
		elseif isButton(c) and c.title then
			local font = c.font or UIFont.Small
			local tw, fh = U.textWidth(font, tostring(c.title)), U.fontHeight(font)
			local need = tw + 2 * U.BUTTON_PAD
			if need > r.w then
				defect("TEXT_WIDE", el, string.format("label \"%s\" needs %d px, button is %d px", cut(c.title), need, r.w))
			elseif r.w - tw < r.w * U.TIGHT then
				warning("TIGHT", el, string.format("label %d px in a %d px button", tw, r.w))
			end
			if fh > r.h + U.OVERLAP_PX then defect("ROW_SHORT", el, string.format("label %d px high in a %d px button", fh, r.h)) end
		end
	end
	if glyphs > 0 then warning("GLYPH_MISSING", "window", string.format("%d characters have no glyph in this font and show as \"?\"", glyphs)) end

	-- drawn text on top of a control (a footer over the list, a countdown over the buttons)
	for _, b in ipairs(boxes) do
		for i, c in ipairs(kids) do
			if textClash(b, rectOf(c)) then
				defect("OVERLAP", elName(c, i), string.format("text \"%s\" (y %d-%d) is drawn over it", cut(b.text), b.y, b.y + b.h))
			end
		end
	end
	for i = 1, #kids do
		for j = i + 1, #kids do
			if intersect(rectOf(kids[i]), rectOf(kids[j])) then
				defect("OVERLAP", elName(kids[i], i), "overlaps " .. elName(kids[j], j))
			end
		end
	end
	for code, n in pairs(seen) do
		if n > U.SAME_CODE_MAX then d[#d + 1] = string.format("UICHECK DEFECT %s/window %s and %d more like these", name, code, n - U.SAME_CODE_MAX) end
	end
	local summary = string.format("UICHECK %s: %d defects, %d warnings (%d texts, %d controls, window %dx%d, screen %dx%d)",
		name, #d, #warn, #probe.texts, #kids, W, H, sw, sh)
	local lines = {}
	for _, l in ipairs(d) do lines[#lines + 1] = l end
	for _, l in ipairs(warn) do lines[#lines + 1] = l end
	lines[#lines + 1] = summary
	for _, l in ipairs(lines) do say(l) end
	append(lines)
	U.count(#d)
	return { name = name, defects = d, warnings = warn, summary = summary, rect = { x = ax, y = ay, w = W, h = H }, kids = kids }
end

-- one control on its own (the main menu's Benchmark Save button): its label and its place on the screen
function U.checkControl(name, el)
	local d, warn = {}, {}
	local sw, sh = U.screen()
	local ax, ay = el.x or 0, el.y or 0
	pcall(function() ax, ay = el:getAbsoluteX(), el:getAbsoluteY() end)
	local r = { x = ax, y = ay, w = el.width or 0, h = el.height or 0 }
	if not inside(r, sw, sh) then d[#d + 1] = string.format("UICHECK DEFECT %s OFF_SCREEN %dx%d at %d,%d on a %dx%d screen", name, r.w, r.h, r.x, r.y, sw, sh) end
	if el.title then
		local font = el.font or UIFont.Small
		local tw, fh = U.textWidth(font, tostring(el.title)), U.fontHeight(font)
		if tw + 2 * U.BUTTON_PAD > r.w then d[#d + 1] = string.format("UICHECK DEFECT %s TEXT_WIDE label \"%s\" needs %d px, button is %d px", name, cut(el.title), tw + 2 * U.BUTTON_PAD, r.w)
		elseif r.w - tw < r.w * U.TIGHT then warn[#warn + 1] = string.format("UICHECK WARN %s TIGHT label %d px in a %d px button", name, tw, r.w) end
		if fh > r.h + U.OVERLAP_PX then d[#d + 1] = string.format("UICHECK DEFECT %s ROW_SHORT label %d px high in a %d px button", name, fh, r.h) end
	end
	local lines = {}
	for _, l in ipairs(d) do lines[#lines + 1] = l end
	for _, l in ipairs(warn) do lines[#lines + 1] = l end
	lines[#lines + 1] = string.format("UICHECK %s: %d defects, %d warnings (control %dx%d, screen %dx%d)", name, #d, #warn, r.w, r.h, sw, sh)
	for _, l in ipairs(lines) do say(l) end
	append(lines)
	U.count(#d)
	return { name = name, defects = d, warnings = warn, rect = r, kids = {} }
end

-- text drawn straight to the screen (the run banner): centred at the screen's middle, room = screen width - 2 margins
function U.checkText(name, text, font, centreX)
	local sw = U.screen()
	local tw = U.textWidth(font, tostring(text))
	local cx = centreX or sw / 2
	local d = {}
	if cx - tw / 2 < U.TEXT_MARGIN or cx + tw / 2 > sw - U.TEXT_MARGIN then
		d[1] = string.format("UICHECK DEFECT %s TEXT_WIDE \"%s\" is %d px on a %d px screen", name, cut(text), tw, sw)
	end
	local lines = {}
	for _, l in ipairs(d) do lines[#lines + 1] = l end
	lines[#lines + 1] = string.format("UICHECK %s: %d defects (text %d px, screen %d px)", name, #d, tw, sw)
	for _, l in ipairs(lines) do say(l) end
	append(lines)
	return d, tw
end

-- the first time a Test Ground window opens in normal use it checks itself and only logs (no file
-- reset, nothing on screen). Call from the window's constructor: U.selfCheck(o, "end_screen", needs).
function U.selfCheck(win, name, needs)
	if U.quiet then return end   -- the UI tour checks its own screens
	U.seen = U.seen or {}
	if U.seen[name] then return end
	U.seen[name] = true
	U.arm(win, name, { needs = needs })
	U.pending = U.pending or {}
	U.pending[#U.pending + 1] = win
end
function U.tickPending()
	if not U.pending then return end
	local keep = {}
	for _, w in ipairs(U.pending) do
		if U.ready(w) then
			local res = U.evaluate(w)
			-- 1.2.0: Autorun adds a check that ran after its done file was written to that file
			if res and TestGroundAutorun and TestGroundAutorun.doneWritten then
				pcall(function()
					local f = getFileWriter("TestGround_autorun_done.txt", true, true)
					f:writeln(string.format("ui_check_late = %s: %d defects, %d warnings (now %d windows, %d defects)", res.name, #res.defects, #res.warnings, U.stats.windows, U.stats.defects))
					f:close()
				end)
			end
		else keep[#keep + 1] = w end
	end
	U.pending = #keep > 0 and keep or nil
end
pcall(function() Events.OnTick.Add(U.tickPending) end)
pcall(function() Events.OnFETick.Add(U.tickPending) end)

-- the real font widths for the cloud mocks: one line per font and character
function U.dumpFontMetrics()
	local sw, sh = U.screen()
	local lines = { string.format("font metrics, screen %dx%d", sw, sh) }
	local fonts = { "Small", "Medium", "Large", "NewSmall", "Code" }
	for _, fname in ipairs(fonts) do
		local font = UIFont[fname]
		if font then
			lines[#lines + 1] = string.format("%s height %d", fname, U.fontHeight(font))
			for c = 32, 126 do
				lines[#lines + 1] = string.format("%s %d %d", fname, c, U.measure(font, string.char(c)))
			end
			-- a whole sentence too, so the mocks can see whether widths simply add up
			-- 1.1.0: whether a character the font lacks measures 0 px (the picker's Chinese row was drawn as "????")
			lines[#lines + 1] = string.format("%s glyph-probe cjk %d cyrillic %d question %d", fname,
				U.measure(font, "\228\184\173"), U.measure(font, "\208\154"), U.measure(font, "?"))
			local s = "Start full benchmark (about 15 min)"
			lines[#lines + 1] = string.format("%s sentence %d %s", fname, U.measure(font, s), s)
		end
	end
	pcall(function()
		local w = getFileWriter(U.METRICS, true, false)
		for _, l in ipairs(lines) do w:writeln(l) end
		w:close()
	end)
	say("UICHECK font metrics written to Zomboid/Lua/" .. U.METRICS)
end
