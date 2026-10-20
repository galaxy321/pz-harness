# Drive Recorder mock test: python3 mock_test.py  ->  ALL OK
import os, sys
try:
    from lupa import lua51 as lupa_rt
except ImportError:
    import lupa as lupa_rt
HERE = os.path.dirname(os.path.abspath(__file__))
L = lupa_rt.LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
T = 1000
pyfiles = {}
function getTimestampMs() return T end
Keyboard = { KEY_F9 = 67 }
EV = {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) EV[k] = f end }; rawset(t, k, e); return e end })
function getFileWriter(name, create, append)
  local cur = pyfiles[name]
  if not append or cur == nil then cur = "" end
  return { writeln = function(self, l) cur = cur .. l .. "\n" end, close = function(self) pyfiles[name] = cur end }
end
CAR = { x = 100, y = 200, yaw = 0, kmh = 0 }
function CAR:getX() return self.x end
function CAR:getY() return self.y end
function CAR:getZ() return 0 end
function CAR:getAngleY() return self.yaw end
function CAR:getCurrentSpeedKmHour() return self.kmh end
function CAR:isGasPedalPressed() return true end
function CAR:isBrakePedalPressed() return false end
function CAR:isBraking() return false end
function CAR:getCurrentSteering() return 0.1 end
function CAR:getEngineSpeed() return 3000 end
function CAR:getDriver() return PL end
function CAR:getScript() return { getFullName = function() return "Base.CarNormal" end } end
OTHER = { getX = function() return 120 end, getY = function() return 200 end }
PL = { inCar = true }
function PL:getVehicle() if self.inCar then return CAR end return nil end
function PL:getHealth() return 1 end
function getPlayer() return PL end
function getCell() return { getVehicles = function() return { size = function() return 2 end, get = function(_, i) if i == 0 then return CAR end return OTHER end } end } end
function getCore() return { getVersion = function() return "42.mock" end } end
''')
L.execute(open(os.path.join(HERE, '42/media/lua/client/DriveRecorder.lua')).read())
ok = True
def check(c, m):
    global ok
    print(('ok   ' if c else 'FAIL ') + m)
    ok = ok and c
tick = L.eval('function() EV.OnTick() end')
def step(ms, **kw):
    for k, v in kw.items(): L.globals().CAR[k] = v
    L.globals().T = L.globals().T + ms
    tick()
L.execute('EV.OnTick()')
for i in range(40):
    step(125, x=100 + i, kmh=50)
step(125, yaw=60, kmh=20)   # knock: 60 deg in 250 ms and -30 km/h
step(125)
L.execute('PL.inCar = false'); step(125)
FILES = dict(L.globals().pyfiles)
files = [k for k in FILES]
check(len(files) == 1, 'one file per drive: %s' % files)
txt = FILES[files[0]]
lines = [l for l in txt.split('\n') if l]
data = [l for l in lines if not l.startswith('#') and not l.startswith('t_ms')]
check(lines[2].startswith('t_ms,x,y'), 'header line')
check(18 <= len(data) <= 24, '%d samples at 250 ms over ~5.4 s' % len(data))
check(all(len(l.split(',')) == 15 for l in data), '15 fields per line')
check(any(l.endswith(',1') for l in data), 'the knock is flagged')
check(all(l.split(',')[13] == '1' for l in data), 'one other car within 40 tiles')
check(lines[-1].startswith('# stopped after'), 'stop line: ' + lines[-1])
# F9 off: no new file while driving
L.execute('PL.inCar = true; EV.OnKeyPressed(67)'); step(500); step(500)
check(len(dict(L.globals().pyfiles)) == 1, 'F9 off: nothing recorded')
L.execute('EV.OnKeyPressed(67)'); step(500); step(10); L.execute('PL.inCar = false'); step(10)
check(len(dict(L.globals().pyfiles)) == 2, 'F9 on again: a new file for the next drive')
print('ALL OK' if ok else 'FAILED'); sys.exit(0 if ok else 1)
