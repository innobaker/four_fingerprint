# Contactless Slap Fingerprint Capture — Flutter Plugin Build Spec

## Goal
Build a Flutter plugin (`four_fingerprint`) that captures four-finger slap images via phone camera and produces match-ready fingerprint templates, comparable in function to BioPassID SLAP / Sciometrics SlapShot / Neurotechnology Slap Verification SDK.

## Existing components
- OpenCV (image processing)
- NBIS (MINDTCT minutiae extraction, BOZORTH3 matching, WSQ compression)
- NFIQ2 (quality scoring)
- Hand/finger landmark model (pose detection)

## Required additions

### 1. Scale / DPI calibration module (build first — everything downstream depends on it)
- Problem: phone camera pixels have no fixed real-world scale; distance and device vary per capture.
- Approach: either (a) reference-object-in-frame calibration, (b) anthropometric finger-width priors combined with landmark distances, or (c) depth-based scale via ARKit (iOS) / ARCore Depth API (Android).
- Output: a per-capture scale factor used to resample crops to a true 500 PPI equivalent before MINDTCT.

### 2. Precise finger segmentation mask
- Problem: landmark models give joints/bounding boxes, not pixel-accurate finger boundaries.
- Approach: lightweight U-Net (train with `segmentation_models.pytorch`, export to TFLite/Core ML) or classic YCrCb skin-color segmentation + GrabCut refinement as a cheaper first pass.

### 3. Illumination normalization + specular highlight removal
- Run before ridge enhancement.
- CLAHE (`cv2.createCLAHE`) for adaptive contrast.
- HSV saturation/value thresholding to detect highlights, `cv2.inpaint` to remove them.

### 4. Cylindrical surface unwarping
- Problem: fingers are cylinders; planar perspective correction under-corrects ridge curvature near edges.
- Approach: custom remap using `cv2.remap()` with a coordinate map derived from an elliptical/cylindrical finger cross-section model. Reference academic implementations of "contactless fingerprint 3D unwarping" for adaptable code.

### 5. Liveness / anti-spoofing gate
- Runs at capture time, before segmentation.
- Minimum viable: FFT-based texture/frequency check (real skin vs. printed/screen).
- Stronger: small CNN classifier trained on the LivDet dataset (livdet.org).

### 6. Multi-frame burst capture + best-frame selection
- Capture 5–10 frames per finger position.
- Score each with NFIQ2 (already available); keep highest-quality frame per finger.

### 7. Hand/finger identity + 4-4-2 capture sequencing
- Use the handedness label already output by the hand landmark model (e.g. MediaPipe `Handedness`).
- Build a capture flow state machine: left four-finger slap → right four-finger slap → two thumbs.

### 8. Template export + encrypted storage
- Export ISO/IEC 19794-2 minutiae templates from MINDTCT output for interoperability.
- Use NBIS's built-in WSQ compression for image storage.
- Encrypt templates at rest: `flutter_secure_storage` for key management, AES-GCM for data.

### 9. Matcher threshold recalibration
- BOZORTH3's default threshold is tuned for ink/optical scans, not contactless captures.
- Recalibrate FAR/FRR against a self-collected dataset across multiple phone models and lighting conditions before trusting MATCH output.

## Suggested build order
1. Dataset collection (labeled captures across several devices/lighting conditions — needed to validate everything below)
2. Scale/DPI calibration module
3. Segmentation mask upgrade (landmarks → real mask)
4. Illumination/specular preprocessing
5. Cylindrical unwarp
6. Liveness gate
7. Burst capture + NFIQ2-based frame selection
8. Hand/finger sequencing state machine
9. Template export + encrypted storage
10. Matcher threshold calibration against own dataset
11. Flutter FFI bindings + platform ports (Android/iOS) for each native module
12. Publish `four_fingerprint` plugin

## Compliance note
If targeting enterprise KYC or law-enforcement use, benchmark against NIST SP 500-399 (the federal spec for contactless fingerprint acquisition devices) — this is the standard vendors like Sciometrics certify against.
