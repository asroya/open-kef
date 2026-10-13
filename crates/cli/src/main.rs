//! Thin test CLI. Usage:
//!   openkef <host> info
//!   openkef <host> volume [0-100]
//!   openkef <host> source [wifi|bluetooth|tv|optic|coaxial|analog|usb|standby]
//!   openkef <host> pause|next|previous
//!   openkef <host> get <path>
//! Discovery (mDNS _kef-info._tcp) is TODO; on macOS use: dns-sd -B _kef-info._tcp
use openkef_core::{protocol::path, Source, Speaker};

fn main() {
    let a: Vec<String> = std::env::args().skip(1).collect();
    if a.len() < 2 { eprintln!("usage: openkef <host> <info|volume|source|pause|next|previous|get> [arg]"); std::process::exit(2); }
    let sp = Speaker::new(&a[0]);
    let arg = a.get(2).map(String::as_str);
    let r = match (a[1].as_str(), arg) {
        ("info", _) => [path::DEVICE_NAME, path::MODEL_NAME, path::FIRMWARE, path::SPEAKER_STATUS, path::PHYSICAL_SOURCE, path::VOLUME]
            .iter().try_for_each(|p| sp.get(p).map(|v| println!("{p}: {v}"))),
        ("volume", None) => sp.volume().map(|v| println!("{v}")),
        ("volume", Some(v)) => v.parse::<u8>().map_err(|e| openkef_core::Error::Decode(e.to_string()))
            .and_then(|v| sp.set_volume(v)).map(|_| ()),
        ("source", None) => sp.source().map(|s| println!("{s}")),
        ("source", Some(s)) => match Source::parse(s) { Some(s) => sp.set_source(s).map(|_| ()), None => { eprintln!("bad source"); std::process::exit(2) } },
        (c @ ("pause" | "next" | "previous"), _) => sp.control(c).map(|_| ()),
        ("get", Some(p)) => sp.get(p).map(|v| println!("{v}")),
        _ => { eprintln!("unknown command"); std::process::exit(2) }
    };
    if let Err(e) = r { eprintln!("error: {e}"); std::process::exit(1); }
}
