#!/usr/bin/env python3
"""MET-10 preview: small icon sizes at 100% and 400% (nearest-neighbour), on light and dark grounds.
Pass a directory of the previous PNGs as argv[1] to add a 'before' row."""
import json, sys, pathlib
from PIL import Image, ImageDraw
H = pathlib.Path(__file__).parent; T = json.load(open(H / '../tokens.json'))
L, D = T['color']['light'], T['color']['dark']
sizes = [16, 32, 64]
rows = [('MET-10 pixel-snapped', {s: Image.open(H / f'icon/png/OpenKef-{s}.png').convert('RGBA') for s in sizes})]
if len(sys.argv) > 1:
    rows.insert(0, ('before (MET-9, SVG raster)', {s: Image.open(f'{sys.argv[1]}/old-{s}.png').convert('RGBA') for s in sizes}))
pad, cell = 24, 64 * 4
W = pad + len(sizes) * (cell + pad) + 2 * (pad + 32 + pad)
Hh = len(rows) * 2 * (cell + 48) + pad
out = Image.new('RGBA', (W + 120, Hh), L['surface']); dr = ImageDraw.Draw(out); y = pad
for label, ims in rows:
    for ground in (L['surface'], D['bg']):
        dr.rectangle([0, y - 8, W + 120, y + cell + 40], fill=ground)
        fg = L['textMuted'] if ground == L['surface'] else D['textMuted']
        dr.text((pad, y), label, fill=fg); x = pad + 120
        for s in (16, 32):                                   # 100% crops
            out.alpha_composite(ims[s], (x, y + 24)); dr.text((x, y + 24 + s + 4), f'{s}@1x', fill=fg); x += 48
        for s in sizes:                                       # 400% crops
            z = ims[s].resize((s * 4, s * 4), Image.NEAREST)
            out.alpha_composite(z, (x, y + 24)); dr.text((x, y + 24 + s * 4 + 4), f'{s}px @400%', fill=fg); x += s * 4 + pad
        y += cell + 48
out.convert('RGB').save(H / 'met-10-preview.png'); print(out.size)
