# Checks that CraneTest.lua's ring walk (K.scan) visits every edge square of each ring exactly once.
for rad in range(1, 41):
    pts = []
    for i in range(8 * rad):
        if i <= 2 * rad: p = (i - rad, -rad)
        elif i <= 4 * rad + 1: p = (i - 3 * rad - 1, rad)
        elif i <= 6 * rad: p = (-rad, i - 5 * rad - 1)
        else: p = (rad, i - 7 * rad)
        pts.append(p)
    edge = {(x, y) for x in range(-rad, rad + 1) for y in range(-rad, rad + 1) if max(abs(x), abs(y)) == rad}
    assert len(pts) == len(set(pts)) == len(edge) and set(pts) == edge, rad
print("ring walk OK for radius 1 to 40")
