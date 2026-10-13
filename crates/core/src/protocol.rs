//! Known W2 HTTP API paths (community-documented; unverified against our own hardware).

pub const PORT: u16 = 80;
/// mDNS service type used by kefctl for discovery.
pub const MDNS_SERVICE: &str = "_kef-info._tcp.local.";

pub const GET_DATA: &str = "/api/getData";
pub const SET_DATA: &str = "/api/setData";
pub const MODIFY_QUEUE: &str = "/api/event/modifyQueue";
pub const POLL_QUEUE: &str = "/api/event/pollQueue";

pub mod path {
    pub const VOLUME: &str = "player:volume";
    pub const MUTE: &str = "settings:/mediaPlayer/mute";
    pub const PHYSICAL_SOURCE: &str = "settings:/kef/play/physicalSource";
    pub const SPEAKER_STATUS: &str = "settings:/kef/host/speakerStatus";
    pub const DEVICE_NAME: &str = "settings:/deviceName";
    pub const MODEL_NAME: &str = "settings:/kef/host/modelName";
    pub const FIRMWARE: &str = "settings:/releasetext";
    pub const MAC_ADDRESS: &str = "settings:/system/primaryMacAddress";
    pub const PLAYER_DATA: &str = "player:player/data";
    pub const PLAYER_CONTROL: &str = "player:player/control";
    pub const PLAY_TIME: &str = "player:player/data/playTime";
}
