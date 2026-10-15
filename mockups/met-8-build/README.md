# MET-8 build screenshots

Rendered by the app itself, not hand-made: `apps/macos/.build/.../OpenKef --snapshot mockups/met-8-build`
(SwiftUI `ImageRenderer`, 2x, mock fixtures from `Mock.swift`). Compare 1:1 with `mockups/met-7/shots/c-the-ruler--*.png`.

Snapshot-only differences: the panel is drawn on `color.bg` with a 1pt `color.line` edge (the live app uses the
system menu material), and Loading shows the mockup's static ring because `ImageRenderer` can't draw `ProgressView`.

`tv-playing` uses the live MET-6 TV payload: title "TV", no metadata, `controls` next/previous/pause all false, so the
pause button renders disabled (`opacity.disabled`). The panel has no next/previous buttons, so only pause is affected.
