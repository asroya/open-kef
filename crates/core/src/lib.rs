//! open-kef core: speaker connectivity + protocol.
//!
//! Protocol notes (W2 platform: LS50 Wireless II, LSX II, LS60) come from public
//! community sources — see docs/kef-protocol.md. Nothing here is from RE yet.
//! Plain HTTP on port 80, JSON payloads, no auth.

pub mod protocol;
pub mod speaker;
pub mod state;
pub mod transport;
pub mod events;

pub use speaker::{Speaker, Source};
pub use state::{NowPlaying, SpeakerState};
pub use transport::{Auth, Endpoint, Scheme};

#[derive(Debug)]
pub enum Error {
    Http(String),
    Decode(String),
    /// Transport not built yet (HTTPS:4430 + auth, pending MET-6 live test).
    Unsupported(String),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::Http(e) => write!(f, "http: {e}"),
            Error::Decode(e) => write!(f, "decode: {e}"),
            Error::Unsupported(e) => write!(f, "unsupported: {e}"),
        }
    }
}
impl std::error::Error for Error {}
pub type Result<T> = std::result::Result<T, Error>;
