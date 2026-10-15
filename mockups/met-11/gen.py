# MET-11 Now Playing window mockup. CSS values come from design/tokens.json (v0.4) via var(--*),
# except 0, 1pt hairlines (tokens.rules) and percentages for data (volume level).
# Window chrome (title bar, traffic lights) is a stand-in for the native NSWindow; see README token requests.
import json, pathlib
H = pathlib.Path(__file__).parent
T = json.load(open(H / '../../design/tokens.json'))
def cssvars():
    L, D = T['color']['light'], T['color']['dark']
    v = [f'--{k}:{x};' for k, x in L.items()]; d = [f'--{k}:{x};' for k, x in D.items()]
    v += [f'--s{k}:{x}px;' for k, x in T['space'].items()]
    v += [f'--r-{k}:{x}px;' for k, x in T['radius'].items()]
    v += [f'--{k}:{x}px;' for k, x in T['size'].items()]
    for k, t in T['type'].items():
        v.append(f'--{k}-size:{t["size"]}px;--{k}-weight:{t["weight"]};--{k}-track:{t["tracking"]}px;--{k}-lh:{t["lineHeight"]}px;')
    v.append(f'--focus-w:{T["focus"]["width"]}px;--focus-o:{T["focus"]["offset"]}px;--o-disabled:{T["opacity"]["disabled"]};--icon:{T["icon"]["size"]}px;--tick:{T["ruler"]["tickWidth"]}px;')
    v += [f'--window-{k}:{x}px;' for k, x in T['window'].items()]
    def resolve(ref):
        cur = T
        for part in ref.split('.'):
            cur = cur[part]
        return cur
    bp = T['button']['primary']
    v.append(f'--status-dot:{T["status"]["dot"]}px;')
    v.append(f'--btn-primary-h:{resolve(bp["height"])}px;--btn-primary-px:{resolve(bp["paddingX"])}px;--btn-primary-r:{resolve(bp["radius"])}px;')
    v.append(f'--btn-primary-weight:{bp["labelWeight"]};')
    return ':root{' + ''.join(v) + '}', ':root{' + ''.join(d) + '}'
LIGHT, DARK = cssvars()
CSS = LIGHT + '\n.dark{' + DARK[6:] + '\n' + '''
*{box-sizing:border-box}html{-webkit-font-smoothing:antialiased}
body{margin:0;background:var(--surface);font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","SF Pro",system-ui,sans-serif;
 font-size:var(--body-size);line-height:var(--body-lh);color:var(--text);padding:var(--s6)}
.board{display:flex;flex-wrap:wrap;gap:var(--s6);align-items:flex-start}
figure{margin:0;display:flex;flex-direction:column;gap:var(--s2)}
figcaption{font-size:var(--label-size);font-weight:var(--label-weight);letter-spacing:var(--label-track);line-height:var(--label-lh);color:var(--textMuted)}
.t{font-size:var(--title-size);font-weight:var(--title-weight);letter-spacing:var(--title-track);line-height:var(--title-lh)}
.l{font-size:var(--label-size);font-weight:var(--label-weight);letter-spacing:var(--label-track);line-height:var(--label-lh)}
.n{font-size:var(--numeric-size);font-weight:var(--numeric-weight);letter-spacing:var(--numeric-track);line-height:var(--numeric-lh);font-variant-numeric:tabular-nums}
.mu{color:var(--textMuted)}.danger{color:var(--danger)}
.ell{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}
.win{width:var(--window-width);min-width:var(--window-minWidth);background:var(--bg);color:var(--text);border:1px solid var(--line);border-radius:var(--r-panel);overflow:hidden}
.bar{height:var(--rowHeight);display:flex;align-items:center;gap:var(--s2);padding:var(--s1) var(--s3);border-bottom:1px solid var(--line);background:var(--surface)}
.lights{display:flex;gap:var(--s2)}.lights i{width:var(--s3);height:var(--s3);border-radius:var(--r-control);border:1px solid var(--line);background:var(--bg)}
.bar .ttl{flex:1;text-align:center}
.status{display:flex;align-items:center;gap:var(--s1)}
.dot{width:var(--status-dot);height:var(--status-dot);border-radius:50%;background:var(--text)}
.dot.off{background:var(--danger)}
.body{padding:var(--s5) var(--s5) var(--s4)}
section{padding:var(--s4) 0;border-top:1px solid var(--line)}
section:first-child{border-top:0;padding-top:0}
.sh{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:var(--s2)}
.np{display:flex;gap:var(--s4);align-items:center}
.art{width:var(--artLarge);height:var(--artLarge);border-radius:var(--r-art);background:var(--surface);border:1px solid var(--line);display:grid;place-items:center;color:var(--textMuted);flex:none}
.hit{width:var(--iconHit);height:var(--iconHit);border-radius:var(--r-control);display:grid;place-items:center;border:0;background:none;color:var(--text);padding:0;flex:none;font:inherit;cursor:default}
.hit:hover{background:var(--surface)}
button[disabled]{opacity:var(--o-disabled)}
button:focus-visible,input:focus-visible{outline:var(--focus-w) solid var(--accent);outline-offset:var(--focus-o)}
svg.g{width:var(--icon);height:var(--icon);fill:none;stroke:currentColor;stroke-width:1.5;stroke-linecap:round;stroke-linejoin:round}
svg.g.f{fill:currentColor;stroke:none}
.ruler{position:relative;height:var(--s6);margin-top:var(--s5)}
.ruler .ticks{position:absolute;left:0;right:0;bottom:0;height:var(--s3);background:repeating-linear-gradient(90deg,var(--line) 0 var(--tick),transparent var(--tick) var(--s1))}
.ruler .ticks.maj{height:var(--s4);background:repeating-linear-gradient(90deg,var(--textMuted) 0 var(--tick),transparent var(--tick) calc(var(--s1) * 10))}
.ruler .lvl{position:absolute;left:0;bottom:0;height:var(--s4);background:repeating-linear-gradient(90deg,var(--text) 0 var(--tick),transparent var(--tick) var(--s1))}
.ruler .cur{position:absolute;bottom:0;height:var(--s6);border-left:var(--tick) solid var(--text)}
.ruler .cur span{position:absolute;bottom:var(--s5);left:var(--s1)}
.ruler input{position:absolute;inset:0;width:100%;opacity:0;margin:0}
.btn{height:var(--btn-primary-h);padding:0 var(--btn-primary-px);border-radius:var(--btn-primary-r);border:1px solid var(--line);background:var(--bg);color:var(--text);font:inherit;font-size:var(--body-size);font-weight:var(--btn-primary-weight);line-height:var(--body-lh);display:inline-flex;align-items:center;gap:var(--s2);cursor:default;flex:none}
.btn.primary{background:var(--accent);color:var(--bg);border-color:var(--accent)}
.row{display:flex;align-items:center;gap:var(--s3);min-height:var(--rowHeight)}
.srcs{display:flex;flex-wrap:wrap;gap:0 var(--s4)}
.srcs button{border:0;background:none;padding:0;height:var(--iconHit);font:inherit;color:var(--textMuted);cursor:default}
.srcs button[aria-checked=true]{color:var(--text);font-weight:var(--title-weight)}
.svc{display:grid;grid-template-columns:1fr auto;gap:var(--s1) var(--s3);align-items:center;padding:var(--s2) 0}
.svc+.svc{border-top:1px solid var(--line)}
.prov{font-style:italic}
.art.danger{color:var(--danger)}
.foot{display:flex;justify-content:space-between;gap:var(--s3);padding:var(--s2) var(--s5);border-top:1px solid var(--line);background:var(--surface)}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
'''
I = {'play': '<svg class="g f" viewBox="0 0 16 16"><path d="M5 3.5v9l7-4.5z"/></svg>',
     'pause': '<svg class="g f" viewBox="0 0 16 16"><rect x="4" y="3.5" width="3" height="9" rx="1"/><rect x="9" y="3.5" width="3" height="9" rx="1"/></svg>',
     'prev': '<svg class="g f" viewBox="0 0 16 16"><path d="M8 8l5-4v8zM3 8l5-4v8z"/></svg>',
     'next': '<svg class="g f" viewBox="0 0 16 16"><path d="M8 8L3 4v8zM13 8L8 4v8z"/></svg>',
     'note': '<svg class="g" viewBox="0 0 16 16"><path d="M6 12V3.5l7-1.5v8.5"/><circle cx="4.5" cy="12" r="1.5"/><circle cx="11.5" cy="10.5" r="1.5"/></svg>',
     'airplay': '<svg class="g" viewBox="0 0 16 16"><path d="M4 11.5H2.5v-8h11v8H12"/><path d="M8 9.5l3.5 4h-7z"/></svg>',
     'warn': '<svg class="g" viewBox="0 0 16 16"><path d="M8 2l6.5 11.5h-13z"/><path d="M8 6.5v3M8 11.6v.1"/></svg>'}
# MET-6: LSX II LT inputs (model note, inferred) and the confirmed kefPhysicalSource values among them
SOURCES = [('wifi', 'Wi-Fi'), ('bluetooth', 'Bluetooth'), ('tv', 'TV'), ('optical', 'Optical'), ('usb', 'USB')]
VOL = 40  # placeholder level (protocol doc example)
STATES = [('airplay', 'Playing · Apple Music over AirPlay'), ('mac', 'AirPlay from this Mac'),
          ('idle', 'Idle · no media'), ('offline', 'Offline')]

def window(sid):
    off = sid == 'offline'; idle = sid == 'idle'; ap = sid == 'airplay'; mac = sid == 'mac'
    src = 'wifi'
    if ap: art, title, sub, via = I['note'], 'Teardrop', 'Massive Attack · Mezzanine', 'AirPlay 2 · Wi-Fi'
    elif mac: art, title, sub, via = I['airplay'], 'This Mac', 'System audio', 'AirPlay 2 from this Mac · Wi-Fi'
    elif idle: art, title, sub, via = I['note'], 'Nothing playing', 'Living Room · Wi-Fi', 'Wi-Fi'
    else: art, title, sub, via = I['warn'], 'Living Room is offline', 'Check that the speaker is on and on this network', ''
    playing = ap or mac
    dis = ' disabled' if off or idle else ''
    status = ('<span class="status l danger"><i class="dot off"></i>Offline</span>' if off
              else '<span class="status l mu"><i class="dot"></i>Connected</span>')
    ruler = ('' if off else f'<div class="lvl" style="width:{VOL}%"></div><div class="cur" style="left:{VOL}%"><span class="n">{VOL}</span></div>')
    srcs = ''.join(f'<button role="radio" aria-checked="{"true" if k == src and not off else "false"}"{" disabled" if off else ""}>{n}</button>' for k, n in SOURCES)
    # The single primary action: system AirPlay picker (AVRoutePickerView)
    head = 'This Mac is playing on Living Room' if mac else 'Play to Living Room with AirPlay'
    note = 'Mac output is set to Living Room · AirPlay 2' if mac else 'Opens the AirPlay menu. Pick Living Room as the output.'
    airplay = (f'<div class="row"><div class="ell" style="flex:1"><div style="font-weight:var(--title-weight)">{head}</div>'
               f'<div class="mu ell">{note}</div></div><button class="btn primary" aria-haspopup="menu"{" disabled" if off else ""}>{I["airplay"]}AirPlay</button></div>')
    ytm = ('<div class="svc"><div><div style="font-weight:var(--title-weight)">YouTube Music</div>'
           '<div class="mu">On this Mac: play it in Safari, then choose Living Room from Safari’s AirPlay button.</div>'
           '<div class="mu">On your phone: tap Cast in the YouTube Music app and choose Living Room (Google Cast).</div></div></div>')
    btn = 'pause' if playing else 'play'
    viahtml = '' if off else f'<div class="l mu ell">{via}</div>'
    subhtml = f'<div class="mu ell">{sub}</div>' if sub else ''
    return f'''<div class="win" role="dialog" aria-label="OpenKef">
<div class="bar"><div class="lights" aria-hidden="true"><i></i><i></i><i></i></div><span class="ttl l">OpenKef</span>{status}</div>
<div class="body">
<section aria-label="Now playing"><div class="np"><div class="art{" danger" if off else ""}" aria-hidden="true">{art}</div>
<div class="ell" style="flex:1"><div class="t ell{" danger" if off else (" mu" if idle else "")}">{title}</div>{subhtml}{viahtml}</div>
<button class="hit" aria-label="Previous"{dis}>{I["prev"]}</button><button class="hit" aria-label="{btn.title()}"{dis}>{I[btn]}</button><button class="hit" aria-label="Next"{dis}>{I["next"]}</button></div>
<div class="ruler"><div class="ticks"></div><div class="ticks maj"></div>{ruler}<input type="range" min="0" max="100" value="{0 if off else VOL}" aria-label="Volume"{" disabled" if off else ""}></div></section>
<section aria-label="AirPlay">{airplay}</section>
<section aria-label="Input"><div class="sh"><span class="l mu">Input</span></div><div class="srcs" role="radiogroup" aria-label="Input">{srcs}</div></section>
<section aria-label="Other apps"><div class="sh"><span class="l mu">Other apps</span></div>{ytm}</section>
</div>
<div class="foot"><span class="l mu">Living Room · LSX II LT</span><span class="l mu">{"Last seen on this network" if off else "Wi-Fi input"}</span></div></div>'''

def page():
    out = f'<!doctype html><html lang="en"><!-- impeccable-disable tiny-text: tokens.json rule "11pt label is allowed: macOS menu-bar scale" --><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OpenKef · MET-11 · Now Playing window</title><style>{CSS}</style></head><body>'
    out += '<p class="l mu" style="margin:0 0 var(--s1)">MET-11 · OpenKef v0.2</p><h1 class="t" style="margin:0 0 var(--s5)">Now Playing window</h1>'
    for theme in ('light', 'dark'):
        out += f'<div class="board {theme}" style="margin-bottom:var(--s6)">'
        for sid, cap in STATES:
            out += f'<figure id="{sid}-{theme}" class="{theme}" style="background:var(--surface);padding:var(--s4)"><figcaption>{cap} · {theme}</figcaption>{window(sid)}</figure>'
        out += '</div>'
    return out + '</body></html>'
(H / 'now-playing-window.html').write_text(page()); print('written')
