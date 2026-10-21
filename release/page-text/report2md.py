#!/usr/bin/env python3
"""Turn a PZ Harness report (.txt) into a readable Markdown file next to it.
Usage: python report2md.py TestGround_quick_123.txt [out.md]"""
import re, sys

def main(src, out=None):
    lines = open(src, encoding="utf-8", errors="replace").read().splitlines()
    out = out or re.sub(r"\.txt$", "", src) + ".md"
    head, steps, tail, cur, mode = [], [], [], None, "head"
    for l in lines:
        if l.startswith("== "):
            cur = {"title": l[3:], "name": "", "frames": "", "extra": []}
            steps.append(cur); mode = "step"
        elif mode == "step" and l.startswith("detail:"):
            mode = "tail"; tail.append(l)
        elif mode == "step" and l.strip():
            if l.startswith("name:"): cur["name"] = l[5:].strip()
            elif l.startswith("frames:"): cur["frames"] = l[7:].strip()
            else: cur["extra"].append(l)
        elif mode == "head": head.append(l)
        elif mode == "tail": tail.append(l)
    kv = {}
    for l in head[1:]:
        m = re.match(r"([\w ]+?): (.*)", l)
        if m: kv.setdefault(m.group(1), m.group(2))
    md = ["# " + head[0], ""]
    for k in ("plan", "scene", "zombie intensity at the start", "zoom"):
        if k in kv: md.append(f"- **{k}:** {kv[k]}")
    mods = kv.get("mods", "").split(";") if kv.get("mods") else []
    md += ["", f"<details><summary>{len(mods)} mods active (click to list)</summary>", "", ", ".join(mods), "", "</details>", ""]
    if "test ground files" in kv:
        md += ["**PZ Harness files:** " + kv["test ground files"].replace("; ", "  \n"), ""]
    summ = [l for l in tail if l.startswith(("save tested", "plan "))]
    if summ:
        md += ["## Result", ""] + [f"- {s}" for s in summ] + [""]
    md += ["## Steps", "", "| Step | fps | mean ms | p95 | p99 | worst ms | over 33 ms | hitches (100 ms+) |", "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for s in steps:
        f = s["frames"]
        g = lambda p: (re.search(p, f) or [None, "-"])[1]
        md.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % (
            s["name"] or s["title"], g(r"([\d.]+) fps"), g(r"mean ([\d.]+)"), g(r"p95 (\d+)"),
            g(r"p99 (\d+)"), g(r"worst (\d+)"), g(r"(\d+) over 33"), g(r"(\d+) hitches")))
    md.append("")
    for s in steps:
        md += [f"### {s['name'] or s['title']}", "", s["title"], ""]
        if s["extra"]: md += ["> " + e for e in s["extra"]] + [""]
    rest = [l for l in tail if l not in summ]
    if rest: md += ["## Notes", ""] + [f"- {l}" for l in rest] + [""]
    open(out, "w", encoding="utf-8", newline="\n").write("\n".join(md))
    print("wrote", out)

if __name__ == "__main__":
    if len(sys.argv) < 2: sys.exit(__doc__)
    main(*sys.argv[1:3])
