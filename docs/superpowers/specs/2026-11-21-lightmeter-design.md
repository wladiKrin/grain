# Grain — film lightmeter — design

Date: 2026-11-21
Status: draft for approval

**App name:** Grain · **Package:** `io.github.wladikrin.grain` · **Repo:** github.com/wladiKrin/grain *(repo name is my call)* · **Code licence:** GPLv3 · **Library data licence:** CC0 *(my call)*
Mockups: https://claude.ai/artifact/TjjoktNV7so13osdFTFJsK (the chosen direction is the board "B + viewfinder, swipe dials")

## 1. Intent

A free, open-source lightmeter app for film photographers. The trigger: metering a Canon A-1 with an existing app that interrupted with an upgrade-to-pro prompt and needed several taps and scrolls to change one value. This app exists so that metering is **one gesture**, nothing is ever paywalled, and it is a pleasure to use.

It also knows the photographer's actual gear (camera bodies, lenses) and keeps a frame-by-frame log of each roll, so settings can be attached to photos when they are posted.

### Success looks like

- Open the app → a reading is on screen within about a second.
- Changing aperture or shutter is one swipe, one stop per detent, with haptic feedback.
- The user's own camera and lens are one tap away (favorites), and the dials offer only values that gear can set.
- After a roll, the user has a correct frame-by-frame record with a reference snapshot per frame, exportable.

## 2. Goals, non-goals, anti-goals

**Goals (v1)**
- Reflected-light metering through the phone camera, average and spot (tap on preview).
- Modes: aperture priority, shutter priority, manual; plus free mode (no gear restrictions).
- Optional histogram overlay with film latitude markers.
- Camera/lens library: bundled community library + user's own profiles + favorites.
- Roll and frame logging with snapshots.
- Export of rolls (CSV, JSON) and sharing of profiles (QR code, file).
- Android first; codebase ready for an iOS release.

**Non-goals (v1)**
- Incident metering via accessories, flash metering, zone system tools.
- Cloud sync, accounts, online gallery.
- Writing EXIF into scans — this is the first *planned later* feature (see §9); v1 data must make it possible.
- Developing-time calculators / reciprocity calculators (possible later).

**Anti-goals — would make it a failure even if it works**
- Any paywall, "pro" tier, ads, nag dialogs, or tracking/analytics.
- Accounts or a required network connection.
- Sluggish UI: dropped frames during swiping, a value that lags the finger, slow startup.
- Needing more than one gesture to change aperture, shutter, ISO, or lens.
- Visual clutter. The look is clean and calm.

## 3. Constraints

- Open source; distributed on F-Droid and GitHub releases, Play Store optional. No proprietary dependencies (no Google Play Services, no Firebase) so F-Droid accepts it.
- Lightweight: target installed APK under ~20 MB per ABI.
- Works fully offline.
- The user has not written Kotlin or Flutter before; they will mostly steer and review. Code must be readable and well structured, with a README explaining how to build and run.
- Flutter is not yet installed on the dev machine (Arch Linux); setup is part of the work.
- **Development and test device: Google Pixel 10.** It is the reference device for performance targets and metering accuracy. Minimum Android version: Android 10 / API 29 *(my call — broad enough for older phones, recent enough for modern Camera2 features)*. Features the Pixel has but others may lack (ultra-wide camera, rich haptics) need graceful fallbacks.

## 4. How it's built (decided)

- **Framework: Flutter (Dart)**, confirmed by the owner, because an iOS release is a real possibility. One codebase for UI and logic.
- **Metering: a native bridge per platform** — Kotlin using Camera2 on Android (Swift/AVFoundation later on iOS). The standard Flutter camera plugin does not expose the auto-exposure result, so the bridge must provide the preview plus, per frame, the sensor's exposure time, ISO and the fixed phone aperture, and the luminance of the preview frame (see §5.2 for why).
- **Storage: SQLite via Drift.**
- **Community library: JSON files in the GitHub repo**, one file per body or lens, bundled into the app at build time. People contribute by pull request. No server.

## 5. The app

### 5.1 Main (meter) screen — matches mockup "B + viewfinder, swipe dials"

Visual language: "Paper" — warm off-white ground (#F4F2EE), near-black text (#141414), one accent red (#B8321A) for the metered value, large light-weight numerals (Inter Tight), thin dividers, no shadows or gradients. Fully accessible contrast and ≥44 px touch targets.

Dark mode follows the system by default and can be set to Light or Dark in Settings; the viewfinder stays dark in both.

Top to bottom:
1. **Header:** current body (e.g. "Canon A-1") and roll status ("Roll 4 · frame 12/36"), plus film and push/pull when they change the ISO ("HP5 · 400 → 800"); buttons for viewfinder on/off and the library.
2. **Lens chip** (not in mockup yet): current lens, e.g. "FD 50/1.8". Tap → choose among favorite lenses for this body's mount. For zooms, a focal-length dial appears with the same swipe behavior.
3. **Mode tabs:** Aperture priority | Shutter priority | Manual. (Free mode is selected by picking the "No camera" profile, not a tab.)
   - **Manual:** both aperture and shutter are swipe dials (stacked). Instead of a red metered value, an exposure offset shows how far the settings are from the meter, in the gear's step size, e.g. **+⅔** or **−1⅓**, and **0** when it matches, drawn like a small match-needle scale (−3…+3). The offset is logged with the frame.
4. **Viewfinder** (toggleable): live preview **cropped to the field of view of the current focal length on the body's film format** (35 mm by default); the frame is drawn sideways (landscape) by default, and a button on the viewfinder turns it upright (remembered; the ultra-wide takes over once the whole frame no longer fits the main camera's picture; added 2026-11-22); uses the phone's ultra-wide camera when the lens is wider than the main camera and an ultra-wide exists. A spot reticle; tap anywhere to move the spot. EV readout in a corner. When hidden, the camera still meters, and the numerals grow.
   - **Histogram overlay** (toggle, off by default, remembered): a small luminance histogram of the lens crop, drawn in the viewfinder's lower corner, with the metered value marked and a band for the film's latitude (default −2 to +3 stops for negative film, −½ to +½ for slide film, chosen from the roll's film type; editable). It shows whether shadows or highlights will fall outside what the film can hold. Only shown when the viewfinder is on.
5. **Two value rows:** the one being set shows a swipe dial (big value, faded neighbors on each side, tick ruler beneath with a center marker). The other row shows the metered result in the accent color with a "METERED" label.
6. **ISO** with − / + (set from the roll's film when a roll is loaded).
7. **Log frame** button.

**Swipe dial behavior (decided):**
- Horizontal drag; **one value per detent**. A fast release keeps the dial spinning with friction until it stops on a value; a touch stops it (changed 2026-11-22 after first use).
- Haptic tick at every detent; **stronger tick on full stops** when the dial moves in thirds/halves.
- Tapping a faded neighbor moves one step.
- The ruler follows the finger 1:1 between detents.
- Optional click sound, off by default.

**Camera-shake warning:** when shutter is slower than ~1/focal length, the shutter value shows a quiet warning mark. Setting, off by default *(builder's call: off by default)*.

### 5.2 Metering

- Reflected metering, calibrated to the camera's AE target (≈ 18 % gray).
- **What is measured (my call):** the app computes brightness itself from the preview frames' luminance (Y plane), using the phone's AE exposure as the absolute reference: `EV_region = EV_AE + log2(mean_luma_region / mean_luma_frame)` (in linear light). This makes two things work on every phone, including those that report zero AE metering regions:
  - **Average** = the area inside the lens crop (what the film camera sees), centre-weighted. It does not cover the whole phone frame.
  - **Spot** = a small circle (~3–5 % of the crop's width) at the tapped point.
  If the phone does support AE regions, the bridge may also set them as a refinement, but nothing depends on it.
- Scene EV (at ISO 100) computed from the phone's auto-exposure result: `EV100 = log2(N² / t) − log2(ISO_phone / 100)` with N = phone aperture, t = exposure time.
- Then for the chosen film ISO: priority mode solves for the missing value and **snaps to the nearest value the current gear allows**.
- **Per-phone calibration offset** in settings (±3 EV in 1/3 steps), because phones disagree slightly.
- Readings update live; a hold/lock function freezes the reading *(builder's call: long-press on the EV readout or a small lock button)*.
- If the exact result is outside the gear's range, show the closest end value with an over/under indication.

### 5.3 Gear library

**Bodies** carry: make, model, mount, film format (35 mm, half-frame, 6×6, 6×7, 6×4.5…), shutter speeds actually available (list, incl. Bulb), default frame count, ISO/ASA dial range.

**Lenses** carry: make, name, mount, focal length or zoom range, maximum aperture (constant or varying across a zoom), minimum aperture, aperture step (full/half/third).

Three layers:
1. **Bundled library** from the repo, read-only in the app.
2. **User profiles**: create from scratch or "duplicate and edit" a bundled one.
3. **Favorites**: star bodies and lenses; favorites appear first in all pickers, and the lens chip only cycles favorites for the current mount (with "more…" to see all).

**Free mode / "No camera":** always present. Apertures f/1–f/64, shutter 1/8000 – 30 s plus Bulb, **in thirds**, strong haptic tick on full stops. Format 35 mm. **Lens (my call):** no lens from the library; instead the lens chip becomes a plain focal-length dial (12–600 mm, common focal lengths as detents), which drives the viewfinder crop, the camera-shake warning and what gets logged.

**Sharing profiles:** export a body or lens (or a body + lens kit) as a QR code (scan in-app) or a JSON file (share sheet). The JSON format is the same as the repo library format, so a shared file can be submitted to the library as-is.

**Library file format (sketch, builder finalizes):**
```json
{
  "schema": 1,
  "type": "body",
  "id": "canon-a1",
  "make": "Canon",
  "model": "A-1",
  "mount": "canon-fd",
  "format": "135",
  "frames": 36,
  "shutter": ["1/1000","1/500","1/250","1/125","1/60","1/30","1/15","1/8","1/4","1/2","1","2","4","8","15","30","B"],
  "iso": [6, 12800]
}
```
Repo layout: `library/bodies/<make>/<id>.json`, `library/lenses/<mount>/<id>.json`. A CI check validates every file against a JSON schema. Starting library: a modest set of common bodies and lenses (builder's call which; Canon A-1 and FD 50/1.8 must be included).

### 5.4 Rolls and frames

**How the meter screen, body and roll relate (my calls):**
- **No active roll:** the button reads **"Save reading"** and saves a standalone reading (all exposure values, gear, time, snapshot, optional note/location) to a **Saved readings** list. This is the "reading to come back to" the user asked for. A small "Start roll" link sits next to it.
- **Active roll:** the button reads **"Log frame N"** and adds a frame to the roll.
- **Body is fixed for a roll.** Picking another body while a roll is active asks: "Finish roll 4 and start a new one?" or "Meter only (don't log)". In meter-only mode the button falls back to "Save reading".
- **Lens can change freely** during a roll (only lenses that fit the body's mount); each frame records its lens.
- **ISO** starts at the roll's exposed-at ISO. Changing it with −/+ during a roll applies to the following frames and is recorded per frame; the roll's ISO stays unchanged. The ISO shows a small marker when it differs from the roll's.

**Roll:** film stock (free text with suggestions), film type (colour negative / B&W negative / slide, used for the histogram latitude), box speed, push/pull in stops (−3…+3, thirds allowed), giving the exposed-at ISO = box × 2^push, which the meter uses automatically. Push/pull is shown prominently on the roll screen and in exports so it reaches whoever develops the film. Also: body, size (12/24/36/72/custom; default from body), starting frame number (00, 0 or 1), notes, status (active/finished). One active roll at a time *(builder's call)*.

**Frame (logged with one tap):** frame number, aperture, shutter, ISO, lens, focal length, mode, timestamp, metered EV, optional location, optional note, snapshot.

- **The counter continues past the nominal size** (37, 38…), shown with a subtle "+1" marker; nothing blocks logging.
- **Roll view** lists frames with thumbnails; allows edit of any field, insert blank frame, delete frame, renumber from a frame. "Finish roll" closes it.
- **Snapshot:** taken from the running preview at log time (no shutter delay), downscaled to ~1000 px long edge, JPEG ~100 KB, stored in app-private storage, not the gallery. On by default; setting to turn off. Not taken when the viewfinder is hidden *(builder's call — or use the stream anyway; see open questions)*. Individual snapshots can be deleted.
- **Location:** off by default, opt-in in settings; if off, no location is stored anywhere, including the snapshot.

**Storage and backup:** everything (rolls, frames, saved readings, user profiles, favorites, settings) lives in the app's own on-device database; nothing has to be exported to be kept. The app opts into Android's automatic backup for the database and settings (snapshots excluded because of Android's size cap). Settings also offers **Export everything / Import everything**: a single file (zip with JSON + snapshots) that restores fully on any phone. Import merges by stable IDs and never silently overwrites.

**Export:** per roll as CSV and JSON (JSON includes everything needed for later EXIF writing: frame number, all exposure values, lens, focal length, film, timestamp, location). Snapshots optionally exported as a zip alongside.

### 5.5 Settings

Backup: export everything / import everything (see §5.4) · Calibration offset · haptics on/off · click sound on/off · snapshots on/off · location on/off · camera-shake warning on/off · default viewfinder on/off (remembered) · units/display details at builder's discretion.

## 6. Performance targets

- Cold start to live reading: ≤ 1.5 s on a mid-range phone.
- Dial drag at the display's refresh rate with no dropped frames; haptic within one frame of crossing a detent.
- Logging a frame feels instant (snapshot encoding happens off the UI thread).

## 7. Testing

- Unit tests for exposure math (EV, solving, snapping to gear value lists, thirds/halves sequences, ranges).
- Unit tests for library parsing/validation and roll numbering edge cases (00/0/1 start, overrun, insert/delete/renumber).
- Widget tests for the swipe dial (detent stepping, one value per detent).
- Manual test checklist for metering accuracy against a known reference (a camera's meter) and calibration.

## 8. What's left to the builder

Project structure, state management approach, exact Drift schema, navigation, animation details, icon set, app icon, exact contents of the starting library, the library JSON schema details, how the native bridge streams preview frames to Flutter, and anything else not decided above.

## 9. Later (not v1, but don't block it)

1. **Write EXIF into scans:** match scan files to frames by number and write the exposure data. Could be in-app (pick a folder of scans) or a small desktop tool.
2. iOS release (native metering bridge in Swift).
3. In-app update of the community library without an app update.
4. Reciprocity-failure helper for long exposures.

## 10. Open questions

None. All owner questions from the builder check are answered above.
