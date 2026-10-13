# open-kef

Open-source, lightweight replacement for KEF Connect on macOS. Rust core for speaker connectivity and control. Apple Music integration. Premium native Mac UI.

Status: scaffold only. No reverse engineering has been done yet; the protocol code is based on public community libraries (see `docs/kef-protocol.md`).

## Architecture

```
┌──────────────────────────────┐
│ Mac UI shell (planned)       │  SwiftUI (preferred) — MusicKit auth/browse, AirPlay route picker
│                              │  alt: pure-Rust UI (iced / egui) — no MusicKit access
└──────────────┬───────────────┘
               │ C ABI / FFI (planned: uniffi or cbindgen)
┌──────────────▼───────────────┐
│ crates/core   openkef-core   │  discovery (mDNS _kef-info._tcp, TODO), HTTP/JSON
│                              │  getData/setData, event queue (TODO), reconnect logic
├──────────────────────────────┤
│ crates/apple_music           │  types + notes only; real auth lives in Swift MusicKit
├──────────────────────────────┤
│ crates/cli   `openkef`       │  thin test CLI for real speakers
└──────────────────────────────┘
```

### Why SwiftUI shell + Rust core
- MusicKit (official Apple Music auth/catalog) is a Swift framework; a pure-Rust UI can't call it directly.
- AirPlay routing (`AVRoutePickerView`) and native Mac look (materials, SF Symbols, menu bar extra) are free in SwiftUI.
- Rust keeps the speaker protocol, state, and reliability logic small, testable, and portable.

Pure Rust (iced/egui) is possible for speaker control only, but Apple Music would then need the REST Apple Music API + a hand-rolled auth flow, and no in-app playback.

## Build
```
cargo build --release
./target/release/openkef 192.168.1.50 info
./target/release/openkef 192.168.1.50 volume 30
./target/release/openkef 192.168.1.50 source wifi
```
Find speakers on macOS: `dns-sd -B _kef-info._tcp`

## Docs
- `docs/kef-protocol.md`: known local HTTP API, gaps for RE
- `docs/apple-music.md`: MusicKit / Apple Music API, lossless and AirPlay constraints
- `docs/design-refs.md`: UI references
- `docs/app-store-notes.md`: KEF Connect listing snapshot
