"""Mock test for the UI check and the UI tour (Autorun 1.5.12, Test Ground 1.13.33).

python3 -I test-ground/ui_mock_test.py [fontmetrics.txt]   # ends with "ALL OK"

Fake ISUI elements and a fake text manager run the real window code. Text widths come from
Zomboid/Lua/TestGround_fontmetrics.txt when one is given (the UI tour writes it on the PC); otherwise
from a profile for the user's 2560x1440 setting: Small 26 px high and widths that give the PC's picker
screenshot's two text lines within 3% (703 and 720 px, pz-picker3.png, 19 Oct); Medium and Large are guesses.
Part 1 replays tonight's five layout bugs from the old builds' own files (old/ next to this script,
or the ship zips) and expects each one named. Part 2 checks the current windows and the full tour.
"""
import os, sys, zipfile, io
from lupa import lua51

HERE = os.path.dirname(os.path.abspath(__file__))
ok = True
SKIP = False
def check(cond, msg):
    global ok
    if SKIP:
        return
    print(('ok   ' if cond else 'FAIL ') + msg)
    ok = ok and bool(cond)

def src(rel):
    return open(os.path.join(HERE, rel), encoding='utf-8').read()

def from_zip(zipname, member):
    for base in (HERE, os.path.join(HERE, '..')):
        p = os.path.join(base, zipname)
        if os.path.exists(p):
            with zipfile.ZipFile(p) as z:
                return z.read(member).decode('utf-8')
    return None

# --- text widths -------------------------------------------------------------------------------
METRICS = {}   # font -> {height, chars{code: w}}
SCREEN = (2560, 1440)
if len(sys.argv) > 1:
    for line in open(sys.argv[1], encoding='utf-8'):
        m = __import__('re').match(r'^font metrics, screen (\d+)x(\d+)', line)
        if m:
            SCREEN = (int(m.group(1)), int(m.group(2)))
        p = line.split()
        if len(p) >= 3 and p[1] == 'height':
            METRICS.setdefault(p[0], {'chars': {}})['height'] = int(p[2])
        elif len(p) == 3 and p[1].isdigit():
            METRICS.setdefault(p[0], {'chars': {}})['chars'][int(p[1])] = int(p[2])
        elif len(p) >= 4 and p[1] == 'sentence':
            METRICS.setdefault(p[0], {'chars': {}})['sentence'] = (int(p[2]), line.split(None, 3)[3].rstrip('\n'))
    # one character measured alone leaves out the spacing to the next one: the whole sentence says how much
    # (2560x1440 Small: the characters add up to 252 px, the sentence measures 290)
    for f, m in METRICS.items():
        if 'sentence' in m:
            real, text = m['sentence']
            alone = sum(m['chars'].get(ord(c), 0) for c in text)
            m['gap'] = (real - alone) / max(1, len(text) - 1)
    print('font widths from', sys.argv[1])
else:
    for font, (w, h) in {'Small': (9, 26), 'Medium': (13, 30), 'Large': (16, 40), 'NewSmall': (9, 26), 'Code': (9, 24)}.items():
        ch = {c: w for c in range(32, 127)}
        for c in range(65, 91): ch[c] = w + 2          # capitals wider
        for c in b' .,;:!|il\'': ch[c] = max(3, w // 2)
        ch[32] = (w * 2) // 3
        METRICS[font] = {'height': h, 'chars': ch}
    print('font widths from the 2560x1440 profile (Small measured on pz-picker3.png, Medium/Large guessed)')

def no_glyph(ch):
    # as on the PC (tour of 1.5.9): the fonts have Latin and Cyrillic, not CJK; a missing glyph measures 0 px
    return '\u2e80' <= ch <= '\u9fff'

def measure(font, text):
    m = METRICS.get(str(font), METRICS['Small'])
    w, avg = 0, m['chars'].get(ord('n'), 9)
    if isinstance(text, bytes):
        text = text.decode('utf-8', 'replace')
    for ch in str(text):
        if no_glyph(ch):
            continue
        w += m['chars'].get(ord(ch), avg + 1)   # Cyrillic and other glyphs the font has: about a letter
    n = sum(1 for ch in str(text) if not no_glyph(ch))
    return int(round(w + m.get('gap', 0) * max(0, n - 1)))

PRELUDE = r'''
next = nil
clock = 1792140000000
function getTimestampMs() return clock end
function getTimestamp() return math.floor(clock / 1000) end
SW, SH = py_screen_w, py_screen_h
UIFont = { Small = "Small", Medium = "Medium", Large = "Large", NewSmall = "NewSmall", Code = "Code" }
TM = { MeasureStringX = function(_, f, t) return py_measure(f, t) end, getFontHeight = function(_, f) return py_height(f) end,
       DrawStringCentre = function(_, f, x, y, t) DRAWN[#DRAWN + 1] = t end }
DRAWN = {}
function getTextManager() return TM end
QUIT = 0
CORE = { getScreenWidth = function() return SW end, getScreenHeight = function() return SH end,
         quitToDesktop = function() QUIT = QUIT + 1 end, quit = function() end, getOptionPauseOnFocusloss = function() return false end }
function getCore() return CORE end
FILES = {}
function getFileWriter(name, create, append)
  if not append then FILES[name] = {} end
  FILES[name] = FILES[name] or {}
  local t = FILES[name]
  return { writeln = function(_, l) t[#t+1] = l end, close = function() end }
end
function getFileReader(name)
  local t = FILES[name]
  if not t then return nil end
  local i = 0
  return { readLine = function() i = i + 1; return t[i] end, close = function() end }
end
function getFileSeparator() return "/" end
function checkSaveFolderExists() return true end
function getFullSaveDirectoryTable() return { "Sandbox/Lumberjack - Copy - PerfTest" } end
Events = {}
for _, n in ipairs({"OnMainMenuEnter","OnGameStart","OnTick","OnFETick","OnRenderTick","OnInitWorld","OnResetLua","OnPostUIDraw"}) do
  local e = { l = {} }
  e.Add = function(f) table.insert(e.l, f) end
  e.Remove = function(f) for i, g in ipairs(e.l) do if g == f then table.remove(e.l, i) return end end end
  Events[n] = e
end
function fire(n, ...) local c = {} for i, f in ipairs(Events[n].l) do c[i] = f end for _, f in ipairs(c) do f(...) end end
function require() end
function isGamePaused() return false end
function setGameSpeed() end
UIManager = { getSpeedControls = function() return { SetCurrentGameSpeed = function() end } end }

-- a minimal ISUI: elements with children, drawn by frame()
UI = {}
local nextID = 0
ISUIElement = { Type = "ISUIElement" }
ISUIElement.__index = ISUIElement
function ISUIElement:derive(t) local o = {}; setmetatable(o, self); self.__index = self; o.Type = t; return o end
function ISUIElement.new(cls, x, y, w, h)
  local o = {}; setmetatable(o, cls); cls.__index = cls
  nextID = nextID + 1
  o.x, o.y, o.width, o.height, o.ID, o.children, o.visible = x, y, w, h, nextID, {}, true
  return o
end
function ISUIElement:initialise() end
function ISUIElement:instantiate() if self.createChildren then self:createChildren() end end
function ISUIElement:addChild(c) c.parent = self; self.children[c.ID] = c end
function ISUIElement:setVisible(v) self.visible = v end
function ISUIElement:isVisible() return self.visible end
function ISUIElement:addToUIManager() UI[#UI + 1] = self end
function ISUIElement:removeFromUIManager() for i, e in ipairs(UI) do if e == self then table.remove(UI, i) return end end end
function ISUIElement:bringToTop() end
function ISUIElement:getAbsoluteX() return self.x + (self.parent and self.parent:getAbsoluteX() or 0) end
function ISUIElement:getAbsoluteY() return self.y + (self.parent and self.parent:getAbsoluteY() or 0) end
function ISUIElement:drawText() end
function ISUIElement:drawTextCentre() end
function ISUIElement:drawTextRight() end
function ISUIElement:prerender() end
function ISUIElement:render() end
ISPanel = ISUIElement:derive("ISPanel")
function ISPanel:new(x, y, w, h) return ISUIElement.new(self, x, y, w, h) end
ISButton = ISUIElement:derive("ISButton")
function ISButton:new(x, y, w, h, title, target, onclick)
  local o = ISUIElement.new(self, x, y, w, h); o.title, o.target, o.onclick, o.font, o.enable = title, target, onclick, UIFont.Small, true; return o
end
function ISButton:setTitle(t) self.title = t end
function ISButton:setEnable(e) self.enable = e end
ISScrollingListBox = ISUIElement:derive("ISScrollingListBox")
function ISScrollingListBox:new(x, y, w, h)
  local o = ISUIElement.new(self, x, y, w, h); o.items, o.itemheight, o.font, o.vscroll = {}, 22, UIFont.Small, { width = 13 }; return o
end
function ISScrollingListBox:addItem(text, item) self.items[#self.items + 1] = { text = text, item = item } end
ISCollapsableWindow = ISPanel:derive("ISCollapsableWindow")
-- as the game's ISModalDialog (42, read from the PC): sized by CalcSize, text drawn centred in prerender
ISModalDialog = ISPanel:derive("ISModalDialog")
function ISModalDialog.CalcSize(width, height, text)
  local fh = TM:getFontHeight(UIFont.Small)
  local tw, th = 0, 0
  for line in string.gmatch(text .. "\n", "([^\n]*)\n") do tw = math.max(tw, TM:MeasureStringX(UIFont.Small, line)); th = th + fh end
  local need = math.max(tw + 10, 100 * 2 + 10 * 3 + 2)
  if width < need then width = need end
  if height < 20 + th + 20 + 25 + 10 then height = 20 + th + 20 + 25 + 10 end
  return width, height
end
function ISModalDialog:new(x, y, w, h, text, yesno, target, onclick)
  text = string.gsub(text, "\\n", "\n")
  w, h = ISModalDialog.CalcSize(w, h, text)
  local o = ISUIElement.new(self, x, y, w, h); o.text = text; return o
end
function ISModalDialog:createChildren()
  local bh = TM:getFontHeight(UIFont.Small) + 6
  local yes = ISButton:new((self.width - 10) / 2 - 100, self.height - 10 - bh - 1, 100, bh, "Yes", self, function() end); self:addChild(yes)
  local no = ISButton:new((self.width + 10) / 2, self.height - 10 - bh - 1, 100, bh, "No", self, function() end); self:addChild(no)
end
function ISModalDialog:prerender() self:drawTextCentre(self.text, self.width / 2, 20, 1, 1, 1, 1, UIFont.Small) end
function frame()
  local list = {}
  for i, e in ipairs(UI) do list[i] = e end
  for _, e in ipairs(list) do if e.visible then e:prerender(); e:render() end end
end

-- the Capture add-on, taking every shot at once
SHOTS = {}
TGCapture = { busyFor = 0,
  request = function(name, mode) SHOTS[#SHOTS + 1] = name; TGCapture.busyFor = 2; return true end,
  busy = function() if TGCapture.busyFor > 0 then TGCapture.busyFor = TGCapture.busyFor - 1; return true end; return false end,
  lastResult = function() return "ok" end, status = function() return "capture 1.0.7 (mock)" end,
  copySaveStart = function() return true end, copySaveStatus = function() return "done" end }
'''

def runtime():
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    g = L.globals()
    g.py_measure = lambda f, t: measure(f, t)
    g.py_height = lambda f: METRICS.get(str(f), METRICS['Small'])['height']
    g.py_screen_w, g.py_screen_h = SCREEN
    L.execute(PRELUDE)
    return L

UICHECK = src('TestGroundAutorun/42/media/lua/client/TestGroundUICheck.lua')
_RUNNER = src('TestGround/42/media/lua/client/TestGround/Runner.lua')
CONFIRM_SRC = ('local K = TestGroundInternal.K\nlocal function say(s) print("[TestGround] " .. s) end\n' +
    _RUNNER[_RUNNER.index('K.CONFIRM_TEXT = '):_RUNNER.index('function K.confirmed()')] +
    _RUNNER[_RUNNER.index('function K.wrapLines'):_RUNNER.index('function T.start(plan)')])
TG_STUB = r'''
TestGroundInternal = { loaded = {}, S = {}, T = {}, K = {} }
TestGround = { VERSION = "1.13.33" }
'''

def lines(L, name):
    t = L.eval('FILES[%r]' % name)
    return [t[i] for i in range(1, len(t) + 1)] if t else []

def defects_of(res):
    d = res['defects']
    return [d[i] for i in range(1, len(d) + 1)]

def picker(L, bench_src, rows=None):
    """open a Benchmark Save window from the given TestGroundBenchmark.lua and check it"""
    L.execute('TestGroundAutorun = TestGroundAutorun or { benchCopyName = function() return nil end, isBenchName = function() return false end,'
              ' BENCH_MODES = { Sandbox = true, Apocalypse = true, Survivor = true }, writeFlagLines = function() end, kick = function() end }')
    L.execute('MainScreen = { instance = { children = {}, addChild = function(self, c) self.children[#self.children + 1] = c end } }')
    L.execute(bench_src)
    if rows:
        L.execute('TestGroundAutorun.benchFixtureRows = ' + rows)
    L.execute('w = TestGroundBenchWindow:new(); w:initialise(); w:instantiate(); w:addToUIManager()')
    L.execute('TestGroundUICheck.arm(w, "picker", { needs = { { "getTextManager", "MeasureStringX" } } })')
    L.execute('frame()')
    return L.eval('TestGroundUICheck.evaluate(w)')

def endscreen(L, es_src, seconds='30', paused=False, stopped='nil'):
    L.execute(TG_STUB)
    L.execute(es_src)
    L.execute(TOUR_FIXTURE)
    L.execute('w = TestGroundEndScreen:new(fixtureSum(%s), %s); w:initialise(); w:instantiate(); w:addToUIManager()' % (stopped, seconds))
    if paused:
        L.execute('w:onPause()')
    L.execute('TestGroundUICheck.arm(w, "end_screen", { needs = { { "getCore", "quitToDesktop" } } })')
    L.execute('frame()')
    return L.eval('TestGroundUICheck.evaluate(w)')

# the tour's own end-screen fixture, without loading the tour
TOUR_FIXTURE = r'''
function fixtureSum(stopped)
  local rows = {}
  for i = 1, 16 do rows[i] = { name = (i == 14) and "A step with a very long name that runs on past the column before the numbers" or ("Fight 40 zombies in the open, step " .. i),
     skipped = (i == 5), f = { fps = 50.5, p99 = 120, over100 = i % 3 } } end
  return { save = string.rep("Lumberjack Long Save Name ", 8), copyOf = true, rows = rows, seconds = 912, frames = 51234, fps = 56.2,
     mean = 17.8, p99 = 165, worst = 1187, over33 = 1234, over100 = 56, stopped = stopped }
end
'''

def has(ds, code, where=''):
    return any((' %s ' % code) in d and where in d for d in ds)

# ===============================================================================================
REAL = len(sys.argv) > 1
if REAL:
    print('== parts 1 and 1b skipped: the old bugs are replayed with the 2560x1440 profile they happened at')
print('== part 1: tonight\'s five bugs, from the old builds')
SKIP = REAL
if len(sys.argv) <= 1:
    for t, real in (('Pick a save to test. The run happens in a throwaway copy of it; your save is not opened.', 703),
                    ('The copy is deleted the next time this menu shows. The full test takes about 15 minutes,', 720)):
        check(abs(measure('Small', t) - real) <= real * 0.03, 'profile within 3%% of the PC screenshot: %d px vs %d px' % (measure('Small', t), real))
old152 = from_zip('autorun-1.5.2.zip', 'TestGroundAutorun/42/media/lua/client/TestGroundBenchmark.lua')
old157 = from_zip('autorun-1.5.7.zip', 'TestGroundAutorun/42/media/lua/client/TestGroundBenchmark.lua')
old1326 = from_zip('ship-1.13.26.zip', 'TestGround/42/media/lua/client/TestGround/EndScreen.lua')
check(old152 and old157 and old1326, 'old builds found (autorun-1.5.2, autorun-1.5.7, ship-1.13.26)')
LONG_ROWS = '{ { mode = "Sandbox", name = string.rep("Lumberjack Long Save Name ", 8), t = 9 } }'

L = runtime(); L.execute(UICHECK)
ds = defects_of(picker(L, old152, LONG_ROWS))
print('   ' + '\n   '.join(ds))
check(has(ds, 'ROW_SHORT', 'picker/ISScrollingListBox'), '1.5.2 picker: rows shorter than the font -> ROW_SHORT')
check(has(ds, 'TEXT_WIDE', 'The copy is deleted'), '1.5.2 picker: footer past the window edge -> TEXT_WIDE')

L = runtime(); L.execute(UICHECK)
ds = defects_of(picker(L, old157, LONG_ROWS))
print('   ' + '\n   '.join(ds))
check(has(ds, 'TEXT_WIDE', 'Start_full_benchmark'), '1.5.7 picker: "Start full benchmark" wider than its button -> TEXT_WIDE')

L = runtime(); L.execute(UICHECK)
ds = defects_of(endscreen(L, old1326))
print('   ' + '\n   '.join(ds))
check(has(ds, 'TEXT_WIDE', 'worst step p99'), '1.13.26 end screen: stats line past the panel -> TEXT_WIDE')

L = runtime(); L.execute(UICHECK)
L.execute('CORE.quitToDesktop = nil')
ds = defects_of(endscreen(L, src('TestGround/42/media/lua/client/TestGround/EndScreen.lua')))
print('   ' + '\n   '.join(ds))
check(has(ds, 'API_MISSING', 'quitToDesktop'), 'a build without getCore():quitToDesktop -> API_MISSING')

L = runtime(); L.execute(UICHECK)
L.execute('Bad = ISPanel:derive("Bad"); function Bad:render() local x = getCore():noSuchCall() end')
L.execute('b = Bad:new(10, 10, 100, 100); b:addToUIManager(); TestGroundUICheck.arm(b, "bad"); frame()')
ds = defects_of(L.eval('TestGroundUICheck.evaluate(b)'))
check(has(ds, 'RENDER_ERROR'), 'a render that calls a missing API -> RENDER_ERROR (%s)' % (ds[:1],))

print("== part 1b: the PC tour of 1.13.30 / 1.5.9 (19 Oct)")
old159 = from_zip('autorun-1.5.9.zip', 'TestGroundAutorun/42/media/lua/client/TestGroundBenchmark.lua')
TOUR_OLD = from_zip('autorun-1.5.9.zip', 'TestGroundAutorun/42/media/lua/client/TestGroundUITour.lua')
check(old159 and TOUR_OLD, 'autorun-1.5.9 found')
L = runtime(); L.execute('SW, SH = 2133, 1200'); L.execute(UICHECK); L.execute(TG_STUB); L.execute(CONFIRM_SRC)
L.execute('d = ISModalDialog:new((SW - 380) / 2, (SH - 170) / 2, 380, 170, TestGroundInternal.K.CONFIRM_TEXT, true); d:initialise(); d:instantiate(); d:addToUIManager()')
L.execute('TestGroundUICheck.arm(d, "confirm/dialog"); frame()')
ds = defects_of(L.eval('TestGroundUICheck.evaluate(d)'))
print('   ' + '\n   '.join(ds))
check(has(ds, 'OFF_SCREEN'), '1.13.30 confirm dialog (one line) at 2133x1200 -> OFF_SCREEN')
L = runtime(); L.execute('SW, SH = 2133, 1200'); L.execute(UICHECK)
L.execute('TestGroundAutorun = { benchCopyName = function() return nil end, isBenchName = function() return false end,'
          ' BENCH_MODES = { Sandbox = true, Apocalypse = true, Survivor = true }, writeFlagLines = function() end, kick = function() end }')
L.execute(TOUR_OLD.replace('require "TestGroundAutorun"', '').replace('require "TestGroundUICheck"', ''))
res = picker(L, old159, 'TestGroundAutorun.Tour.pickerRows()')
ds = defects_of(res)
ws = [res['warnings'][i] for i in range(1, len(res['warnings']) + 1)]
print('   ' + '\n   '.join(ds + ws))
check(has(ds, 'TEXT_WIDE', 'row 3'), '1.5.9 picker: the Chinese row cut past the list edge -> TEXT_WIDE')
check(any('GLYPH_MISSING' in w for w in ws), '... and GLYPH_MISSING names the characters drawn as "?"')

SKIP = False
if REAL and SCREEN == (2560, 1440):
    print('== part 1c: the PC tour of 1.13.32 / 1.5.11 at 2560x1440 (real font widths)')
    old1332 = from_zip('ship-1.13.32.zip', 'TestGround/42/media/lua/client/TestGround/EndScreen.lua')
    L = runtime(); L.execute(UICHECK)
    ds = defects_of(endscreen(L, old1332, paused=True))
    print('   ' + '\n   '.join(ds))
    check(has(ds, 'TEXT_WIDE', 'Resume countdown'), '1.13.32 end screen, paused: "Resume countdown" wider than its 160 px button -> TEXT_WIDE')

# ===============================================================================================
print('== part 2: the current windows (Autorun 1.5.12, Test Ground 1.13.33)')
BENCH = src('TestGroundAutorun/42/media/lua/client/TestGroundBenchmark.lua')
ES = src('TestGround/42/media/lua/client/TestGround/EndScreen.lua')
TOUR = src('TestGroundAutorun/42/media/lua/client/TestGroundUITour.lua')

for (sw, sh) in ((2560, 1440), (2133, 1200), (1920, 1080), (1280, 720)):
    L = runtime(); L.execute('SW, SH = %d, %d' % (sw, sh)); L.execute(UICHECK); L.execute(TG_STUB); L.execute(CONFIRM_SRC)
    L.execute('d = TestGroundInternal.K.confirmDialog(function() end); d:instantiate(); TestGroundUICheck.arm(d, "confirm/dialog"); frame()')
    res = L.eval('TestGroundUICheck.evaluate(d)')
    ds = defects_of(res)
    check(not ds and res['rect']['w'] <= sw, 'confirm dialog at %dx%d: %dx%d, no defects %s' % (sw, sh, res['rect']['w'], res['rect']['h'], ds))
    L = runtime(); L.execute('SW, SH = %d, %d' % (sw, sh)); L.execute(UICHECK)
    L.execute('TestGroundAutorun = { benchCopyName = function() return nil end, isBenchName = function() return false end,'
              ' BENCH_MODES = { Sandbox = true, Apocalypse = true, Survivor = true }, writeFlagLines = function() end, kick = function() end }')
    L.execute(TOUR.replace('require "TestGroundAutorun"', '').replace('require "TestGroundUICheck"', ''))
    ds = defects_of(picker(L, BENCH, 'TestGroundAutorun.Tour.pickerRows()'))
    check(not ds, 'picker with the tour rows at %dx%d: no defects %s' % (sw, sh, ds))
    for label, kw in (('countdown', {}), ('paused', {'paused': True}), ('no countdown', {'seconds': 'nil'}), ('stopped', {'seconds': 'nil', 'stopped': '"stopped by the user"'})):
        L2 = runtime(); L2.execute('SW, SH = %d, %d' % (sw, sh)); L2.execute(UICHECK)
        ds = defects_of(endscreen(L2, ES, **kw))
        check(not ds, 'end screen (%s) at %dx%d: no defects %s' % (label, sw, sh, ds))

# self-check on first open, only once, file and stats
L = runtime(); L.execute(UICHECK); L.execute(TG_STUB); L.execute(ES); L.execute(TOUR_FIXTURE)
L.execute('for i = 1, 2 do local w = TestGroundEndScreen:new(fixtureSum(nil), 30); w:initialise(); w:instantiate(); w:addToUIManager(); frame(); fire("OnTick") end')
f = lines(L, 'TestGround_uicheck.txt')
check(sum(1 for l in f if l.startswith('UICHECK end_screen:')) == 1, 'the end screen checks itself once per session (%d lines)' % len(f))
check(L.eval('TestGroundUICheck.stats.windows') == 1, 'stats count the self-check')

# ===============================================================================================
print('== part 3: the tour, flag to done file')
AR = src('TestGroundAutorun/42/media/lua/client/TestGroundAutorun.lua')
L = runtime()
L.execute('FILES["TestGround_autorun.txt"] = { "save = Lumberjack - Copy - PerfTest", "uitour = 1", "delay = 10", "quit = 1" }')
L.execute(TG_STUB)
L.execute(r'''
LOADS = {}
MainScreen = { instance = { children = {}, addChild = function(self, c) c.parent = nil; self.children[#self.children + 1] = c end },
  continueLatestSave = function(mode, save) LOADS[#LOADS + 1] = mode .. "/" .. save end }
WORLD = "Lumberjack - Copy - PerfTest"
function getWorld() return { getWorld = function() return WORLD end } end
function getPlayer() return nil end
function getSpecificPlayer() return nil end
local K = TestGroundInternal.K
function K.bannerText(r, t)
  if r.phase == "settle" then return "Test Ground: " .. r.plan.label, "waiting for the start to load" end
  local st = r.steps[r.si]
  if r.phase == "gap" then return "Test Ground: " .. r.plan.label, "next: " .. st.text end
  return "TEST: Stress: 500 zombies around the player (zombies)", string.format("step %d of %d, pass %d, %d s", r.si, #r.steps, st.pass, 47) .. "   " .. st.text
end
''')
L.execute(CONFIRM_SRC)
L.execute(AR)
L.execute(BENCH)
L.execute(UICHECK)
L.execute(TOUR)
L.execute(ES)
def run(n, ev, step=50):
    for _ in range(n):
        L.execute('clock = clock + %d; frame(); fire(%r)' % (step, ev))
L.execute('fire("OnMainMenuEnter")')
run(200, 'OnFETick')
check(L.eval('#LOADS') == 1, 'the save loads after the menu part (%d loads)' % L.eval('#LOADS'))
m = lines(L, 'TestGround_uitour.txt')
check(m and ('screen %dx%d' % SCREEN) in m[0], 'manifest header has the game resolution: %s' % (m[:1],))
check(any(l.startswith('part menu: 3 screens, 3 shots') for l in m), 'menu part: 3 screens, 3 shots')
fm = lines(L, 'TestGround_fontmetrics.txt')
check(len(fm) > 400 and fm[0].startswith('font metrics, screen %dx%d' % SCREEN), 'font metrics written (%d lines)' % len(fm))
L.execute('fire("OnGameStart")')
for _ in range(2000):
    run(1, 'OnTick')
    if lines(L, 'TestGround_autorun_done.txt'): break
done = lines(L, 'TestGround_autorun_done.txt')
print('   ' + '\n   '.join(done[:3]))
check(done and done[0] == 'result = ui tour done', 'done file says the tour finished')
check(any(l.startswith('ui_check = ') for l in done), 'done file carries the ui_check count: %s' % [l for l in done if l.startswith('ui_check')])
check(any(l.startswith('ui_tour = 12 screens, 12 shots, 0 defects') for l in done), 'ui_tour = 12 screens, 12 shots, 0 defects')
m = lines(L, 'TestGround_uitour.txt')
shots = [l for l in m if l.startswith('shot ')]
check(len(shots) == 12, '12 shots in the manifest: %s' % [s[5:] for s in shots])
check(all(l.startswith('file = TG_ui_1.13.33-1.5.12_') for l in m if l.startswith('file = ')), 'shot files named TG_ui_<build>_<screen>_<state>')
check(L.eval('#SHOTS') == 12, 'Capture asked for 12 shots')
check(L.eval('#UI') == 0, 'every tour window closed (%d left)' % L.eval('#UI'))
check(L.eval('QUIT') == 0, 'the end screen never closed the game during the tour')
run(150, 'OnTick')
check(L.eval('QUIT') == 1, 'quits to desktop after the tour (quit = 1)')

print('ALL OK' if ok else 'SOME FAILED')
sys.exit(0 if ok else 1)
