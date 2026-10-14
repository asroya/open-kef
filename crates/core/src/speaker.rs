use crate::{protocol::{self, path}, Error, Result};
use serde_json::{json, Value};
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
    pub fn parse(s: &str) -> Option<Self> {
        Some(match s {
            "standby" => Self::Standby, "wifi" => Self::Wifi, "bluetooth" => Self::Bluetooth,
            "tv" => Self::Tv, "optical" | "optic" => Self::Optic, "coaxial" => Self::Coaxial,
            "analog" => Self::Analog, "usb" => Self::Usb, _ => return None,
        })
    }
}

/// One W2-platform speaker reachable over HTTP. Blocking, short timeouts, no retries yet.
pub struct Speaker {
    base: String,
    agent: ureq::Agent,
}

impl Speaker {
    pub fn new(host: &str) -> Self {
        let agent = ureq::AgentBuilder::new()
            .timeout_connect(Duration::from_secs(2))
            .timeout(Duration::from_secs(5))
            .build();
        Self { base: format!("http://{host}:{}", protocol::PORT), agent }
    }

    pub fn get(&self, p: &str) -> Result<Value> {
        self.agent.get(&format!("{}{}", self.base, protocol::GET_DATA))
            .query("path", p).query("roles", "value")
            .call().map_err(|e| Error::Http(e.to_string()))?
            .into_json().map_err(|e| Error::Decode(e.to_string()))
    }

    pub fn set(&self, body: Value) -> Result<Value> {
        self.agent.post(&format!("{}{}", self.base, protocol::SET_DATA))
            .send_json(body).map_err(|e| Error::Http(e.to_string()))?
            .into_json().map_err(|e| Error::Decode(e.to_string()))
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

    /// `cmd` is one of "pause" (toggle), "next", "previous" per community libs.
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
