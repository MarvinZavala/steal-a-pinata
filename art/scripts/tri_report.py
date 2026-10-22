"""Counts triangles per object in every exported OBJ (independent of Blender) -> art/export/TRIANGLES.md + .json"""
import os, glob, json
ROOT = os.path.join(os.path.dirname(__file__), "..", "export")
rows = []
for f in sorted(glob.glob(f"{ROOT}/*/*.obj")):
    objs = {}; cur = None
    for line in open(f):
        if line.startswith("o "): cur = line[2:].strip(); objs.setdefault(cur, 0)
        elif line.startswith("f "): objs[cur] = objs.get(cur, 0) + len(line.split()) - 3
    sub = os.path.basename(os.path.dirname(f)); name = os.path.splitext(os.path.basename(f))[0]
    for o, t in objs.items(): rows.append((sub, name, o, t))
over = [r for r in rows if r[3] > 20000]
json.dump([dict(folder=a, file=b, mesh=c, tris=d) for a, b, c, d in rows], open(f"{ROOT}/TRIANGLES.json", "w"), indent=1)
with open(f"{ROOT}/TRIANGLES.md", "w") as out:
    out.write("# Triangle report (auto: scripts/tri_report.py, counted from the .obj exports)\n\n")
    out.write("Roblox limit: 20,000 triangles per MeshPart. Each row = one MeshPart after import.\n\n")
    out.write("| Folder | File | MeshPart | Triangles | OK |\n|---|---|---|---:|:-:|\n")
    for a, b, c, d in rows: out.write(f"| {a} | {b} | {c} | {d:,} | {'✅' if d <= 20000 else '❌'} |\n")
    out.write(f"\n**{len(rows)} MeshParts, max {max(r[3] for r in rows):,} tris, {len(over)} over the limit.**\n")
print(len(rows), "meshes; max", max(r[3] for r in rows), "; over:", over)
