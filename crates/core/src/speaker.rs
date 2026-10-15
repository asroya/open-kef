use crate::{protocol::{self, path}, Error, Result};
use serde_json::{json, Value};
use crate::transport::{Endpoint, Transport};
use std::time::Duration;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Source { Standby, Wifi, Bluetooth, Tv, Optic, Coaxial, Analog, Usb }

impl Source {
    pub fn as_str(self) -> &'static str {
        match self {
            Source::Standby => "standby", Source::Wifi => "wifi", Source::Bluetooth => "bluetooth",
            Source::Tv => "tv", Source::Optic => "optical", Source::Coaxial => "coaxial",
            Source::Analog => "analog", Source::Usb => "usb",
        }
    }
    /// Inputs on the LSX II LT, in panel order (MET-6: no coaxial/analog).
    pub const LSX_II_LT: [Source; 5] = [Source::Wifi, Source::Bluetooth, Source::Tv, Source::Optic, Source::Usb];

    pub fn parse(s: &str) -> Option<Self> {
        Some(match s {
            "standby" => Self::Standby, "wifi" => Self::Wifi, "bluetooth" => Self::Bluetooth,
            "tv" => Self::Tv, "optical" | "optic" => Self::Optic, "coaxial" => Self::Coaxial,
            "analog" => Self::Analog, "usb" => Self::Usb, _ => return None,
        })
    }
}

/// One W2-platform speaker. Blocking, short timeouts. Retries/backoff live in `events`.
pub struct Speaker {
    transport: Transport,
}

impl Speaker {
    /// Default: plain HTTP on port 80, no auth (MET-6 live-confirmed on LSXIILT_V2186).
    pub fn new(host: &str) -> Self {
        Self { transport: Transport::new(Endpoint::http(host)) }
    }

    /// Custom endpoint. HTTPS:4430 answers unauthenticated (MET-6) but isn't implemented; HTTP is enough.
    pub fn with_endpoint(ep: Endpoint) -> Self { Self { transport: Transport::new(ep) } }

    pub fn endpoint(&self) -> &Endpoint { &self.transport.endpoint }

    pub fn get(&self, p: &str) -> Result<Value> {
        self.transport.get_json(protocol::GET_DATA, &[("path", p), ("roles", "value")], None)
    }

    pub fn set(&self, body: Value) -> Result<Value> {
        self.transport.post_json(protocol::SET_DATA, body)
    }

    pub fn mute(&self) -> Result<bool> {
        let v = self.get(path::MUTE)?;
        v.get(0).and_then(|x| x.get("bool_")).and_then(Value::as_bool)
            .ok_or_else(|| Error::Decode(format!("unexpected: {v}")))
    }

    pub fn set_mute(&self, on: bool) -> Result<Value> {
        self.set(json!({"path": path::MUTE, "roles": "value",
                        "value": {"type": "bool_", "bool_": on}}))
    }

    /// `settings:/kef/host/speakerStatus` -> "powerOn" / "standby" / ...
    pub fn speaker_status(&self) -> Result<String> {
        let v = self.get(path::SPEAKER_STATUS)?;
        v.get(0).and_then(|x| x.get("kefSpeakerStatus")).and_then(Value::as_str)
            .map(str::to_owned).ok_or_else(|| Error::Decode(format!("unexpected: {v}")))
    }

    pub fn string_setting(&self, p: &str) -> Result<String> {
        let v = self.get(p)?;
        v.get(0).and_then(|x| x.get("string_")).and_then(Value::as_str)
            .map(str::to_owned).ok_or_else(|| Error::Decode(format!("unexpected: {v}")))
    }

    pub fn now_playing(&self) -> Result<crate::state::NowPlaying> {
        let v = self.get(path::PLAYER_DATA)?;
        Ok(crate::state::NowPlaying::from_player_data(&v))
    }

    /// Full snapshot for the panel. Device name/model failures are tolerated (empty strings).
    pub fn state(&self) -> Result<crate::state::SpeakerState> {
        let volume = self.volume()?;
        let source = self.source()?;
        let status = self.speaker_status().unwrap_or_else(|_| "powerOn".into());
        let muted = self.mute().unwrap_or(false);
        let now = self.now_playing().unwrap_or_default();
        Ok(crate::state::SpeakerState {
            volume: volume.clamp(0, 100) as u8, muted, source, status, now_playing: now,
            device_name: self.string_setting(path::DEVICE_NAME).unwrap_or_default(),
            model_name: self.string_setting(path::MODEL_NAME).unwrap_or_default(),
        })
    }

    /// Subscribe to the event queue. Returns the queue id.
    pub fn subscribe(&self) -> Result<String> {
        let paths = [path::VOLUME, path::MUTE, path::PHYSICAL_SOURCE, path::SPEAKER_STATUS,
                     path::PLAYER_DATA, "notifications:/player/playing"];
        let sub: Vec<Value> = paths.iter().map(|p| json!({"path": p, "type": "itemWithValue"})).collect();
        let v = self.transport.post_json(protocol::MODIFY_QUEUE, json!({"subscribe": sub, "unsubscribe": []}))?;
        v.as_str().map(str::to_owned).ok_or_else(|| Error::Decode(format!("queue id: {v}")))
    }

    /// Long-poll the queue. Returns the changed paths (empty on timeout).
    pub fn poll(&self, queue: &str, timeout_s: u64) -> Result<Vec<String>> {
        let t = timeout_s.to_string();
        let v = self.transport.get_json(protocol::POLL_QUEUE, &[("queueId", queue), ("timeout", &t)],
                                        Some(Duration::from_secs(timeout_s + 5)))?;
        Ok(v.as_array().map(|a| a.iter().filter_map(|e| e.get("path").and_then(Value::as_str))
            .map(str::to_owned).collect()).unwrap_or_default())
    }

    /// Toggle based on current player state (`play` is confirmed in KEF Connect 1.31 strings).
    /// Sends an explicit play or pause. Callers decide the target, so a stale read can't invert it.
    pub fn set_playing(&self, play: bool) -> Result<Value> {
        self.control(if play { "play" } else { "pause" })
    }

    pub fn volume(&self) -> Result<i64> {
        let v = self.get(path::VOLUME)?;
        v.get(0).and_then(|x| x.get("i32_")).and_then(Value::as_i64)
            .ok_or_else(|| Error::Decode(format!("unexpected: {v}")))
    }

    pub fn set_volume(&self, vol: u8) -> Result<Value> {
        self.set(json!({"path": path::VOLUME, "roles": "value",
                        "value": {"type": "i32_", "i32_": vol.min(100)}}))
    }

    pub fn source(&self) -> Result<String> {
        let v = self.get(path::PHYSICAL_SOURCE)?;
        v.get(0).and_then(|x| x.get("kefPhysicalSource")).and_then(Value::as_str)
            .map(str::to_owned).ok_or_else(|| Error::Decode(format!("unexpected: {v}")))
    }

    pub fn set_source(&self, s: Source) -> Result<Value> {
        self.set(json!({"path": path::PHYSICAL_SOURCE, "roles": "value",
                        "value": {"type": "kefPhysicalSource", "kefPhysicalSource": s.as_str()}}))
    }

    /// `cmd`: "play", "pause", "stop", "next", "previous" (MET-6).
    pub fn control(&self, cmd: &str) -> Result<Value> {
        self.set(json!({"path": path::PLAYER_CONTROL, "roles": "activate",
                        "value": {"control": cmd}}))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn source_roundtrip() {
        for s in ["standby","wifi","bluetooth","tv","optical","coaxial","analog","usb"] {
            assert_eq!(Source::parse(s).unwrap().as_str(), s);
        }
    }
}

#[cfg(test)]
mod met6_tests {
    use super::Source;
    #[test]
    fn optical_wire_name_matches_kef_connect() {
        assert_eq!(Source::Optic.as_str(), "optical");
        assert_eq!(Source::parse("optical"), Some(Source::Optic));
        assert_eq!(Source::parse("optic"), Some(Source::Optic));
    }
}
