# Generates the three MET-7 direction mockups. Every CSS value comes from design/tokens.json via var(--*),
# except 0, 1pt hairlines (tokens.rules: "a 1pt line"), and percentages for slider fill (data, not style).
import json,pathlib
T=json.load(open('../../design/tokens.json'))
def cssvars():
    L,D=T['color']['light'],T['color']['dark']
    v=[f'--{k}:{x};' for k,x in L.items()]
    d=[f'--{k}:{x};' for k,x in D.items()]
    for k,x in T['space'].items(): v.append(f'--s{k}:{x}px;')
    for k,x in T['radius'].items(): v.append(f'--r-{k}:{x}px;')
    for k,x in T['size'].items(): v.append(f'--{k}:{x}px;')
    for k,t in T['type'].items():
        v.append(f'--{k}-size:{t["size"]}px;--{k}-weight:{t["weight"]};--{k}-track:{t["tracking"]}px;--{k}-lh:{t["lineHeight"]}px;')
    v.append(f'--focus-w:{T["focus"]["width"]}px;--focus-o:{T["focus"]["offset"]}px;--o-disabled:{T["opacity"]["disabled"]};')
    v.append(f'--fast:{T["motion"]["fast"]}ms;--base:{T["motion"]["base"]}ms;--ease:ease-out;')
    return ':root{'+''.join(v)+'}\n@media (prefers-color-scheme:dark){:root{'+''.join(d)+'}}'
BASE=cssvars()+'''
*{box-sizing:border-box}
html{-webkit-font-smoothing:antialiased}
body{margin:0;background:var(--surface);font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","SF Pro",system-ui,sans-serif;color:var(--text);
 font-size:var(--body-size);line-height:var(--body-lh);padding:var(--s6)}
.board{display:flex;flex-wrap:wrap;gap:var(--s6);align-items:flex-start}
.state{display:flex;flex-direction:column;gap:var(--s2)}
.state>.cap{font-size:var(--label-size);font-weight:var(--label-weight);letter-spacing:var(--label-track);line-height:var(--label-lh);color:var(--textMuted)}
.prov{color:var(--textMuted);font-style:italic}
.panel{width:var(--panelWidth);background:var(--bg);border:1px solid var(--line);border-radius:var(--r-panel);padding:var(--s3);user-select:none;cursor:default}
.t{font-size:var(--title-size);font-weight:var(--title-weight);letter-spacing:var(--title-track);line-height:var(--title-lh)}
.b{font-size:var(--body-size);line-height:var(--body-lh)}
.l{font-size:var(--label-size);font-weight:var(--label-weight);letter-spacing:var(--label-track);line-height:var(--label-lh)}
.mu{color:var(--textMuted)}
.n{font-size:var(--numeric-size);font-weight:var(--numeric-weight);letter-spacing:var(--numeric-track);line-height:var(--numeric-lh);font-variant-numeric:tabular-nums;font-feature-settings:"tnum"}
.tn{font-variant-numeric:tabular-nums}
.danger{color:var(--danger)}
.ell{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}
.art{width:var(--art);height:var(--art);border-radius:var(--r-art);background:var(--surface);border:1px solid var(--line);flex:none;display:grid;place-items:center;color:var(--textMuted)}
.hit{width:var(--iconHit);height:var(--iconHit);border-radius:var(--r-control);display:grid;place-items:center;border:0;background:none;color:var(--text);padding:0;flex:none;cursor:default;font:inherit}
.hit:hover{background:var(--surface)}
.hit:focus-visible,.seg button:focus-visible,.row:focus-visible,.srcs button:focus-visible,input:focus-visible{outline:var(--focus-w) solid var(--accent);outline-offset:var(--focus-o)}
.hit[disabled],button[disabled]{opacity:var(--o-disabled)}
svg.g{width:var(--s4);height:var(--s4);fill:none;stroke:currentColor;stroke-width:1.5;stroke-linecap:round;stroke-linejoin:round}
svg.g.f{fill:currentColor;stroke:none}
.slider{position:relative;height:var(--iconHit);display:flex;align-items:center}
.slider .tr{position:relative;width:100%;height:var(--slider);border-radius:var(--r-control);background:var(--line)}
.slider .fi{position:absolute;inset:0 auto 0 0;border-radius:var(--r-control);background:var(--accent)}
.slider .th{position:absolute;top:50%;width:var(--s3);height:var(--s3);margin:calc(var(--s3) / -2) 0 0 calc(var(--s3) / -2);border-radius:var(--r-control);background:var(--bg);border:1px solid var(--textMuted)}
.slider input{position:absolute;inset:0;width:100%;opacity:0;margin:0}
.hr{height:1px;background:var(--line);margin:var(--s2) calc(var(--s3) * -1)}
.spin{width:var(--s3);height:var(--s3);border-radius:var(--r-control);border:1px solid var(--line);border-top-color:var(--text);flex:none}
@keyframes sp{to{transform:rotate(1turn)}}
@media (prefers-reduced-motion:reduce){.spin{animation:none}*{transition:none!important}}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}
'''
I={ # icons (SF Symbol stand-ins)
'play':'<svg class="g f" viewBox="0 0 16 16"><path d="M5 3.5v9l7-4.5z"/></svg>',
'pause':'<svg class="g f" viewBox="0 0 16 16"><rect x="4" y="3.5" width="3" height="9" rx="1"/><rect x="9" y="3.5" width="3" height="9" rx="1"/></svg>',
'prev':'<svg class="g f" viewBox="0 0 16 16"><path d="M8 8l5-4v8zM3 8l5-4v8z"/></svg>',
'next':'<svg class="g f" viewBox="0 0 16 16"><path d="M8 8L3 4v8zM13 8L8 4v8z"/></svg>',
'spk':'<svg class="g" viewBox="0 0 16 16"><rect x="4" y="1.5" width="8" height="13" rx="1.5"/><circle cx="8" cy="10" r="2"/><circle cx="8" cy="4.5" r=".6"/></svg>',
'vol0':'<svg class="g" viewBox="0 0 16 16"><path d="M2.5 6h2.5l3-2.5v9l-3-2.5H2.5z"/></svg>',
'vol':'<svg class="g" viewBox="0 0 16 16"><path d="M2.5 6h2.5l3-2.5v9l-3-2.5H2.5z"/><path d="M10.5 5.5a3.5 3.5 0 0 1 0 5M12.5 3.5a6.3 6.3 0 0 1 0 9"/></svg>',
'note':'<svg class="g" viewBox="0 0 16 16"><path d="M6 12V3.5l7-1.5v8.5"/><circle cx="4.5" cy="12" r="1.5"/><circle cx="11.5" cy="10.5" r="1.5"/></svg>',
'check':'<svg class="g" viewBox="0 0 16 16"><path d="M3.5 8.5l3 3 6-7"/></svg>',
'warn':'<svg class="g" viewBox="0 0 16 16"><path d="M8 2l6.5 11.5h-13z"/><path d="M8 6.5v3M8 11.6v.1"/></svg>',
'power':'<svg class="g" viewBox="0 0 16 16"><path d="M8 2v6M4.5 4.5a5 5 0 1 0 7 0"/></svg>',
}
SOURCES=[('wifi','Wi-Fi'),('bluetooth','Bluetooth'),('tv','TV'),('optic','Optical'),('usb','USB')]
TRACK=('Teardrop','Massive Attack')  # placeholder copy for the mockup, not live data
STATES=[('playing','Playing',False),('paused','Paused',False),('offline','Speaker offline · provisional (MET-6)',True),('switching','Changing source · provisional (MET-6)',True)]
def page(name,thesis,css,panel_fn,states=None):
    states=states or STATES
    out=f'<!doctype html><html lang="en"><!-- impeccable-disable tiny-text: tokens.json v0.2 rule "11pt label is allowed: macOS menu-bar scale" --><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>open-kef · MET-7 · {name}</title><style>{BASE}{css}</style></head><body>'
    out+=f'<p class="l mu" style="margin:0 0 var(--s1)">MET-7 · open-kef menu-bar panel</p><h1 class="t" style="margin:0 0 var(--s1)">{name}</h1><p class="b mu" style="margin:0 0 var(--s5);max-width:calc(var(--panelWidth) * 2)">{thesis}</p><div class="board">'
    for sid,cap,prov in states:
        out+=f'<figure class="state" id="{sid}" style="margin:0"><figcaption class="cap{" prov" if prov else ""}">{cap}</figcaption>{panel_fn(sid)}</figure>'
    return out+'</div></body></html>'

def np_strip(sid, compact=False):
    off=sid=='offline'; sw=sid=='switching'
    if off: title,sub='Not playing','—'
    elif sw: title,sub='Switching to TV…','Now playing will update'
    else: title,sub=TRACK
    btn='play' if sid in('paused','offline','switching') else 'pause'
    dis=' disabled' if off or sw else ''
    return f'''<div style="display:flex;align-items:center;gap:var(--s3)"><div class="art" aria-hidden="true">{I['note']}</div>
<div class="ell" style="flex:1"><div class="b ell{' mu' if off else ''}" style="font-weight:var(--title-weight)">{title}</div><div class="l mu ell">{sub}</div></div>
<button class="hit" aria-label="Previous"{dis}>{I['prev']}</button><button class="hit" aria-label="{'Play' if btn=='play' else 'Pause'}"{dis}>{I[btn]}</button><button class="hit" aria-label="Next"{dis}>{I['next']}</button></div>'''

def head(sid):
    off=sid=='offline'
    st=f'<span class="l danger" style="display:flex;align-items:center;gap:var(--s1)">{I["warn"]}Offline</span>' if off else f'<span class="l mu">LSX II LT</span>'
    return f'<div style="display:flex;align-items:center;justify-content:space-between;gap:var(--s2);margin-bottom:var(--s3)"><span class="t">Living Room</span>{st}</div>'

def slider(v,dis=False):
    return f'<div class="slider"><div class="tr"><div class="fi" style="width:{v}%{";background:var(--textMuted)" if dis else ""}"></div>{"" if dis else f'<div class="th" style="left:{v}%"></div>'}</div><input type="range" min="0" max="100" value="{v}" aria-label="Volume"{" disabled" if dis else ""}></div>'

def cur(sid): return 'tv' if sid=='switching' else 'wifi'
VOL=40  # placeholder value, matches the protocol doc's example payload

# ---------- A: The number ----------
A_CSS='''.seg{display:grid;grid-template-columns:repeat(5,1fr);gap:var(--s1);background:var(--surface);border-radius:var(--r-control);padding:var(--s1)}
.seg button{height:var(--rowHeight);border:0;background:none;border-radius:var(--r-control);font:inherit;font-size:var(--label-size);font-weight:var(--label-weight);letter-spacing:var(--label-track);color:var(--textMuted);padding:0;cursor:default}
.seg button[aria-checked=true]{background:var(--bg);color:var(--text);border:1px solid var(--line)}
.seg button.pending{color:var(--text);border:1px dashed var(--textMuted);background:none}
.vol{display:flex;align-items:center;gap:var(--s3)}
.vol .n{width:var(--s6)}'''
def A(sid):
    off=sid=='offline'; c=cur(sid)
    seg=''.join(f'<button role="radio" aria-checked="{"true" if k==c and sid!="switching" and not off else "false"}" class="{"pending" if sid=="switching" and k==c else ""}"{" disabled" if off else ""}>{n}</button>' for k,n in SOURCES)
    note=''
    if off: note='<p class="l mu" style="margin:var(--s2) 0 0">Can’t reach Living Room. <button class="hit l" style="width:auto;padding:0 var(--s2);display:inline-flex;height:var(--s5);color:var(--text)">Retry</button></p>'
    vnum='—' if off else str(VOL)
    st=f'<span class="l danger" style="display:flex;align-items:center;gap:var(--s1)">{I["warn"]}Offline</span>' if off else '<span class="l mu">Volume</span>'
    return f'''<div class="panel" role="dialog" aria-label="open-kef">
<div style="display:flex;align-items:baseline;justify-content:space-between"><span class="l mu">Living Room · LSX II LT</span>{st}</div>
<div class="vol"><span class="n{" mu" if off else ""}" aria-live="polite">{vnum}</span><div style="flex:1">{slider(0 if off else VOL,off)}</div></div>
<div style="height:var(--s4)"></div>
<div class="seg" role="radiogroup" aria-label="Source">{seg}</div>{note}
<div class="hr"></div>{np_strip(sid)}</div>'''

# ---------- B: The menu ----------
B_CSS='''.row{display:flex;align-items:center;gap:var(--s2);height:var(--rowHeight);padding:0 var(--s2);margin:0 calc(var(--s2) * -1);border-radius:var(--r-control);border:0;background:none;width:calc(100% + var(--s4));font:inherit;color:var(--text);text-align:left;cursor:default}
.row:hover,.row.hl{background:var(--surface)}
.row .ck{width:var(--s4);display:grid;place-items:center}
.row .kb{margin-left:auto;color:var(--textMuted);font-size:var(--label-size)}
.row[disabled]{color:var(--textMuted)}
.sec{margin:var(--s1) 0 var(--s1)}
.vrow{display:flex;align-items:center;gap:var(--s2);height:var(--rowHeight)}
.vrow .tn{width:var(--s5);text-align:right;color:var(--textMuted)}'''
def B(sid):
    off=sid=='offline'; c=cur(sid)
    rows=''
    for i,(k,n) in enumerate(SOURCES,1):
        if sid=='switching' and k==c: mark='<span class="l mu">Switching…</span>'; ck=''
        else: mark=f'<span class="kb tn">⌘{i}</span>'; ck=I['check'] if k==c and sid!='switching' else ''
        if sid=='switching' and k=='wifi': ck=''
        rows+=f'<button class="row{" hl" if sid=="switching" and k==c else ""}" role="menuitemradio" aria-checked="{"true" if ck else "false"}"{" disabled" if off else ""}><span class="ck">{ck}</span>{n}{mark if not off else ""}</button>'
    status=''
    if off: status=f'<div class="b danger" style="display:flex;gap:var(--s2);align-items:center;height:var(--rowHeight)">{I["warn"]}Living Room is offline</div><button class="row"><span class="ck"></span>Try again<span class="kb">⌘R</span></button><div class="hr"></div>'
    return f'''<div class="panel" role="menu" aria-label="open-kef">{np_strip(sid)}
<div class="hr"></div>{status}
<div class="vrow"><span class="mu">{I["vol"]}</span><div style="flex:1">{slider(0 if off else VOL,off)}</div><span class="tn b">{"—" if off else VOL}</span></div>
<div class="hr"></div><div class="l mu sec">Source</div>{rows}
<div class="hr"></div><button class="row"{" disabled" if off else ""}><span class="ck">{I["power"]}</span>Standby<span class="kb">⌘S</span></button><button class="row"><span class="ck"></span>Open open-kef…<span class="kb">⌘O</span></button></div>'''

# ---------- C: The ruler ----------
C_CSS='''.spinner{position:absolute;bottom:var(--s1);left:0;width:var(--s4);height:var(--s4);border-radius:var(--r-panel);border:var(--focus-w) solid var(--line);border-top-color:var(--textMuted)}
.ruler{position:relative;height:var(--s6);margin-top:var(--s5)}
.ruler .ticks{position:absolute;left:0;right:0;bottom:0;height:var(--s3);background:repeating-linear-gradient(90deg,var(--line) 0 1px,transparent 1px var(--s1))}
.ruler .ticks.maj{height:var(--s4);background:repeating-linear-gradient(90deg,var(--textMuted) 0 1px,transparent 1px calc(var(--s1) * 10))}
.ruler .lvl{position:absolute;left:0;bottom:0;height:var(--s4);background:repeating-linear-gradient(90deg,var(--text) 0 1px,transparent 1px var(--s1))}
.ruler .cur{position:absolute;bottom:0;height:var(--s6);border-left:1px solid var(--text)}
.ruler .cur span{position:absolute;bottom:var(--s5);left:var(--s1);}
.ruler input{position:absolute;inset:0;width:100%;opacity:0;margin:0}
.srcs{display:flex;flex-wrap:wrap;gap:0 var(--s3);margin-top:var(--s4)}
.srcs button{border:0;background:none;padding:0;height:var(--iconHit);font:inherit;color:var(--textMuted);cursor:default}
.srcs button[aria-checked=true]{color:var(--text);font-weight:var(--title-weight)}
.srcs button.pending{color:var(--text);text-decoration:underline dotted;text-underline-offset:var(--s1)}
.big{display:flex;gap:var(--s3);align-items:center}'''
def C(sid):
    load=sid=='loading'; err=sid=='error'
    off=sid=='offline'; sw=sid=='switching'; c=cur(sid)
    v=0 if off or load else VOL
    title,sub=('Living Room is offline','Check power and Wi-Fi') if off else (('Switching to TV…','From Wi-Fi') if sw else (('Connecting…','Living Room') if load else TRACK))
    btn='play' if sid in('paused','offline','switching','loading') else 'pause'
    dis=' disabled' if off or sw or load else ''
    srcs=''.join(f'<button role="radio" aria-checked="{"true" if k==c and not sw and not off and not load else "false"}" class="{"pending" if sw and k==c else ""}"{" disabled" if off or load else ""}>{n}</button>' for k,n in SOURCES)
    return f'''<div class="panel" role="dialog" aria-label="open-kef">
<div class="big"><div class="art" aria-hidden="true">{"<span class=\"danger\" style=\"display:grid\">"+I["warn"]+"</span>" if off else I["note"]}</div><div class="ell" style="flex:1"><div class="t ell{" danger" if off else ""}">{title}</div><div class="b mu ell">{sub}</div></div><button class="hit" aria-label="{"Play" if btn=="play" else "Pause"}"{dis}>{I[btn]}</button></div>
<div class="ruler" aria-hidden="false"><div class="ticks"></div><div class="ticks maj"></div>{('<div class="cur" style="left:0;border:0"><span class="spinner" role="progressbar" aria-label="Loading volume"></span></div>' if load else ("" if off else f'<div class="lvl" style="width:{v}%"></div><div class="cur" style="left:{v}%"><span class="n">{v}</span></div>'))}<input type="range" min="0" max="100" value="{v}" aria-label="Volume"{" disabled" if off or load else ""}></div>
<div class="srcs" role="radiogroup" aria-label="Source">{srcs}</div>
<div style="display:flex;justify-content:space-between;align-items:center;margin-top:var(--s2)">{'<span class="b danger" role="alert">Couldn’t set volume. Reverted.</span>' if err else '<span class="l mu">Living Room · LSX II LT</span>'}{'<button class="hit l" style="width:auto;padding:0 var(--s2)">Retry</button>' if off else '<span class="l mu">'+('Switching…' if sw else '')+'</span>'}</div></div>'''

D=[('a-the-number.html','A · The number','Thesis: you open this panel to change loudness, so the volume figure is the interface. Signature: a 22pt tabular volume readout locked to the slider; everything else steps back.',A_CSS,A),
   ('b-the-menu.html','B · The menu','Thesis: a menu-bar extra should behave like a Mac menu, not a mini app. Signature: sources as real menu rows with a checkmark and ⌘1–⌘5, fully keyboard-drivable.',B_CSS,B),
   ('c-the-ruler.html','C · The ruler','Thesis: hi-fi gear is about precise level, so volume is drawn as a measuring ruler at the 4pt grid. Signature: a tick ruler (1 tick = 4pt, majors every 40pt) with the tabular level riding the cursor.',C_CSS,C)]
for fn,name,th,css,fnc in D:
    st=STATES+[('loading','Loading',False),('error','Error · command failed',False)] if fnc is C else None
    open(fn,'w').write(page(name,th,css,fnc,st))
print('written')
