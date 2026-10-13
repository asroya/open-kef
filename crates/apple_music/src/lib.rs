//! Apple Music integration — research stub only. See docs/apple-music.md.
//!
//! Plan: on macOS, auth + catalog/library browsing live in the SwiftUI shell via
//! MusicKit (automatic developer-token generation, user authorization prompt).
//! The Rust side only models what the shell hands across FFI. Off-Apple paths
//! (Apple Music API with an ES256 developer token + Music User Token) would need
//! an Apple Developer Program membership and a MusicKit key; nothing is wired yet.

/// Where an Apple Music token came from.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuthSource {
    /// MusicKit for Swift handled tokens; Rust never sees them.
    MusicKitNative,
    /// Explicit tokens for Apple Music API (REST). Music User Token expires (~6 months, per Apple forum reply).
    RestTokens { developer_token: String, music_user_token: String },
}

/// Output route for Apple Music audio to KEF speakers. Only AirPlay is a known
/// path today; KEF exposes no Apple Music "connect"-style service.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Route { AirPlay }

pub const API_BASE: &str = "https://api.music.apple.com/v1";
