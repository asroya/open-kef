// open-kef C ABI. Hand-written; keep in sync with crates/ffi/src/lib.rs.
// All calls are blocking (short timeouts): call off the main thread.
// Return codes: 0 = ok, -1 = speaker/transport error, -2 = bad argument.
#ifndef OPENKEF_H
#define OPENKEF_H
#include <stdint.h>
#include <stdbool.h>

typedef struct OkefSpeaker OkefSpeaker;

// Event callback. json is {"type":"state","state":{...}} or {"type":"offline","reason":"..."}.
// Called on a background thread; json is only valid during the call.
typedef void (*okef_event_cb)(void *ctx, const char *json);

OkefSpeaker *okef_connect(const char *host);          // NULL on bad host. Plain HTTP:80.
void okef_free(OkefSpeaker *sp);                       // stops events, frees.

char *okef_get_state(OkefSpeaker *sp);                 // JSON SpeakerState or NULL; free with okef_string_free.
void okef_string_free(char *s);

int32_t okef_set_volume(OkefSpeaker *sp, uint8_t volume);  // 0..100
int32_t okef_set_mute(OkefSpeaker *sp, bool muted);
int32_t okef_set_source(OkefSpeaker *sp, const char *source); // wifi|bluetooth|tv|optical|usb|...
int32_t okef_play_pause(OkefSpeaker *sp);
int32_t okef_next(OkefSpeaker *sp);
int32_t okef_previous(OkefSpeaker *sp);

// Starts the subscribe/long-poll loop (auto reconnect + backoff). Restarts if already running.
void okef_events_start(OkefSpeaker *sp, okef_event_cb cb, void *ctx);
void okef_events_stop(OkefSpeaker *sp);

#endif
