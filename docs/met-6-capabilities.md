# MET-6 — KEF LSX II LT (W2) capability audit

Source: KEF Connect **1.31.0** (iPad build), unencrypted frameworks only (`ApiLib`, `HttpLib`,
`NetworkLib`, `KEFUtility`; `cryptid 0`). Main binary is encrypted and was not touched.
Method: static string/symbol extraction (`strings`, Swift mangled symbols). No speaker or cloud host was contacted.
Binaries and dumps live in `/workspace/kefre` on the box, not in git.

**Confirmed** = the literal path/string exists in ApiLib. **Inferred** = deduced from symbol names, log
strings, or community docs; needs a live test against our LSX II LT.

## Transport and endpoints

| Capability | Evidence (ApiLib) | Status |
|---|---|---|
| Read a value | `/api/getData` | Confirmed path |
| Write / trigger | `/api/setData`, request body keys `path`, `roles` (`value`/`activate`), `value`, typed values `i32_`, `bool_`, `string_`, `kefPhysicalSource`, `kefSpeakerStatus` | Confirmed |
| List rows (queues, presets, browse) | `/api/getRows`, `ApiResponseGetRowsAccumulator.swift` | Confirmed path |
| Event subscribe | `/api/event/modifyQueue` (`subscribe`, `queueId`) | Confirmed |
| Event long-poll | `/api/event/pollQueue` (`queueId`, `timeout`); log "Event poller has lost subscription. Re-subscribing on the next loop..." | Confirmed |
| Push notifications on poll | `notifications:/player/playing`, `notifications:/display/queue` | Confirmed path |

## "Cybersecurity" change (important)

| Finding | Evidence | Status |
|---|---|---|
| HTTPS on **port 4430** alongside HTTP | "Got prove by poller that 4430 is fine. Switch back from restricted mode to normal!", `isHttps`, `updatedForHttps`, `wasTransmissionToHTTPS` | Confirmed strings; port semantics inferred |
| Self-signed / pinned speaker cert | `SecTrustSetAnchorCertificates(Only)`, `SecCertificateCreateWithData`, `NSURLAuthenticationChallenge` delegate | Inferred: app trusts a custom anchor, not public CAs |
| HTTP Basic auth with speaker user | `Authorization`, `basicHeaderValue(for:)`, `usernameBase64`, `ApiSpeakerCredentials`, "HTTP 401 (Not Authorized)" | Inferred: Basic auth on HTTPS firmware |
| Speaker user management | `webserver:addUser`, `webserver:changePassword` (`oldPassword`/`newPassword`), `checkSpeakerMasterKey`, `kef:verifyKey/result`, "Credentials are set, set credentials to the speaker!" | Confirmed paths; flow inferred (app creates its own user on the speaker, guarded by a master key) |
| Fallback modes | "Broken security speaker behaviour was detected. Switch to restricted/emergency mode!", `ApiBrokenHTTPSReason`, `isBrokenHTTPSSpeaker` | Confirmed: app tolerates HTTP-only / half-migrated firmware |

**Implication for open-kef:** keep plain HTTP:80 (works on older firmware), add HTTPS:4430 + Basic auth path
as a fallback once we see what our speaker's firmware does. Need to test: does `:80` still answer on current
LSX II LT firmware, and what credentials does a fresh speaker accept (master key source is in the encrypted binary — unknown).

## Setting paths relevant to the menu-bar panel

| Feature | Path(s) | Status |
|---|---|---|
| Volume | `player:volume` (`i32_`), limits `settings:/kef/host/maximumVolume`, `volumeLimit`, `volumeStep` | Confirmed |
| Mute | `settings:/mediaPlayer/mute` (`bool_`) | Confirmed |
| Source | `settings:/kef/play/physicalSource` (`kefPhysicalSource`) | Confirmed |
| Source enum values | `standby, wifi, bluetooth, tv, optical, coaxial, analog, usb` | Confirmed — **`optical`, not `optic`** (core fixed) |
| Power / standby | `settings:/kef/host/speakerStatus` (`kefSpeakerStatus`: `standby`/`powerOn`/`networkSetup`/`firmwareUpgrade`); standby = set source `standby`; `powermanager:target`, `powermanager:goReboot`; `settings:/kef/host/standbyMode`, `wakeUpSource` | Confirmed paths |
| Transport | `player:player/control` (`activate`, `control`: `play`, `pause`, `stop`, `next`, `previous`); repeat/shuffle `settings:/mediaPlayer/playMode` (`repeatOne`/`repeatAll`/`shuffle`) | Confirmed |
| Now playing | `player:player/data` → `state` (`playing`/`paused`/`stopped`), `trackRoles` (`title`, `icon` = artwork URL), `mediaData.metaData` (`artist`, `album`, `albumArtist`), `status.duration`; `player:player/data/playTime` | Confirmed keys; exact JSON nesting inferred from community docs |
| Audio format | `imx8af:decoderInfoCodecString`, MQA info (`MqaState`, `originalSampleRate`) | Confirmed path |
| EQ / DSP | `kef:eqProfile`, `kef:eqProfile/v2`, `settings:/kef/dsp/{bassExtension,trebleAmount,balance,deskMode,wallMode,phaseCorrection,highPassMode,subwooferGain,...}`, `kef:restoreDspSettings(/v2)` | Confirmed |
| Device info | `settings:/deviceName`, `settings:/kef/host/{modelName,serialNumber,kefId}`, `settings:/releasetext`, `settings:/version`, `settings:/system/primaryMacAddress` | Confirmed |
| Other | firmware `firmwareupdate:*`, network `network:*`, grouping `grouping:members`, alarms/timers `alerts:*`, LEDs `settings:/kef/host/{frontLED,topPanelLED,...}` | Confirmed (out of scope for panel) |

Model-specific note (inferred): LSX II LT hardware has Wi-Fi, Bluetooth, TV (HDMI eARC), optical, USB-C;
no coaxial/analog inputs. Panel should offer **Wi-Fi, Bluetooth, TV, Optical, USB** and hide the rest.
Confirm by reading `physicalSource` while cycling the remote.

## Streaming services

| Service | Evidence | Status |
|---|---|---|
| AirPlay 2 | `settings:/airplay/{deviceName,password,addedToHome}`, `AirplayQuality` | Confirmed (handled on speaker; app only configures) |
| Chromecast | `settings:/googlecast/tosAccepted`, `googlecast:usageReport`, `googleCastLite` | Confirmed |
| Spotify Connect | `ui:/spotify`, `spotifySupported` | Confirmed |
| TIDAL / Qobuz / Deezer / Amazon / radio / podcasts | `ui:/airabletidal`, `ui:/airableqobuz`, `ui:/airabledeezer`, `ui:/airableamazon`, `ui:/airableradios`, `ui:/airablepodcasts` (via Airable) | Confirmed; TIDAL **Connect** specifically not found — TIDAL via Airable browse |
| Roon Ready, Alexa, UPnP, Huawei HiMusic | `roon`, `alexa`, `ui:/upnp`, `settings:/huaweiHiMusic/enabled` | Confirmed strings |
| Apple Music | only App Store links (`itunes.apple.com/app/...`); playback is via AirPlay | No native integration found |

## Cloud hosts found (not contacted)

- `https://8448239770.airable.io` (Airable music/radio/podcast catalog; `/airable/feeds/favorites`, `/airable/radios/favorites`, `/airable/feed/<id>/episodes`)
- `itunes.apple.com/app/id292738169, id324684580, id691797987, id913943275, id944011620` (App Store deep links)
- Apple PKI (`ocsp.apple.com`, `crl.apple.com`) — code signing only.
- No KEF account/cloud API host is present in these frameworks; it is likely in the encrypted main binary.
  `settings:/kef/host/disableAnalytics` / `disableAppAnalytics` exist.

## Panel-state feasibility

| State | Feasible? | How |
|---|---|---|
| Playing / paused | Yes | `player:player/data.state` + `player:player/control` |
| Now playing + artwork | Yes (Wi-Fi/streaming sources) | `trackRoles.title`, `trackRoles.icon`, `mediaData.metaData.artist/album`; physical inputs show no metadata |
| Offline detection | Yes | HTTP timeout/refused + pollQueue failures; `speakerStatus` = `standby` distinguishes "asleep" from "unreachable" |
| Source switching | Yes | `physicalSource`; values above |
| Volume | Yes | `player:volume`, respect `maximumVolume` |
| Mute | Yes | `settings:/mediaPlayer/mute` |
| Live updates | Yes | subscribe via `modifyQueue`, long-poll `pollQueue` |
| Auth on new firmware | **Risk** | HTTPS:4430 + Basic auth; credential bootstrap unknown |

## Open items
1. Live test on our LSX II LT: firmware version, whether `:80` still works, whether `:4430` requires auth.
2. Ghidra pass on `ApiLib` `ApiSpeakerCredentials` / `checkSpeakerMasterKey` to pin down the auth handshake.
