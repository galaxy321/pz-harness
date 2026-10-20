# Test Ground Memory mock test (Lua side): python3 mock_test.py  ->  ALL OK
# The Java side has java/test/Smoke.java (runs the sampler outside the game; needs Java 25 for OSHI's FFM).
import os, sys
try:
    from lupa import lua51 as lupa_rt
except ImportError:
    import lupa as lupa_rt
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = open(os.path.join(HERE, '42/media/lua/client/TestGroundMemory.lua')).read()
ok = True
def check(c, m):
    global ok
    print(('ok   ' if c else 'FAIL ') + m)
    ok = ok and c
def runtime():
    L = lupa_rt.LuaRuntime(unpack_returned_tuples=True)
    L.execute(r'''
    EV = {}
    Events = { OnGameStart = { Add = function(f) EV.start = f end } }
    MODS = {}
    TestGround = { addReportModule = function(name, m) MODS[name] = m; return true end }
    ''')
    return L
# with the Java part
L = runtime()
L.execute(r'''
MARKS = 0
V = { processMB = 3000, processPeakMB = 3300, heapUsedMB = 1800, heapPeakMB = 2100, heapMaxMB = 3072,
  systemTotalMB = 32768, systemFreeMB = 9000, systemFreeLowMB = 8800, vramTotalMB = 8192, vramFreeMB = 4100, vramFreeLowMB = 3900 }
TGMemory = { mark = function() MARKS = MARKS + 1 end, vramSource = function() return "nvx" end, status = function() return "TestGroundMemory 1.0.0: 10 samples" end }
for k, v in pairs(V) do TGMemory[k] = function() return V[k] end end
''')
L.execute(SRC)
L.execute(r'''
LINES = {}
local function add(l) LINES[#LINES + 1] = l end
local r, st = {}, {}
MODS.memory.stepStart(r, st)
V.processMB = 3120
MODS.memory.stepEnd(r, st, add)
MODS.memory.finish(r, add)
''')
lines = list(L.eval('LINES').values())
check(L.eval('MARKS') == 1, 'stepStart resets the peaks')
check(len(lines) == 2, 'one line per step and one at the end')
print('     ' + lines[0]); print('     ' + lines[1])
check('game RAM 3120 MB at the end (peak 3300, +120 over the step)' in lines[0], 'game RAM and its change')
check('Java heap 1800 MB (peak 2100 of 3072 max)' in lines[0], 'heap')
check('system free 8.8 of 32.0 GB (lowest 8.6)' in lines[0], 'system RAM')
check('VRAM free 4100 MB (lowest 3900) of 8192 [nvx]' in lines[0], 'VRAM')
check('run peak game RAM 3300 MB' in lines[1] and 'lowest free VRAM 3900' in lines[1], 'run summary')
# VRAM unknown (Intel)
L.execute('V.vramFreeMB = -1; V.vramFreeLowMB = -1; V.vramTotalMB = -1; TGMemory.vramSource = function() return "none (this GPU\'s driver reports no free VRAM)" end')
L.execute('LINES = {}; local r, st = {}, {}; MODS.memory.stepStart(r, st); MODS.memory.stepEnd(r, st, function(l) LINES[#LINES + 1] = l end)')
check("VRAM none (this GPU's driver reports no free VRAM)" in L.eval('LINES[1]'), 'no VRAM query: says so')
# without the Java part
L = runtime()
L.execute(SRC)
L.execute(r'''
LINES = {}
local r, st = {}, {}
MODS.memory.stepStart(r, st)
MODS.memory.stepEnd(r, st, function(l) LINES[#LINES + 1] = l end)
MODS.memory.finish(r, function(l) LINES[#LINES + 1] = l end)
''')
lines = list(L.eval('LINES').values())
check(len(lines) == 1 and "Java part isn't loaded" in lines[0], 'no jar: one line at the end, no step lines')
# Test Ground not loaded yet: registers at OnGameStart
L = lupa_rt.LuaRuntime(unpack_returned_tuples=True)
L.execute('EV = {}; Events = { OnGameStart = { Add = function(f) EV.start = f end } }')
L.execute(SRC)
L.execute('MODS = {}; TestGround = { addReportModule = function(name, m) MODS[name] = m; return true end }; EV.start()')
check(L.eval('MODS.memory ~= nil'), 'registers at game start when Test Ground loads later')
print('ALL OK' if ok else 'FAILED'); sys.exit(0 if ok else 1)
