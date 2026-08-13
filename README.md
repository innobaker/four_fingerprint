# four_fingerprint

Contactless slap fingerprint capture Flutter plugin — captures four-finger slap images via phone camera and produces match-ready fingerprint templates, comparable to BioPassID SLAP / Sciometrics SlapShot.

## Features

- **4-4-2 capture sequencing** — left four-finger slap → right four-finger slap → two thumbs
- **Scale/DPI calibration** — anthropometric finger-width priors resample to 500 PPI
- **Finger segmentation** — YCrCb skin-color mask with landmark-guided ROI
- **Illumination normalization** — CLAHE + specular highlight removal
- **Cylindrical unwarping** — finger surface flattening for ridge analysis
- **Liveness gate** — FFT-based texture check (real skin vs print/screen)
- **Burst capture** — 8-frame burst with NFIQ2-style best-frame selection
- **Minutiae extraction** — ridge thinning + crossing-number minutiae detection
- **Template matching** — BOZORTH3-inspired matcher with recalibrated contactless threshold
- **ISO/IEC 19794-2 export** — interoperable minutiae templates
- **WSQ compression** — fingerprint image storage
- **Encrypted storage** — AES-GCM templates at rest via `flutter_secure_storage`

## Architecture

```
lib/
  four_fingerprint.dart          # Public API
  src/
    fp_constants.dart            # Enums, finger codes, thresholds
    fp_models.dart               # Dart data models
    fp_native.dart               # FFI bridge (runs on background isolate)
    fp_capture_controller.dart   # 4-4-2 capture state machine
    fp_storage.dart              # Encrypted template storage

src/                             # Native C processing pipeline
  fp_calibration.c
  fp_segmentation.c
  fp_illumination.c
  fp_unwarp.c
  fp_liveness.c
  fp_quality.c
  fp_minutiae.c
  fp_matching.c
  fp_iso19794.c
  fp_wsq.c
  fp_crypto.c
  fp_state_machine.c
  fp_pipeline.c
```

## Usage

```dart
import 'package:four_fingerprint/four_fingerprint.dart';

await FourFingerprint.instance.initialize();

final controller = FpCaptureController();
await controller.initialize();
controller.startCapture();

// Feed camera frames during capture
await controller.processFrame(cameraImage);

// After 4-4-2 complete
final enrollment = controller.buildEnrollment('user_001');
await FpSecureStorage().storeEnrollment(enrollment!);
```

## Building native code

```bash
cd src && mkdir -p build && cd build
cmake .. && make
```

Regenerate FFI bindings:

```bash
dart run ffigen --config ffigen.yaml
```

## Third-party components

- OpenCV (bundled in `third_party/opencv` for Android/iOS)
- NBIS sources in `third_party/nbis` (MINDTCT, BOZORTH3, WSQ — optional full link)
- NFIQ2 sources in `third_party/nfiq2` (optional full link)
- Hand landmarks via `hand_detection` package (MediaPipe-style TFLite)

## Match threshold

Contactless captures use a recalibrated match threshold of **25** (vs NBIS default ~40 for ink scans). Tune against your own dataset for production FAR/FRR targets.

## Example app

```bash
cd example && flutter run
```

## Compliance

For enterprise KYC or law-enforcement deployment, benchmark against [NIST SP 500-399](https://www.nist.gov/publications/sp-500-399-contactless-fingerprint-capture-device-compliance) (contactless fingerprint acquisition standard).
