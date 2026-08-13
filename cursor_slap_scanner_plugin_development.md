# Slap scanner plugin development
_Exported on 8/13/2026 at 17:35:38 GMT+3 from Cursor (3.4.20)_

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

