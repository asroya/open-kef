# MET-11 build: Now Playing window

Rendered by the app: `OpenKef --snapshot-window mockups/met-11-build` (ImageRenderer, 2x, fixtures in `Mock.swift`).
Compare with `mockups/met-11/shots/` (rev 2). States: `playing` (= mockup "airplay"), `mac`, `idle`, `offline`, light and dark.

Snapshot-only: the title bar is a stand-in (the live window uses the native NSWindow title bar with the
status in the toolbar), and the AirPlay button shows without the transparent AVRoutePickerView on top.
Idle has no subline (design snob bro's cut).
