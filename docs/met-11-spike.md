# MET-11 spike: now-playing, source switching, AirPlay 2 from the Mac

LSX II LT, firmware LSXIILT_V2186, 192.168.18.36, HTTP :80, no auth. 2026-10-15. Read-only except the source test in section 2.

## 1. Now playing (`player:player/data`)

On TV (live):
```json
{"playId":{"timestamp":5244109873,"systemMemberId":"lsxlite-…"},"state":"playing","error":"",
 "controls":{"next_":false,"previous":false,"pause":false},
 "trackRoles":{"path":"kef:/playlogic/TV","title":"TV","audioType":"audioBroadcast","type":"audio",
   "mediaData":{"metaData":{"serviceID":"TV","playLogicPath":"kef:/playlogic"}}},
 "mediaRoles":{ …same as trackRoles… }}
```
On Wi-Fi with nothing streaming (live): `{"state":"stopped","trackRoles":{},"mediaRoles":{},"streamerError":{},"keepActive":false,…}`.

| Field | Where | Seen live |
|---|---|---|
| state | `state` (`playing` / `stopped`; `paused` in ApiLib) | yes |
| title | `trackRoles.title` | yes ("TV") |
| service | `trackRoles.mediaData.metaData.serviceID` (`TV`, `AUX`, …) | yes |
| artist / album / albumArtist | `trackRoles.mediaData.metaData.{artist,album,albumArtist}` | ApiLib strings only |
| artwork | `trackRoles.icon` | ApiLib strings only |
| duration | `trackRoles.mediaData.metaData.duration` / `status.duration` (unconfirmed nesting) | ApiLib strings only |
| position | `player:player/data/playTime` (`i64_`, ms; `-1` on TV) | yes |
| controls | `controls.{next_, previous, pause}` | yes |

- **Bug found:** the key is **`next_`**, not `next`. `crates/core/src/state.rs` reads `next`, so `controls.next` is always false. That's a one-line fix (read `next_`).
- Artist, album, artwork and duration need a streaming source to confirm (Spotify, AirPlay or a preset). Nothing was streaming on Wi-Fi.
- **Events work:** `POST /api/event/modifyQueue` with `{"subscribe":[{"path":"player:player/data","type":"itemWithValue"},{"path":"player:volume","type":"itemWithValue"},{"path":"settings:/kef/play/physicalSource","type":"itemWithValue"}],"unsubscribe":[]}` returns a queue id string in braces (`"{uuid}"`, braces included). Then `GET /api/event/pollQueue?queueId={uuid}&timeout=N` returns `[]` or a list of `{path, itemType:"update", itemValue}`. A single source switch produced 3 events in one poll: source, player data, and volume.
- `getRows ui:` lists the service containers (Spotify, Qobuz Connect, TIDAL/Amazon/Deezer via airable, AirPlay 2, Google Cast, Bluetooth, AUX, SPDIF). `player:player/control` exists for transport commands.

## 2. Source switch from code (done, restored)

```
POST /api/setData
{"path":"settings:/kef/play/physicalSource","roles":"value",
 "value":{"type":"kefPhysicalSource","kefPhysicalSource":"wifi"}}
→ {"timestamp":…,"value":{"kefPhysicalSource":"wifi","type":"kefPhysicalSource"}}
```
- Confirmed by `getData` and by the event queue.
- The volume jumped from 49 (TV) to 35 (Wi-Fi) because each source keeps its own volume (`settings:/kef/host/defaultVolume{Wifi,TV,…}`).
- After switching back to `tv`, the volume was 49 again. I also set `player:volume` to `{"type":"i32_","i32_":49}` explicitly.
- **End state matches the start:** TV, 49, playing.
- **For the app:** after a switch, re-read the volume from the event rather than assuming it carries over.

## 3. Mac audio to the KEF over AirPlay 2

- The KEF advertises AirPlay 2 (`_airplay._tcp` and `_raop._tcp` as "KEF LSX II Speaker", `dns-sd -B`).
- **CoreAudio doesn't list it.** `kAudioHardwarePropertyDevices` returns only "Mac mini Speakers" (`bltn`, default, data source `ispk`) and the LG monitor (`dprt`). No AirPlay device appears while nothing is routed to AirPlay. macOS creates the AirPlay audio device only once a route is chosen in Control Center or the Sound settings. Script: `/tmp/met11-devs.swift` (not in the repo).
- **Public API:** `AVRoutePickerView` (AVKit, macOS 10.15+) shows the system route picker, and the user picks the KEF in a popover. The app can't pick it programmatically. https://developer.apple.com/documentation/avkit/avroutepickerview
- **Private API:** choosing a route programmatically means `AVOutputContext` / `AVOutputDevice` (private AVFoundation, used by tools such as Airfoil-style switchers). That's App Store-hostile and can break with any macOS update. Once the AirPlay device exists, CoreAudio's `kAudioHardwarePropertyDefaultOutputDevice` can switch to it, but it can't create it.
- **Alternative:** implement AirPlay 2 sending ourselves. RAOP/AirPlay 1 is doable (open source in shairport-sync's sender side and pyatv). AirPlay 2 needs HomeKit pairing and a large amount of work.

## Recommendation
1. Fix `next_` now. Build the now-playing UI on `trackRoles` + `mediaData.metaData` + `playTime`, and confirm artist, album, artwork and duration with a streaming source.
2. Keep source switching as is. Treat the per-source volume as authoritative from events.
3. AirPlay: ship an `AVRoutePickerView` button (public, about 20 lines). Don't use private `AVOutputContext`. Don't build our own AirPlay 2 sender unless there's a strong reason.

## Implemented on met-11 (no UI)
- `controls.next` reads the speaker's `next_` (and `next`).
- Event loop applies pollQueue values directly (`SpeakerState::apply_event`), so after a source switch the volume comes from the event (recorded tv→wifi test: 49 → 35). Unmodelled paths fall back to a full refetch.
- `MusicNowPlaying.swift`: Music.app track via AppleScript, only if `com.apple.Music` is already running. `OpenKef --music-now-playing` prints it.
- **Info.plist needs** `NSAppleEventsUsageDescription` ("open-kef reads what's playing in Music to show it in the panel."). `scripts/package_dmg.sh` lives on met-9 (PR #5), not main, so add the key there once that's merged. Ad-hoc/SwiftPM binaries also need the user's Automation consent for Music.
