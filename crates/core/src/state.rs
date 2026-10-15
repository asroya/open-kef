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
    /// Which transport controls the current source allows (`controls` in player data).
    pub controls: Controls,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
pub struct Controls { pub next: bool, pub previous: bool, pub pause: bool }

impl NowPlaying {
    /// Parses `getData(player:player/data)`. Layout live-confirmed in MET-6: {state, trackRoles{title, icon, mediaData{metaData}}, mediaRoles, controls}.
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
            controls: {
                let c = d.get("controls");
                let b = |k: &str| c.and_then(|c| c.get(k)).and_then(Value::as_bool).unwrap_or(false);
                // The speaker sends `next_` (MET-11 live); accept `next` too.
                Controls { next: b("next_") || b("next"), previous: b("previous"), pause: b("pause") }
            },
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

impl SpeakerState {
    /// Applies one pollQueue item (`{path, itemType, itemValue}`) in place.
    /// Returns false for paths it doesn't model, so the caller can refetch.
    pub fn apply_event(&mut self, item: &Value) -> bool {
        use crate::protocol::path;
        let (Some(p), Some(v)) = (item.get("path").and_then(Value::as_str), item.get("itemValue")) else { return false };
        match p {
            path::VOLUME => match v.get("i32_").and_then(Value::as_i64) {
                Some(n) => { self.volume = n.clamp(0, 100) as u8; true } None => false },
            path::MUTE => match v.get("bool_").and_then(Value::as_bool) {
                Some(b) => { self.muted = b; true } None => false },
            path::PHYSICAL_SOURCE => match v.get("kefPhysicalSource").and_then(Value::as_str) {
                Some(s) => { self.source = s.to_owned(); true } None => false },
            path::SPEAKER_STATUS => match v.get("kefSpeakerStatus").and_then(Value::as_str) {
                Some(s) => { self.status = s.to_owned(); true } None => false },
            path::PLAYER_DATA => { self.now_playing = NowPlaying::from_player_data(v); true }
            _ => false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn parses_player_data() {
        let v = json!([{"state":"playing","trackRoles":{"title":"Teardrop","icon":"http://x/a.jpg",
            "mediaData":{"metaData":{"artist":"Massive Attack","album":"Mezzanine"}}},
            "mediaRoles":{},"controls":{"next_":true,"previous":false,"pause":true}}]);
        let n = NowPlaying::from_player_data(&v);
        assert_eq!(n, NowPlaying{state:"playing".into(),title:"Teardrop".into(),artist:"Massive Attack".into(),
            album:"Mezzanine".into(),artwork_url:"http://x/a.jpg".into(),
            controls:Controls{next:true,previous:false,pause:true}});
    }
    #[test]
    fn accepts_next_without_underscore() {
        let n = NowPlaying::from_player_data(&json!({"controls":{"next":true}}));
        assert!(n.controls.next);
    }
    /// Recorded live (MET-11): one poll after switching tv -> wifi. Volume comes from the
    /// event (per-source volume 49 -> 35), not carried over from the old source.
    #[test]
    fn source_switch_takes_volume_from_events() {
        let poll = json!([
          {"path":"settings:/kef/play/physicalSource","rowsEvents":[],"itemType":"update","itemValue":{"kefPhysicalSource":"wifi","type":"kefPhysicalSource"}},
          {"path":"player:player/data","rowsEvents":[],"itemType":"update","itemValue":{"playId":{"timestamp":5244109873u64,"systemMemberId":"lsxlite-x"},"streamerError":{},"state":"stopped","error":"","trackRoles":{},"mediaRoles":{},"keepActive":false}},
          {"path":"player:volume","rowsEvents":[],"itemType":"update","itemValue":{"type":"i32_","i32_":35}}
        ]);
        let mut s = SpeakerState { volume: 49, source: "tv".into(),
            now_playing: NowPlaying { state: "playing".into(), title: "TV".into(), ..Default::default() }, ..Default::default() };
        for e in poll.as_array().unwrap() { assert!(s.apply_event(e)); }
        assert_eq!((s.volume, s.source.as_str(), s.now_playing.state.as_str(), s.now_playing.title.as_str()), (35, "wifi", "stopped", ""));
        assert!(!s.apply_event(&json!({"path":"notifications:/player/playing","itemValue":{}})));
    }
    #[test]
    fn empty_player_data_is_default() {
        assert_eq!(NowPlaying::from_player_data(&json!([])), NowPlaying::default());
    }
}
