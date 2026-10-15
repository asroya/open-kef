//! Panel-facing state, serialisable across the FFI as JSON.
use serde::Serialize;
use serde_json::Value;

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
pub struct NowPlaying {
    /// "playing" / "paused" / "stopped" / "" (unknown)
    pub state: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub artwork_url: String,
}

impl NowPlaying {
    /// Parses `getData(player:player/data)`. Nesting per community docs (MET-6: keys confirmed, nesting inferred).
    pub fn from_player_data(v: &Value) -> Self {
        let d = v.get(0).unwrap_or(v);
        let s = |x: Option<&Value>| x.and_then(Value::as_str).unwrap_or("").to_owned();
        let tr = d.get("trackRoles");
        let md = tr.and_then(|t| t.get("mediaData")).and_then(|m| m.get("metaData"));
        Self {
            state: s(d.get("state")),
            title: s(tr.and_then(|t| t.get("title"))),
            artist: s(md.and_then(|m| m.get("artist"))),
            album: s(md.and_then(|m| m.get("album"))),
            artwork_url: s(tr.and_then(|t| t.get("icon"))),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
pub struct SpeakerState {
    pub volume: u8,
    pub muted: bool,
    pub source: String,
    /// `kefSpeakerStatus`: "powerOn" / "standby" / "networkSetup" / "firmwareUpgrade"
    pub status: String,
    pub now_playing: NowPlaying,
    pub device_name: String,
    pub model_name: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn parses_player_data() {
        let v = json!([{"state":"playing","trackRoles":{"title":"Teardrop","icon":"http://x/a.jpg",
            "mediaData":{"metaData":{"artist":"Massive Attack","album":"Mezzanine"}}}}]);
        let n = NowPlaying::from_player_data(&v);
        assert_eq!(n, NowPlaying{state:"playing".into(),title:"Teardrop".into(),artist:"Massive Attack".into(),
            album:"Mezzanine".into(),artwork_url:"http://x/a.jpg".into()});
    }
    #[test]
    fn empty_player_data_is_default() {
        assert_eq!(NowPlaying::from_player_data(&json!([])), NowPlaying::default());
    }
}
