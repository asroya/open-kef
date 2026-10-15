//! C ABI for the macOS app. See include/openkef.h.
#![allow(clippy::missing_safety_doc)]
use openkef_core::{events, Source, Speaker};
use serde_json::json;
use std::ffi::{c_char, c_void, CStr, CString};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::JoinHandle;

pub struct OkefSpeaker {
    sp: Arc<Speaker>,
    events: Option<(Arc<AtomicBool>, JoinHandle<()>)>,
}

pub type EventCb = extern "C" fn(*mut c_void, *const c_char);
struct Ctx(*mut c_void);
unsafe impl Send for Ctx {}

unsafe fn s<'a>(p: *const c_char) -> Option<&'a str> {
    if p.is_null() { None } else { CStr::from_ptr(p).to_str().ok() }
}
fn rc<T>(r: openkef_core::Result<T>) -> i32 { if r.is_ok() { 0 } else { -1 } }

#[no_mangle]
pub unsafe extern "C" fn okef_connect(host: *const c_char) -> *mut OkefSpeaker {
    match s(host) {
        Some(h) if !h.is_empty() => Box::into_raw(Box::new(OkefSpeaker { sp: Arc::new(Speaker::new(h)), events: None })),
        _ => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn okef_free(sp: *mut OkefSpeaker) {
    if sp.is_null() { return; }
    okef_events_stop(sp);
    drop(Box::from_raw(sp));
}

#[no_mangle]
pub unsafe extern "C" fn okef_get_state(sp: *mut OkefSpeaker) -> *mut c_char {
    let Some(h) = sp.as_ref() else { return std::ptr::null_mut() };
    match h.sp.state() {
        Ok(st) => CString::new(serde_json::to_string(&st).unwrap_or_default()).map(CString::into_raw).unwrap_or(std::ptr::null_mut()),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn okef_string_free(p: *mut c_char) { if !p.is_null() { drop(CString::from_raw(p)); } }

#[no_mangle]
pub unsafe extern "C" fn okef_set_volume(sp: *mut OkefSpeaker, v: u8) -> i32 {
    sp.as_ref().map_or(-2, |h| rc(h.sp.set_volume(v.min(100))))
}
#[no_mangle]
pub unsafe extern "C" fn okef_set_mute(sp: *mut OkefSpeaker, m: bool) -> i32 {
    sp.as_ref().map_or(-2, |h| rc(h.sp.set_mute(m)))
}
#[no_mangle]
pub unsafe extern "C" fn okef_set_source(sp: *mut OkefSpeaker, src: *const c_char) -> i32 {
    let (Some(h), Some(src)) = (sp.as_ref(), s(src).and_then(Source::parse)) else { return -2 };
    rc(h.sp.set_source(src))
}
#[no_mangle]
pub unsafe extern "C" fn okef_play_pause(sp: *mut OkefSpeaker) -> i32 { sp.as_ref().map_or(-2, |h| rc(h.sp.play_pause())) }
#[no_mangle]
pub unsafe extern "C" fn okef_next(sp: *mut OkefSpeaker) -> i32 { sp.as_ref().map_or(-2, |h| rc(h.sp.control("next"))) }
#[no_mangle]
pub unsafe extern "C" fn okef_previous(sp: *mut OkefSpeaker) -> i32 { sp.as_ref().map_or(-2, |h| rc(h.sp.control("previous"))) }

#[no_mangle]
pub unsafe extern "C" fn okef_events_start(sp: *mut OkefSpeaker, cb: Option<EventCb>, ctx: *mut c_void) {
    let (Some(h), Some(cb)) = (sp.as_mut(), cb) else { return };
    okef_events_stop(sp);
    let stop = Arc::new(AtomicBool::new(false));
    let (spk, st, ctx) = (h.sp.clone(), stop.clone(), Ctx(ctx));
    let jh = std::thread::spawn(move || {
        let ctx = ctx;
        events::run(spk, st, |e| {
            let j = match e {
                events::Event::State(s) => json!({"type": "state", "state": s}),
                events::Event::Offline(r) => json!({"type": "offline", "reason": r}),
            };
            if let Ok(c) = CString::new(j.to_string()) { cb(ctx.0, c.as_ptr()); }
        });
    });
    h.events = Some((stop, jh));
}

#[no_mangle]
pub unsafe extern "C" fn okef_events_stop(sp: *mut OkefSpeaker) {
    if let Some(h) = sp.as_mut() {
        if let Some((stop, jh)) = h.events.take() { stop.store(true, Ordering::Relaxed); let _ = jh.join(); }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn null_and_bad_args_are_safe() {
        unsafe {
            assert!(okef_connect(std::ptr::null()).is_null());
            assert_eq!(okef_set_volume(std::ptr::null_mut(), 10), -2);
            let h = okef_connect(c"192.0.2.1".as_ptr());
            assert!(!h.is_null());
            assert_eq!(okef_set_source(h, c"laserdisc".as_ptr()), -2);
            okef_free(h);
        }
    }
    #[test]
    fn header_declares_every_export() {
        let hdr = include_str!("../include/openkef.h");
        for f in ["okef_connect","okef_free","okef_get_state","okef_string_free","okef_set_volume","okef_set_mute",
                  "okef_set_source","okef_play_pause","okef_next","okef_previous","okef_events_start","okef_events_stop"] {
            assert!(hdr.contains(&format!("{f}(")), "{f} missing from header");
        }
    }
}
