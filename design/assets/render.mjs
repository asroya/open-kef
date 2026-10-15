// Rasterises the SVG masters with headless Chrome (exact SVG rendering, transparent background).
import {chromium} from 'playwright-core';
import fs from 'node:fs'; import path from 'node:path'; import {fileURLToPath} from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const exe = process.env.CHROME || '/usr/bin/google-chrome';
const b = await chromium.launch({executablePath: exe, args:['--no-sandbox']});
async function shot(svg, out, w, h, scale=1){
  const p = await b.newPage({viewport:{width:w,height:h}, deviceScaleFactor:scale});
  const s = fs.readFileSync(path.join(here,svg),'utf8').replace(/width="\d+" height="\d+"/, `width="${w}" height="${h}"`);
  await p.setContent(`<html><body style="margin:0;background:transparent">${s}</body></html>`);
  await p.screenshot({path:path.join(here,out), omitBackground:true, clip:{x:0,y:0,width:w,height:h}}); await p.close();
}
fs.mkdirSync(path.join(here,'icon/AppIcon.iconset'),{recursive:true});
// 16, 16@2x, 32 and 32@2x (16/32/64px) are pixel-drawn by `make_assets.py small` (MET-10).
for (const pt of [128,256,512]) for (const sc of [1,2]) {
  const px = pt*sc, svg = 'icon/OpenKef-icon.svg';
  await shot(svg, `icon/AppIcon.iconset/icon_${pt}x${pt}${sc==2?'@2x':''}.png`, px, px);
}
for (const px of [128,256,512,1024]) await shot('icon/OpenKef-icon.svg', `icon/png/OpenKef-${px}.png`, px, px);
await shot('menubar/MenuBarGlyph.svg','menubar/MenuBarGlyphTemplate.png',18,18,1);
await shot('menubar/MenuBarGlyph.svg','menubar/MenuBarGlyphTemplate@2x.png',18,18,2);
await shot('dmg/dmg-background.svg','dmg/dmg-background.png',660,400,1);
await shot('dmg/dmg-background.svg','dmg/dmg-background@2x.png',660,400,2);
await b.close(); console.log('rendered');
