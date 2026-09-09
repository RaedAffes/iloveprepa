import os, re
from fontTools import subset
from fontTools.ttLib import TTFont

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(BASE, "lib")
SDK_FULL = r"C:\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf"
ICONS_DART = r"C:\flutter\packages\flutter\lib\src\material\icons.dart"
BUILD_FONT = os.path.join(BASE, "build", "web", "assets", "fonts", "MaterialIcons-Regular.otf")

names = set()
for root, _, files in os.walk(LIB):
    for fn in files:
        if fn.endswith(".dart"):
            txt = open(os.path.join(root, fn), encoding="utf-8").read()
            names.update(re.findall(r"Icons\.(\w+)", txt))

name2cp = {}
src = open(ICONS_DART, encoding="utf-8").read()
for m in re.finditer(r"""static const IconData (\w+) = IconData\(\s*([0-9a-fA-FxX]+)""", src):
    name2cp.setdefault(m.group(1), int(m.group(2).replace("0x", ""), 16))

keep = {0x20, 0x00A0}
t = TTFont(BUILD_FONT)
for tbl in t["cmap"].tables:
    if tbl.isUnicode():
        keep |= set(tbl.cmap.keys())
t.close()
for n in names:
    if n in name2cp:
        keep.add(name2cp[n])

unresolved = sorted(n for n in names if n not in name2cp)
if unresolved:
    print("warn: unresolved icon names (check manually):", unresolved)

args = [
    SDK_FULL,
    "--output-file=" + BUILD_FONT,
    "--unicodes=" + ",".join("U+%04X" % c for c in sorted(keep)),
    "--no-hinting", "--name-IDs=*", "--name-legacy", "--name-languages=*",
]
subset.main(args)

t = TTFont(BUILD_FONT)
cps = set()
for tbl in t["cmap"].tables:
    if tbl.isUnicode():
        cps |= set(tbl.cmap.keys())
t.close()
need = {0xEEAF, 0xF63B}
print("MaterialIcons fixed: %d glyphs, %d bytes, 0xEEAF=%s 0xF63B=%s"
      % (len(cps), os.path.getsize(BUILD_FONT), 0xEEAF in cps, 0xF63B in cps))
if not need <= cps:
    raise SystemExit("fix_icons_font FAILED: missing required glyphs")