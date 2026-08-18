# Changelog

All notable changes to this project will be documented in this file.

## 1.0.5

- Fix `lfs_detect_minutiae_V2` parameter types — wrong pointer types caused build failures on Linux.
- Add `free()` calls for NBIS allocated maps after minutiae extraction.
- Suppress `_BSD_SOURCE` deprecation warning in NBIS headers.

## 1.0.4

- Rebuild `libfour_fingerprint.so` with real NIST NBIS MINDTCT (minutiae extraction) and BOZORTH3 (matching).
- Remove unused OpenCV SDK (~819 MB) — code never used it.
- Trim NBIS to essential directories only.
- Add `android/CMakeLists.txt` for `ffiPlugin: true` compatibility.
- Pin NDK version and restrict ABI to arm64-v8a.
- Downgrade AGP from 9.0.1 to 8.1.0 for stability.
- Fix `compileSdk` 36 → 35.

## 1.0.2

- Ship prebuilt `libfour_fingerprint.so` for Android arm64-v8a.
- Remove CMake externalNativeBuild from Android build — no more compiling OpenCV/NFIQ2/NBIS during user builds.
- Add heuristic fallbacks for NBIS/NFIQ2 wrappers when real libraries are unavailable.
- Fix missing global variable definitions (`g_countdown_active`, `g_countdown_remaining`, `g_ring_mode`).

## 1.0.1

- Fix missing native library build configuration for Android.

## 1.0.0

- Initial release.
- 4-4-2 slap capture sequencing.
- Burst capture with NFIQ2-style best-frame selection.
- Minutiae extraction and BOZORTH3-inspired matching.
- ISO/IEC 19794-2 export.
- Encrypted storage via flutter_secure_storage.
