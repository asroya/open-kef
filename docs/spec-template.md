# Feature spec template (open-kef)

Every handoff to code bro uses this file, whichever model or agent writes it. Rules:
- Values come only from `design/tokens.json` (by key, e.g. `space.4`, `type.title`). No raw hex, pt, or ms.
- Visuals come only from a signed-off file in `mockups/`. No adjectives like "premium" or "clean" as requirements.
- Any field left blank blocks the ticket from moving to Build.

---

**Linear ticket:** MET-
**Goal (one sentence):**
**User story:** As Abhi, I want … so that …

## Acceptance criteria
- [ ] (testable, observable behaviour)

## Mockup
- File: `mockups/…html`
- Screenshots per state: `mockups/…/<state>.png`

## Tokens used
| Element | Token keys |
|---|---|
| | |

## States
| State | What shows | Mockup ref |
|---|---|---|
| Playing | | |
| Paused | | |
| Speaker offline | | |
| Changing source | | |
| Loading | | |
| Error | | |

## Speaker API calls
| Action | `crates/core` function | Endpoint / setting path |
|---|---|---|
| | | |

## Edge cases
-

## Slop check (Pixel Snob)
- Detector problems: (must be 0)
- Checklist score: /17 (must be ≤ 4)
- One clear idea: yes / no
- One signature element: yes / no
- One accessory cut: yes / no

## Out of scope
-

## Sign-off
- Design review (design snob bro):
- Direction approved (Abhi, MET-7 only):
