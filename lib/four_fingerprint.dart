/// Contactless slap fingerprint capture — MediaPipe guidance + native matching.
///
/// Minimal usage:
/// ```dart
/// final result = await FourFingerprint.scan(
///   context,
///   subjectId: 'user_001',
///   profile: CaptureProfile.fourFour, // or fourFourTwo / thumbs / single
///   storage: StorageMode.device,       // or StorageMode.callback for backend
/// );
/// ```
library;

export 'src/finger_detector.dart';
export 'src/fp_capture_controller.dart';
export 'src/fp_constants.dart';
export 'src/fp_models.dart';
export 'src/fp_native.dart';
export 'src/fp_storage.dart';
export 'src/mediapipe_hands.dart';
export 'src/scan_options.dart';
export 'src/widgets/finger_overlay.dart';
export 'src/widgets/slap_scanner.dart';

import 'package:flutter/widgets.dart';

import 'src/fp_constants.dart';
import 'src/fp_native.dart';
import 'src/scan_options.dart';
import 'src/widgets/slap_scanner.dart';

/// Public entry for the `four_fingerprint` package.
class FourFingerprint {
  FourFingerprint._();

  static final FourFingerprint instance = FourFingerprint._();

  String get version => FpNativeBridge.instance.version;

  Future<void> initialize({String? nfiq2ModelDir}) =>
      FpNativeBridge.instance.initialize(nfiq2ModelDir: nfiq2ModelDir);

  /// One-liner slap / fingerprint UI.
  ///
  /// [profile] chooses what to capture:
  /// - [CaptureProfile.fourFour] — left 4 → right 4
  /// - [CaptureProfile.fourFourTwo] — left 4 → right 4 → thumbs
  /// - [CaptureProfile.thumbs] — both thumbs only
  /// - [CaptureProfile.single] — one finger ([singleFinger])
  /// - [CaptureProfile.leftFour] / [CaptureProfile.rightFour]
  ///
  /// [storage]:
  /// - [StorageMode.device] — encrypt on-device
  /// - [StorageMode.callback] — return templates only (you upload)
  /// - [StorageMode.both] — store locally and return for backend
  static Future<SlapScanResult?> scan(
    BuildContext context, {
    required String subjectId,
    ScanMode mode = ScanMode.enroll,
    StorageMode storage = StorageMode.device,
    CaptureProfile profile = CaptureProfile.fourFour,
    FingerCode singleFinger = FingerCode.rightIndex,
    int countdownSeconds = 3,
    RingMode ringMode = RingMode.dynamic,
  }) {
    return openSlapScanner(
      context,
      subjectId: subjectId,
      mode: mode,
      storage: storage,
      profile: profile,
      singleFinger: singleFinger,
      countdownSeconds: countdownSeconds,
      ringMode: ringMode,
    );
  }
}
