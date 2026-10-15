#!/usr/bin/env python3
"""Builds met-9-preview.png: icon at every size (on light and dark ground), menu-bar glyph, DMG background @1x."""
import json, pathlib
from PIL import Image, ImageDraw
H = pathlib.Path(__file__).parent; T = json.load(open(H/'../tokens.json'))
L, D = T['color']['light'], T['color']['dark']
sizes = [16, 32, 64, 128, 256, 512, 1024]
icons = [Image.open(H/f'icon/png/OpenKef-{s}.png').convert('RGBA') for s in sizes]
shown = [i if i.width <= 256 else i.resize((256, 256), Image.LANCZOS) for i in icons]
dmg = Image.open(H/'dmg/dmg-background.png').convert('RGBA')
g1, g2 = Image.open(H/'menubar/MenuBarGlyphTemplate.png'), Image.open(H/'menubar/MenuBarGlyphTemplate@2x.png')
pad = 32; rowh = 256 + pad * 2
W = max(sum(i.width for i in shown) + pad * (len(shown) + 1), dmg.width + pad * 2)
out = Image.new('RGBA', (W, rowh * 2 + 80 + dmg.height + pad * 2), L['surface'])
dr = ImageDraw.Draw(out)
for row, ground in enumerate([L['surface'], D['bg']]):
    y0 = row * rowh; dr.rectangle([0, y0, W, y0 + rowh], fill=ground); x = pad
    for s, im in zip(sizes, shown):
        out.alpha_composite(im, (x, y0 + pad + 256 - im.height)); dr.text((x, y0 + rowh - 24), f'{s}px', fill=L['textMuted'] if row == 0 else D['textMuted']); x += im.width + pad
y = rowh * 2 + 24
for gi, g in enumerate([g1, g2]):
    out.alpha_composite(g.convert('RGBA'), (pad + gi * 60, y))
dr.text((pad + 140, y + 4), 'menu-bar template glyph 18pt @1x / @2x', fill=L['textMuted'])
out.alpha_composite(dmg, (pad, rowh * 2 + 80))
for cx in (170, 490):  # assumed Finder icon centres (128pt icons)
    dr.rectangle([pad + cx - 64, rowh * 2 + 80 + 200 - 64, pad + cx + 64, rowh * 2 + 80 + 200 + 64], outline=L['textMuted'])
out.alpha_composite(icons[3], (pad + 170 - 64, rowh * 2 + 80 + 200 - 64))
out.convert('RGB').save(H/'met-9-preview.png'); print(out.size)
