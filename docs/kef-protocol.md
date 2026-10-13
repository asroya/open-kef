# KEF speaker local control protocol (public sources)

All of this comes from community open-source projects and has **not** been verified on our own hardware yet.

## Platform split
- **W2 platform**: LS50 Wireless II, LSX II, LSX II LT, LS60 Wireless (+ newer: XIO, Muo, Coda W, LS LUXE per KEF Connect release notes). Controlled by **KEF Connect**.
- **Gen 1**: LS50 Wireless, LSX. Used KEF Control / KEF Stream apps. TCP protocol on **port 50001** (binary). Library: [aiokef](https://github.com/basnijholt/aiokef) (`AsyncKefSpeaker(port=50001)`).

open-kef targets W2.

## W2 HTTP/JSON API
- Plaintext **HTTP, port 80, no authentication** ([kefctl README](https://github.com/douglas/kefctl)).
- Discovery: mDNS `_kef-info._tcp.local.` ([kefctl](https://github.com/douglas/kefctl)).

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/getData?path=<path>&roles=value` | GET | read a value |
| `/api/setData` | POST JSON (older firmware/libs used GET with query params) | write a value / activate |
| `/api/event/modifyQueue` | POST JSON `{"subscribe":[{"path":..,"type":"itemWithValue"}],"unsubscribe":[]}` | creates/updates event queue, returns queue id |
| `/api/event/pollQueue?queueId={<uuid>}&timeout=<s>` | GET | long-poll for changes |

Sources: [pykefcontrol](https://github.com/N0ciple/pykefcontrol) (`kef_connector.py`), [N0ciple event queue gist](https://gist.github.com/N0ciple/deade052fd1a87d5b213d2e5cde31bc2), [m-lange/kef_speaker](https://github.com/m-lange/kef_speaker/blob/main/kef_connector.py). pykefcontrol changelog: 0.9 switched setData to POST for LS50WII; 0.9.2/0.9.3 same for LSX II and LS60.

### Value payloads
```json
{"path":"player:volume","roles":"value","value":{"type":"i32_","i32_":40}}
{"path":"settings:/kef/play/physicalSource","roles":"value","value":{"type":"kefPhysicalSource","kefPhysicalSource":"wifi"}}
{"path":"player:player/control","roles":"activate","value":{"control":"pause"}}   // also "next", "previous"
```
Sources (pykefcontrol): `standby, wifi, bluetooth, tv, optic, coaxial, analog` (+`usb` on some models; unverified).

### Known paths
| Path | Type in responses |
|---|---|
| `player:volume` | `i32_` |
| `settings:/mediaPlayer/mute` | `bool_` |
| `settings:/kef/play/physicalSource` | `kefPhysicalSource` |
| `settings:/kef/host/speakerStatus` | `kefSpeakerStatus` (standby / powerOn) |
| `settings:/deviceName` | `string_` |
| `settings:/kef/host/modelName` | |
| `settings:/releasetext`, `settings:/version` | firmware |
| `settings:/system/primaryMacAddress` | |
| `settings:/kef/host/maximumVolume`, `volumeStep`, `volumeLimit` | |
| `player:player/data` | now-playing (title, artist, album, icon URL, serviceID e.g. `airplay`, state, duration) |
| `player:player/data/playTime` | `i64_` ms |
| `player:player/control` | `roles=activate` |
| `kef:eqProfile`, `kef:fwupgrade/info`, `kef:speedTest/status`, `network:info` | |
| `playlists:pq/getitems`, `notifications:/display/queue` | rows |

## Other community projects
- [douglas/kefctl](https://github.com/douglas/kefctl) — Rust TUI for W2 (useful reference implementation)
- [pykefcontrol on PyPI](https://pypi.org/project/pykefcontrol/)

## Still needed from RE of KEF Connect / live speaker
1. Streaming service hand-off: how the app starts Spotify/TIDAL/Qobuz/etc. on the speaker (paths under `ui:`/`playlists:`?, auth token push).
2. Newer models (Muo, Coda W, XIO, LS LUXE): same API? Bluetooth-only control paths?
3. Onboarding / Wi-Fi setup (BLE?) and firmware update flow.
4. EQ/DSP write schema (`kef:eqProfile` structure), standby modes, wake source, sleep timer/alarm.
5. Whether recent "cybersecurity enhancements" (1.28.0 release notes) added auth/HTTPS to the local API.
6. KEF cloud account API (login, settings sync), if we need it at all.
7. Exact AirPlay / Google Cast receiver behavior on the speaker (codec, AirPlay 1 vs 2 mode).
