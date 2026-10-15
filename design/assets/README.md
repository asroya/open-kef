# open-kef assets (MET-9)

Everything here is generated from `design/tokens.json` (v0.3.1) by `make_assets.py` and `render.mjs`.
`apps/macos` has no Assets or Resources folder yet. It's a SwiftPM menu-bar app whose `MenuBarExtra` uses the SF Symbol `hifispeaker`, so the assets live here until the app has a bundle step.

## Files
| Path | What | Sizes |
|---|---|---|
| `icon/OpenKef-icon.svg` | App icon master (64px and up) | 1024 viewBox |
| `icon/OpenKef-icon-small.svg` | Simplified master for 16px and 32px (5 heavy ticks and cursor) | 1024 viewBox |
| `icon/AppIcon.iconset/` | `icon_{16,32,128,256,512}x…{,@2x}.png` | 16 to 1024px |
| `icon/png/OpenKef-{16,32,64,128,256,512,1024}.png` | Flat exports, including 64 | |
| `icon/OpenKef.icns` | Built with Pillow from the iconset | |
| `menubar/MenuBarGlyph.svg` | Template-image master: black on transparent, macOS tints it | 18pt |
| `menubar/MenuBarGlyphTemplate.png`, `@2x.png` | Template PNGs (the `Template` suffix makes AppKit treat them as template images) | 18 / 36px |
| `dmg/dmg-background.svg`, `.png`, `@2x.png` | DMG window background | 660×400 / 1320×800 |
| `met-9-preview.png` | Every icon size on light and dark grounds, the glyph, and the DMG with assumed icon slots | |

## Design
- **Motif:** direction C's ruler, with filled ticks up to a tall cursor. Majors fall every `ruler.majorEvery` ticks.
- **Body:** a rounded square on Apple's macOS grid (824pt inset 100pt on a 1024 canvas, corner radius ≈185.4). The continuous corner is approximated with Béziers.
- **Colours** (all from `color.dark`):
  - Body: `bg`, with a `line` edge so it holds on dark wallpapers.
  - Ticks: filled in `text`; majors and remaining ticks in `textMuted`.
  - Unfilled minor ticks: `textMuted` at `opacity.disabled`.
- **Not tokens:** the icon's internal geometry (tick and cursor sizes, the 8-unit edge) is canvas geometry, which tokens don't cover. No drop shadow is drawn; `material.panel` defers elevation to the system.
- **DMG background:**
  - Colours: `color.light.bg`; the arrow is `textMuted` at 2× `ruler.tickWidth`.
  - Arrowhead: `space.3`.
  - Caption: `type.label`, placed `space.5`×2 below the arrow.

## DMG icon positions (Finder window 660×400, icon size 128)
- open-kef.app is centred at **(170, 200)** and the Applications link at **(490, 200)**.
- The arrow runs from x 250 to 410 at y 200.
- Example for `create-dmg`: `--window-size 660 400 --icon-size 128 --icon "open-kef.app" 170 200 --app-drop-link 490 200 --background dmg-background.png`.

## Regenerate
```sh
cd design/assets
python3 make_assets.py svg        # SVG masters from tokens.json
node render.mjs                   # needs playwright-core + Chrome (CHROME=/path); PNG exports
python3 make_assets.py pack       # OpenKef.icns via Pillow
python3 preview.py                # met-9-preview.png
```
On a Mac you can instead run `iconutil -c icns icon/AppIcon.iconset -o icon/OpenKef.icns`.
