# Design references

Goal: premium, light, native-feeling Mac app for music + speaker control.

## Free references
- **Apple Human Interface Guidelines (macOS)**: https://developer.apple.com/design/human-interface-guidelines/ (sidebars, toolbars, materials, Liquid Glass in macOS 26)
- **Apple Design Resources** (Sketch/Figma macOS UI kits): https://developer.apple.com/design/resources/
- **SF Symbols** app (free; speaker, airplayaudio, hifispeaker, waveform glyphs): https://developer.apple.com/sf-symbols/
- **Apple Music for Mac**: now playing bar, artwork-led layouts, sidebar navigation
- **System Settings / Control Center**: dense, quiet controls; sliders and toggles for volume, source, EQ
- **Menu bar extras** (Control Center sound module, AirBuddy-style): quick volume + source switching without opening a window
- Third-party Mac music apps worth studying: Doppler, Sonos for Mac (control density), Roon (multi-zone)
- Free galleries: https://www.macosicongallery.com/ (icons), Dribbble/Behance (search "macOS music player")

## Paid curated refs
- **Refero** (https://refero.design/) — curated real-product screens and flows; an MCP connector is available in this workspace (`user-Refero`) to pull refs during the design pass.
- **Mobbin** (https://mobbin.com/) — mostly mobile/web flows, limited macOS.

## Direction (proposal)
- Main window: sidebar (Speakers, Sources, Apple Music, Settings) + content + persistent now-playing bar.
- Menu bar extra for instant volume/source/standby control; the app should be useful without the main window.
- System materials, SF Symbols, system accent color; no custom chrome.
- Show connection state honestly (reachable / reconnecting / standby).

## UI tech recommendation
| Option | Pros | Cons |
|---|---|---|
| **SwiftUI shell + Rust core (FFI)** — recommended | Native look, MusicKit, AirPlay picker, menu bar extra, small binary | Two languages; FFI boundary (uniffi/cbindgen) |
| Pure Rust (iced / egui) | One language, cross-platform | Not native-looking, no MusicKit, AirPlay picker needs ObjC bindings |
