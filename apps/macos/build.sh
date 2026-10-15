#!/bin/sh
# Headless build: Rust staticlib (aarch64-apple-darwin) + SwiftPM menu-bar app. No signing.
set -eu
cd "$(dirname "$0")"
ROOT=$(cd ../.. && pwd)
python3 scripts/gen_tokens.py
(cd "$ROOT" && cargo build --release -p openkef-ffi --target aarch64-apple-darwin)
LIB="$ROOT/target/aarch64-apple-darwin/release"
swift build -c "${CONFIG:-release}" -Xlinker -L"$LIB"
echo "built: $(swift build -c "${CONFIG:-release}" --show-bin-path)/OpenKef"
