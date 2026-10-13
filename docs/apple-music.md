# Apple Music in open-kef

## Official integration options
1. **MusicKit for Swift** (Apple platforms incl. macOS). Apple recommends it on Apple platforms with *automatic developer-token generation*: enable the MusicKit App Service for the App ID; the user approves access via `MusicAuthorization.request()`. Gives catalog search, library access, subscription checks.
   - https://developer.apple.com/musickit/
   - https://developer.apple.com/documentation/applemusicapi/generating-developer-tokens
   - WWDC26 "Integrate MusicKit into your app": https://developer.apple.com/videos/play/wwdc2026/254/
2. **Apple Music API (REST)**, `https://api.music.apple.com/v1`. Every request needs `Authorization: Bearer <developer token>` — a JWT signed **ES256** with a MusicKit private key from an Apple Developer Program account. User-specific endpoints also need a **Music User Token** (`Music-User-Token` header), obtained via MusicKit (Swift/JS/Android) user auth. Rate limits return 429.
   - Music User Token expires (~6 months per an Apple engineer reply, cited at https://stackoverflow.com/questions/62916634/do-apple-music-user-tokens-expire); no refresh endpoint.
3. MusicKit JS (web) / MusicKit for Android exist but are not the natural fit for a Mac app.

## Playback on macOS: key constraint
- `ApplicationMusicPlayer` / `SystemMusicPlayer` were **not available on native macOS** per Apple's MusicKit engineer (forum thread https://developer.apple.com/forums/thread/698902; availability was only for Mac Catalyst, with reported issues). **Must re-verify against current macOS 26/27 SDK docs** before committing; we have not confirmed whether this changed.
- Fallbacks if no native player: (a) Mac Catalyst target, (b) control the Music.app via AppleScript/ScriptingBridge (play, pause, AirPlay device selection is scriptable in Music.app), (c) MusicKit JS in a WKWebView. Each has trade-offs; to be tested.
- The REST API does **not** stream audio; it returns metadata and previews only.

## Getting audio to KEF speakers
- KEF does not list Apple Music as an in-app service (see `app-store-notes.md`). The route is **AirPlay** (W2 speakers are AirPlay 2 receivers) — audio flows Mac → speaker; the speaker does not fetch from Apple's servers.
- **Lossless caveat:** Apple Music's lossless/Hi-Res applies to wired/built-in output per Apple (https://support.apple.com/en-us/118295). Testing by Darko.Audio found Apple Music sent to *AirPlay 2* receivers is re-encoded to 256 kbps AAC, and AirPlay can't carry >48 kHz (https://darko.audio/2024/07/wiims-pro-plus-confirms-that-apple-airplay-2-isnt-always-lossless/, https://darko.audio/2025/10/apple-musics-hi-res-audio-is-still-standing-in-its-own-light/). Users have reported possible changes with iOS 26 (https://www.avsforum.com/threads/lossless-over-airplay-2.3333367/), but we found no Apple documentation confirming lossless AirPlay to third-party receivers. **Abhi's premise "Apple now supports lossless AirPlay" is unverified — need his source.**
- open-kef can't change the codec Apple uses for AirPlay; it can at best pick the route and show what the speaker reports (`player:player/data`).

## What KEF Connect supports today (App Store listing, v1.31.0)
Spotify, TIDAL (Hi-Res FLAC since 1.20), Amazon Music, Qobuz, Deezer, HighResAudio, Internet Radio, Podcasts; plus AirPlay, Google Cast, Bluetooth; Auracast on Muo/Coda W. No Apple Music. Source: https://apps.apple.com/ca/app/kef-connect/id1512439427

## Requirements for us
- Apple Developer Program membership (paid) for MusicKit App Service / keys; signed app with bundle ID.
- Abhi's Apple Music subscription; auth happens on his Mac (not on the box).
