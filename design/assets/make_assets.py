#!/usr/bin/env python3
"""MET-9 asset generator. Writes SVG masters from design/tokens.json; render.mjs rasterises them; this script then builds the .icns.
Usage: python3 make_assets.py svg && node render.mjs && python3 make_assets.py pack"""
import json, sys, pathlib
HERE = pathlib.Path(__file__).parent
T = json.load(open(HERE / '../tokens.json'))
L, D = T['color']['light'], T['color']['dark']
R = T['ruler']

# Apple macOS icon grid (1024 canvas): 824pt body inset 100pt, corner radius ~185.4 (continuous corner approximated)
def squircle(x=100, s=824, r=185.4):
    k = r * 0.5523  # bezier approximation of the corner
    return (f'M{x+r},{x} H{x+s-r} C{x+s-r+k},{x} {x+s},{x+r-k} {x+s},{x+r} V{x+s-r} '
            f'C{x+s},{x+s-r+k} {x+s-r+k},{x+s} {x+s-r},{x+s} H{x+r} C{x+r-k},{x+s} {x},{x+s-r+k} {x},{x+s-r} '
            f'V{x+r} C{x},{x+r-k} {x+r-k},{x} {x+r},{x} Z')

def icon_svg(simple=False):
    """Direction C motif: a level ruler (filled ticks up to the cursor) and a tall cursor line, on the dark token ground."""
    bg, filled, minor, major = D['bg'], D['text'], D['line'], D['textMuted']
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">',
           f'<path d="{squircle()}" fill="{bg}" stroke="{D["line"]}" stroke-width="8"/>']  # dark.line edge so it holds on dark wallpapers/Dock
    x0, x1, base = 220, 804, 680           # ruler span inside the body, baseline
    if simple:                               # 16/32px: 7 heavy ticks, cursor
        n, w, cur = 5, 84, 3
        step = (x1 - x0 - w) / (n - 1)
        for i in range(n):
            x = x0 + i * step; h = 330 if i in (0, n - 1) else 220
            c = filled if i < cur else major
            out.append(f'<rect x="{x:.1f}" y="{base-h}" width="{w}" height="{h}" rx="6" fill="{c}"/>')
        cx = x0 + cur * step - step / 2 + w / 2
        out.append(f'<rect x="{cx-30:.1f}" y="230" width="60" height="{base-230+80}" rx="10" fill="{filled}"/>')
    else:                                    # 64px and up: full ruler, major every R['majorEvery']
        n, w, cur = 31, 14, 18
        step = (x1 - x0 - w) / (n - 1)
        for i in range(n):
            x = x0 + i * step; maj = i % R['majorEvery'] == 0
            h = 260 if maj else 150
            # filled up to the cursor; beyond it majors in textMuted, minors in textMuted at opacity.disabled
            c = filled if i <= cur else major
            op = f' opacity="{T["opacity"]["disabled"]}"' if i > cur and not maj else ''
            out.append(f'<rect x="{x:.1f}" y="{base-h}" width="{w}" height="{h}" rx="3" fill="{c}"{op}/>')
        cx = x0 + cur * step + step / 2 + w / 2
        out.append(f'<rect x="{cx-12:.1f}" y="250" width="24" height="{base-250+80}" rx="6" fill="{filled}"/>')
    out.append('</svg>')
    return '\n'.join(out)

def glyph_svg():
    """Menu-bar template glyph, 18pt: black on transparent (macOS tints it). Ruler + cursor."""
    o = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" width="18" height="18">']
    for i, x in enumerate([2, 5, 8, 11, 14]):
        h = 8 if i in (0, 4) else 5
        o.append(f'<rect x="{x}" y="{14-h}" width="1.5" height="{h}" rx=".5" fill="#000" opacity="{1 if i < 2 else T['opacity']['disabled']}"/>')
    o.append('<rect x="6.25" y="2" width="1.5" height="14" rx=".75" fill="#000"/>')
    o.append('</svg>'); return '\n'.join(o)

def dmg_svg():
    """660x400 DMG window background. Assumes Finder icon centres: app (170,200), Applications (490,200), 128pt icons."""
    s = T['space']; ty = T['type']['label']
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 660 400" width="660" height="400">
<rect width="660" height="400" fill="{L['bg']}"/>
<g fill="none" stroke="{L['textMuted']}" stroke-width="{R['tickWidth']*2}" stroke-linecap="round" stroke-linejoin="round">
  <path d="M{250} 200 H{410}"/><path d="M{410 - s['3']} {200 - s['3']} L410 200 L{410 - s['3']} {200 + s['3']}"/>
</g>
<text x="330" y="{200 + s['5']*2}" text-anchor="middle" font-family="-apple-system, 'SF Pro Text', system-ui, sans-serif" font-size="{ty['size']}" font-weight="{ty['weight']}" letter-spacing="{ty['tracking']}" fill="{L['textMuted']}">Drag open-kef to Applications</text>
</svg>'''

if sys.argv[1:] == ['svg']:
    (HERE/'icon/OpenKef-icon.svg').write_text(icon_svg())
    (HERE/'icon/OpenKef-icon-small.svg').write_text(icon_svg(simple=True))
    (HERE/'menubar/MenuBarGlyph.svg').write_text(glyph_svg())
    (HERE/'dmg/dmg-background.svg').write_text(dmg_svg())
    print('svg written')
elif sys.argv[1:] == ['pack']:
    from PIL import Image
    src = HERE/'icon/AppIcon.iconset'
    Image.open(src/'icon_512x512@2x.png').save(HERE/'icon/OpenKef.icns',
        append_images=[Image.open(p) for p in sorted(src.glob('*.png'))])
    print('icns written')
