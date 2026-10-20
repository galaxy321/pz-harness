"""Verdicts for a Test Ground UI tour (design: test-ground/docs/UI-CHECKS.md).

python3 -I uishots.py <TestGround_uitour.txt> <screenshots dir> [golden dir] [--expect WxH]

Runs in the cloud (any thread's container, after the PC thread stages the files); the PC itself needs no Python.
--expect: the resolution the game is set to (options.ini). If the tour ran at another size (on 19 Oct the
monitor was asleep and the game came up at 2133x1200 instead of 2560x1440) every shot is a DEFECT, since
fonts and layout change with the resolution.

For each shot in the manifest, one line:
  layout ok: <screen/state>
  DEFECT <screen/state> ...   the in-game check found it, or a shot is missing or the wrong size
  LOOK <screen/state> ...     a pixel test is unsure (text may cross an edge, a change against the golden):
                              the PC thread opens the crop and decides
The screen size is the one the manifest records (the game's own resolution setting), never a fixed one.
A golden is the last shot the user approved, named <screen>_<state>.png in the golden dir.
Needs Pillow. Exit code 1 when there is any DEFECT.
"""
import os, re, sys
from PIL import Image, ImageStat

BAND = 6          # px just outside a panel or button that must hold no text
INSIDE = 8        # px just inside it that the same text row would come from
TILE = 16

def parse(path):
    shots, screen, cur = [], None, None
    for raw in open(path, encoding='utf-8', errors='replace'):
        line = raw.rstrip('\n')
        m = re.match(r'^ui tour \S+, part \S+, screen (\d+)x(\d+)', line)
        if m:
            screen = (int(m.group(1)), int(m.group(2)))
        elif line.startswith('shot '):
            cur = {'name': line[5:], 'elements': [], 'defects': [], 'warnings': [], 'screen': screen}
        elif cur is not None:
            if line == 'end':
                shots.append(cur); cur = None
            elif line.startswith('file = '):
                cur['file'] = line[7:]
            elif line.startswith('expect = '):
                cur['expect'] = line[9:]
            elif line.startswith('window = '):
                cur['window'] = tuple(int(v) for v in line[9:].split())
            elif line.startswith('element '):
                n, v = line[8:].split(' = ', 1)
                cur['elements'].append((n, tuple(int(x) for x in v.split())))
            elif line.startswith('UICHECK DEFECT'):
                cur['defects'].append(line)
            elif line.startswith('UICHECK WARN'):
                cur['warnings'].append(line)
    return shots

def bright(px):
    """text colours (white, grey-white, amber), not the blue panel border"""
    r, g, b = px[:3]
    return r > 180 and g > 140

def touch(img, rect):
    """a label or line reaching the last few px inside an edge: it fits too tightly or is cut there"""
    W, H = img.size
    x, y, w, h = rect
    hits = []
    for side, band in (('right', range(x + w - 5, x + w - 1)), ('left', range(x + 1, x + 5))):
        rows = 0
        for yy in range(max(0, y + 2), min(H, y + h - 2)):
            if sum(1 for xx in band if 0 <= xx < W and bright(img.getpixel((xx, yy)))) >= 1 and \
               not all(0 <= xx < W and bright(img.getpixel((xx, yy))) for xx in band):   # a solid vertical line is a border
                rows += 1
        if rows >= 3:
            hits.append('%s edge, %d rows' % (side, rows))
    return hits

def spill(img, rect):
    """rows where bright pixels sit both just inside the right/left edge and just outside it"""
    W, H = img.size
    x, y, w, h = rect
    hits = []
    for side, xin, xout in (('right', range(x + w - INSIDE, x + w - 1), range(x + w + 1, x + w + 1 + BAND)),
                            ('left', range(x + 1, x + INSIDE), range(x - BAND - 1, x - 1))):
        rows = 0
        for yy in range(max(0, y), min(H, y + h)):
            inn = any(0 <= xx < W and bright(img.getpixel((xx, yy))) for xx in xin)
            out = any(0 <= xx < W and bright(img.getpixel((xx, yy))) for xx in xout)
            if inn and out:
                rows += 1
        if rows >= 3:
            hits.append('%s edge, %d rows' % (side, rows))
    return hits

def blank(img, rect):
    x, y, w, h = rect
    crop = img.crop((max(0, x), max(0, y), x + w, y + h)).convert('L')
    st = ImageStat.Stat(crop)
    return st.stddev[0] < 2.0, st.mean[0]

def golden_diff(img, gold, rect):
    if gold.size != img.size:
        return ['golden is %dx%d, shot is %dx%d' % (gold.size + img.size)]
    x, y, w, h = rect
    out = []
    for ty in range(max(0, y), y + h, TILE):
        for tx in range(max(0, x), x + w, TILE):
            box = (tx, ty, min(tx + TILE, x + w), min(ty + TILE, y + h))
            a = ImageStat.Stat(img.crop(box).convert('L')).mean[0]
            b = ImageStat.Stat(gold.crop(box).convert('L')).mean[0]
            if abs(a - b) > 12:
                out.append(box)
    return out

def bbox(boxes):
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))

def main(argv):
    expect = None
    if '--expect' in argv:
        i = argv.index('--expect')
        expect = tuple(int(v) for v in argv[i + 1].lower().split('x'))
        argv = argv[:i] + argv[i + 2:]
    if len(argv) < 3:
        print(__doc__); return 2
    shots = parse(argv[1])
    sdir, gdir = argv[2], (argv[3] if len(argv) > 3 else None)
    bad = 0
    for s in shots:
        name, out = s['name'], []
        kind = 'ok'
        for d in s['defects']:
            out.append(d.replace('UICHECK DEFECT ', '')); kind = 'DEFECT'
        if expect and s['screen'] and s['screen'] != expect:
            out.append('the game ran at %dx%d, its setting is %dx%d (monitor asleep or off?): run the tour again' % (s['screen'] + expect)); kind = 'DEFECT'
        f = s.get('file', '')
        path = os.path.join(sdir, f)
        if f.startswith('NO SHOT') or not os.path.exists(path):
            out.append('no screenshot (%s)' % f); kind = 'DEFECT'
        else:
            img = Image.open(path).convert('RGB')
            if s['screen'] and img.size != s['screen']:
                out.append('shot is %dx%d, the game was %dx%d' % (img.size + s['screen'])); kind = 'DEFECT'
            rect = s.get('window')
            if rect and rect[2] > 0 and rect[3] > 0:
                is_blank, mean = blank(img, rect)
                if is_blank:
                    out.append('the window area is blank (mean %.0f)' % mean); kind = 'DEFECT'
                is_panel = not name.split('/')[0].endswith('banner') and not name.startswith('menu_button')
                for r in ([('window', rect)] if is_panel else []) + [e for e in s['elements']]:
                    for h in spill(img, r[1]):
                        out.append('text may cross the %s of %s' % (h, r[0]))
                        if kind == 'ok': kind = 'LOOK'
                    for h in touch(img, r[1]):
                        out.append('text touches the %s of %s' % (h, r[0]))
                        if kind == 'ok': kind = 'LOOK'
                if gdir:
                    gp = os.path.join(gdir, re.sub(r'^TG_ui_[^_]+_', '', f))
                    if os.path.exists(gp):
                        ch = golden_diff(img, Image.open(gp).convert('RGB'), rect)
                        if ch:
                            out.append('%d tiles differ from the golden, within %s' % (len(ch), bbox(ch) if isinstance(ch[0], tuple) else ch[0]))
                            if kind == 'ok': kind = 'LOOK'
                    else:
                        out.append('no golden yet')
        for w in s['warnings']:
            out.append(w.replace('UICHECK WARN ', 'warning: '))
        if kind == 'DEFECT': bad += 1
        head = 'layout ok:' if kind == 'ok' else kind
        print('%s %s%s' % (head, name, (': ' + '; '.join(out)) if out else ''))
        if kind != 'ok' and s.get('expect'):
            print('    expected: ' + s['expect'])
    print('%d shots, %d with defects' % (len(shots), bad))
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main(sys.argv))
