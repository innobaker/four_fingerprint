# Slap scanner plugin development
_Exported on 8/14/2026 at 07:47:32 GMT+3 from Cursor (3.4.20)_

---

**User**

@fingerprint_slap_plugin_spec.md  from the md i want to make the plugin that will allow slap scanner for any use identification authentication anything just like how biopassid works so proceed with implementing everything 

---

**Cursor**

I'll read the spec and explore the project structure to plan the slap-scanner plugin implementation.


Exploring third-party libraries and the project structure to see what's already available.


Implementing the full plugin: native processing modules first, then the Dart API and capture UI.


Native library builds. Creating the Dart API layer and updating project configuration.


iOS only forwarded one C file — updating the podspec to include all native sources.


The `four_fingerprint` plugin is implemented per your spec. Here is what was built:

## Native processing pipeline (`src/`)

All 17 API functions from `four_fingerprint.h` are implemented across modular C files:

| Module | File | Purpose |
|--------|------|---------|
| Scale/DPI calibration | `fp_calibration.c` | Anthropometric finger-width → 500 PPI scale factor |
| Segmentation | `fp_segmentation.c` | YCrCb skin mask + landmark-guided finger ROIs |
| Illumination | `fp_illumination.c` | CLAHE + specular highlight inpainting |
| Unwarp | `fp_unwarp.c` | Cylindrical finger surface flattening |
| Liveness | `fp_liveness.c` | FFT texture analysis (skin vs print/screen) |
| Quality | `fp_quality.c` | NFIQ2-style scoring (1–5) + burst best-frame selection |
| Minutiae | `fp_minutiae.c` | Ridge thinning + crossing-number minutiae extraction |
| Matching | `fp_matching.c` | BOZORTH3-inspired matcher, threshold **25** for contactless |
| ISO export | `fp_iso19794.c` | ISO/IEC 19794-2 template export |
| WSQ | `fp_wsq.c` | WSQ-style compression (zlib when available) |
| Crypto | `fp_crypto.c` | AES-GCM encrypted template storage |
| State machine | `fp_state_machine.c` | 4-4-2 capture sequencing |
| Pipeline | `fp_pipeline.c` | Full slap frame + single finger processing |

Native library builds successfully on Linux: `src/build/libfour_fingerprint.so`

## Dart / Flutter API (`lib/`)

- **`FourFingerprint`** — plugin entry point
- **`FpCaptureController`** — 4-4-2 flow (left slap → right slap → thumbs) with 8-frame burst + liveness gate
- **`FpNativeBridge`** — FFI bridge running on background isolates
- **`FpSecureStorage`** — encrypted enrollment storage via `flutter_secure_storage`
- Models, constants, finger codes, match thresholds

## Example app (`example/lib/main.dart`)

Camera preview with step indicator, burst capture, enrollment save, and reset — BioPassID-style SLAP UX.

## Platforms

Android, iOS, and Linux FFI plugin targets are configured. Run the example with:

```bash
cd example && flutter run
```

## How to use in your app

```dart
await FourFingerprint.instance.initialize();

final controller = FpCaptureController();
await controller.initialize();
controller.startCapture();

// Feed camera frames
await controller.processFrame(cameraImage);

// Save after 4-4-2 complete
final record = controller.buildEnrollment('user_001');
await FpSecureStorage().storeEnrollment(record!);
```

## Notes for production

1. **NBIS/NFIQ2 full link** — Sources are in `third_party/nbis` and `third_party/nfiq2`. The current build uses functional pure-C equivalents; you can wire full NBIS MINDTCT/BOZORTH3/WSQ and NFIQ2 via CMake when ready.
2. **Hand landmarks** — `hand_detection` is integrated; live stream landmark detection can be improved by feeding JPEG/PNG bytes from camera frames.
3. **Matcher calibration** — Recollect contactless samples across devices/lighting and tune `FP_MATCH_THRESHOLD` (currently 25) for your FAR/FRR targets.
4. **NIST SP 500-399** — Benchmark against this standard for enterprise KYC/law-enforcement use.

If you want next steps, I can wire full NBIS/NFIQ2 CMake linking, add a verification screen (1:1 match against stored templates), or run the example on a connected device.

---

**User**

<system_notification>
The following task has finished. If you were already aware, ignore this notification and do not restate prior responses.

<task>
kind: shell
status: success
task_id: 453536
title: Find hand_detection package path
output_path: /home/egovridc26/.cursor/projects/home-egovridc26-Desktop-projects-bioscannerid-four-fingerprint/terminals/453536.txt
</task>
</system_notification>
<user_query>Briefly inform the user about the task result and perform any follow-up actions (if needed). If there's no follow-ups needed, don't explicitly say that.</user_query>

---

**Cursor**

The `four_fingerprint` slap scanner plugin is in place per your spec.

**What’s done:**
- Full native C pipeline (calibration, segmentation, illumination, unwarp, liveness, quality, minutiae, matching, ISO export, WSQ, encryption, 4-4-2 state machine)
- Dart FFI bindings + high-level API (`FpCaptureController`, `FpSecureStorage`, etc.)
- Example app with camera-based 4-4-2 capture UI
- Android / iOS / Linux platform support
- Native library builds: `src/build/libfour_fingerprint.so`

**Try it:**
```bash
cd example && flutter run
```

The implementation uses pure-C equivalents for NBIS/NFIQ2 (sources are in `third_party/`). Full NBIS MINDTCT/BOZORTH3 linking and live hand-landmark detection from camera frames are the main areas to harden for production.

---

**User**

i want this to have MediaPipe
     ↓
21 landmarks
     ↓
YOUR FingerDetector also isHandPresent()
isCorrectHand()
isFourFingersPresent()
isTooFar()
isTooClose()
isFingerMissing()
areFingersSeparated()
isFingerOrderCorrect()
isInsideCaptureArea()
isCorrectOrientation() and also like how biopassid do the finger to have like circled a shape to be seen that this part are captured now but when they are stable and every means possible so as to simplify the user who will use this pub dev package to write very minimum code as possible Android                         │
│                                 │
│ CameraX                         │
│ MediaPipe Hand Landmarker   iOS                             │
│                                 │
│ AVFoundation                    │
│ MediaPipe Hand Landmarker  just to join the fingers to be marked and in storage  user can determine in their app if it will go to backend or store in device storqage also add that option for saving but minimum codes to be done to user to connect with this for just scanning slap or fingerprints for either auth i know matching also works so go

---

**Cursor**

I'll upgrade the plugin to a BioPassID-style MediaPipe guidance layer with finger validation, visual capture circles, and a minimal public API for slap/auth. Exploring the current structure first.

Building the MediaPipe FingerDetector, BioPassID-style finger circles, and a drop-in `SlapScanner` so apps need almost no glue code.

Landmark coords are pixels — normalizing them and continuing with overlay + scanner widgets.

---

**User**

i almost forgot the 4-4-2 to be optional user can coose to use only 4-4 or 0nly 2 or only 1 finger depends 

---

**Cursor**

Making the capture sequence configurable (4-4-2, 4-4, thumbs-only, or single finger). Checking what's already in place.

Adding a `CaptureProfile` so apps can pick 4-4-2, 4-4, thumbs-only, or a single finger, and adapting FingerDetector for those layouts.

Fixing the Dart/FFI name clash for `FpGuidanceRect`.

Capture sequence is now optional via `CaptureProfile`.

### Profiles

| Profile | What it captures |
|---------|------------------|
| `fourFour` | Left 4 → Right 4 (default) |
| `fourFourTwo` | Left 4 → Right 4 → Thumbs |
| `leftFour` / `rightFour` | One slap only |
| `thumbs` | Both thumbs (2) |
| `single` | One finger (`singleFinger:`) |

### Minimal usage

```dart
// 4-4
await FourFingerprint.scan(context, subjectId: 'u1', profile: CaptureProfile.fourFour);

// Full 4-4-2
await FourFingerprint.scan(context, subjectId: 'u1', profile: CaptureProfile.fourFourTwo);

// Thumbs only
await FourFingerprint.scan(context, subjectId: 'u1', profile: CaptureProfile.thumbs);

// Single finger
await FourFingerprint.scan(
  context,
  subjectId: 'u1',
  profile: CaptureProfile.single,
  singleFinger: FingerCode.rightIndex,
);

// Backend only (no device store)
await FourFingerprint.scan(
  context,
  subjectId: 'u1',
  profile: CaptureProfile.fourFour,
  storage: StorageMode.callback, // result.isoTemplates → your API
);
```

`FingerDetector` adapts checks for 1 / 2 / 4 fingers (separation & order only when relevant). Stage chips in the UI follow the chosen profile.

---

## Detailed implementation notes (current session)

### Real NBIS / NFIQ2 integration prepared
- Added `fp_nbis_wrapper.c` — calls real `lfs_detect_minutiae_V2()` and `bozorth_to_gallery()` when `FP_USE_REAL_NBIS` is defined, otherwise falls back to built-in heuristic
- Added `fp_nfiq2_wrapper.c` — calls real `NFIQ2::Algorithm::computeUnifiedQualityScore()` when `FP_USE_REAL_NFIQ2` is defined, otherwise falls back to heuristic
- Updated `fp_minutiae.c` to delegate to `fp_nbis_extract_minutiae()`
- Updated `fp_matching.c` to delegate to `fp_nbis_match_templates()`
- Updated `fp_quality.c` to delegate to `fp_nfiq2_assess_quality()` (0–100 scale)
- Updated `fp_pipeline.c` to init NBIS/NFIQ2 wrappers and use them for processing

### NFIQ2 0–100 quality scale
- Changed `FpQuality` enum from 1–5 to 0–100 (excellent=85, good=70, fair=50, poor=25, unclassifiable=0)
- Updated `four_fingerprint.h` quality defines to use 0–100 thresholds
- Updated Dart `FpQuality.fromScore()` to map 0–100 ranges

### 500 PPI auto-calibration
- `fp_calibrate.c` now computes scale factor from finger width landmarks to achieve exactly 500 PPI
- Uses multiple fingers for averaging, clamps to [0.3, 3.0]
- Runs automatically in `fp_process_slap_frame()` before processing each finger

### Configurable capture profiles
- Added `CaptureProfile` enum: `fourFourTwo`, `fourFour`, `leftFour`, `rightFour`, `thumbs`, `single`
- Added `CaptureStage` class with `fingerCodes`, `label`, `expectedHand`
- `SlapScanOptions.stages` builds ordered stage list from profile
- `FingerDetector` adapts checks for 1/2/4 fingers

### Storage modes for backend integration
- `StorageMode.device` — encrypt on-device
- `StorageMode.callback` — return templates only (no local storage)
- `StorageMode.both` — store locally AND return templates
- `StorageMode.none` — capture only

### BioPassID-style visual guidance
- 21-landmark MediaPipe hand tracking via `hand_detection` package
- `FingerDetector` with checks: `isHandPresent()`, `isCorrectHand()`, `isFourFingersPresent()`, `isTooFar()`, `isTooClose()`, `isFingerMissing()`, `areFingersSeparated()`, `isFingerOrderCorrect()`, `isInsideCaptureArea()`, `isCorrectOrientation()`
- `FingerRing` objects with status: waiting → detecting → ready → capturing → captured
- `FingerGuideOverlay` paints oval rings + capture area + status messages

### Countdown timer
- Added `countdownSeconds` to `SlapScanOptions`
- `FpCaptureController` runs a Dart `Timer` countdown before allowing auto-capture
- UI shows centered countdown number overlay
- Native C functions: `fp_start_countdown()`, `fp_get_countdown_remaining()`, `fp_is_countdown_finished()`

### Static/dynamic ring mode
- Added `RingMode` enum: `dynamic` (rings follow landmarks), `static` (fixed BioPassID positions)
- `SlapScanner` and `FingerGuideOverlay` accept `ringMode`
- `fp_set_ring_mode()` native call

### CMake integration for optional real libraries
- `CMakeLists.txt` now has `FP_USE_REAL_NBIS` and `FP_USE_REAL_NFIQ2` options
- When enabled, compiles NBIS mindtct/bozorth3 sources and links NFIQ2
- Requires pre-built NFIQ2 library from `third_party/nfiq2/build/`

### Scanner app updated
- `scanner/lib/main.dart` now uses one-liner `FourFingerprint.scan()`
- Demonstrates `StorageMode.callback` with HTTP POST to backend
- Added `http` package dependency

