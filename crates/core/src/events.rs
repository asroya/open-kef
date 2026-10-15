//! Event loop: modifyQueue subscribe + pollQueue long-poll, refetching full state on change,
//! with reconnect + exponential backoff and offline detection.
use crate::{SpeakerState, Speaker};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

#[derive(Debug, Clone, PartialEq)]
pub enum Event { State(SpeakerState), Offline(String) }

pub const POLL_TIMEOUT_S: u64 = 10;

/// Backoff for attempt n (0-based): 1, 2, 4, 8, 16, 30, 30... seconds.
pub fn backoff(n: u32) -> Duration { Duration::from_secs((1u64 << n.min(5)).min(30)) }

/// Sleep in small slices so `stop` is honoured promptly.
fn nap(d: Duration, stop: &AtomicBool) {
    let mut left = d;
    while !stop.load(Ordering::Relaxed) && !left.is_zero() {
        let s = left.min(Duration::from_millis(100));
        std::thread::sleep(s);
        left -= s;
    }
}

/// Runs until `stop` is set. Emits State on (re)connect and after every change; Offline once per outage.
pub fn run(sp: Arc<Speaker>, stop: Arc<AtomicBool>, mut emit: impl FnMut(Event)) {
    let mut fails = 0u32;
    let mut offline = false;
    while !stop.load(Ordering::Relaxed) {
        let q = match sp.subscribe().and_then(|q| sp.state().map(|s| (q, s))) {
            Ok((q, s)) => { fails = 0; offline = false; emit(Event::State(s)); q }
            Err(e) => {
                if !offline { emit(Event::Offline(e.to_string())); offline = true; }
                nap(backoff(fails), &stop); fails += 1; continue;
            }
        };
        while !stop.load(Ordering::Relaxed) {
            match sp.poll(&q, POLL_TIMEOUT_S) {
                Ok(ev) if ev.is_empty() => {}
                Ok(_) => match sp.state() {
                    Ok(s) => emit(Event::State(s)),
                    Err(_) => break,
                },
                // Lost subscription or unreachable: resubscribe (offline is emitted if that fails).
                Err(_) => break,
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn backoff_caps_at_30s() {
        assert_eq!(backoff(0), Duration::from_secs(1));
        assert_eq!(backoff(3), Duration::from_secs(8));
        assert_eq!(backoff(9), Duration::from_secs(30));
    }
    #[test]
    fn unreachable_speaker_emits_offline_once_then_stops() {
        // TEST-NET-1 address: guaranteed unroutable.
        let sp = Arc::new(Speaker::new("192.0.2.1"));
        let stop = Arc::new(AtomicBool::new(false));
        let s2 = stop.clone();
        let mut got = vec![];
        run(sp, stop, |e| { got.push(e); s2.store(true, Ordering::Relaxed); });
        assert!(matches!(got.as_slice(), [Event::Offline(_)]));
    }
}
