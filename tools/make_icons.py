import os, sys
from PIL import Image, ImageDraw
RES = sys.argv[1]            # android/app/src/main/res
SRC = sys.argv[2]            # folder holding icon-512.png and maskable-512.png
icon = Image.open(os.path.join(SRC, 'icon-512.png')).convert('RGBA')
mask = Image.open(os.path.join(SRC, 'maskable-512.png')).convert('RGBA')
legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for d, px in legacy.items():
    out = os.path.join(RES, 'mipmap-' + d); os.makedirs(out, exist_ok=True)
    sq = icon.resize((px, px), Image.LANCZOS); sq.save(os.path.join(out, 'ic_launcher.png'))
    m = Image.new('L', (px * 4, px * 4), 0); ImageDraw.Draw(m).ellipse((0, 0, px * 4 - 1, px * 4 - 1), fill=255)
    m = m.resize((px, px), Image.LANCZOS); rd = sq.copy(); rd.putalpha(m); rd.save(os.path.join(out, 'ic_launcher_round.png'))
    fpx = round(px * 108 / 48)
    mask.resize((fpx, fpx), Image.LANCZOS).save(os.path.join(out, 'ic_launcher_foreground.png'))
any26 = os.path.join(RES, 'mipmap-anydpi-v26'); os.makedirs(any26, exist_ok=True)
xml = '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/ic_launcher_background"/>\n    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n</adaptive-icon>\n'
for n in ('ic_launcher.xml', 'ic_launcher_round.xml'):
    open(os.path.join(any26, n), 'w').write(xml)
vals = os.path.join(RES, 'values'); os.makedirs(vals, exist_ok=True)
open(os.path.join(vals, 'ic_launcher_background.xml'), 'w').write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#09090D</color>\n</resources>\n')
# the default blue-X foreground drawables would clash with ours, remove them
for sub in ('drawable', 'drawable-v24'):
    f = os.path.join(RES, sub, 'ic_launcher_foreground.xml')
    if os.path.exists(f): os.remove(f)
print('icons written to', RES)
