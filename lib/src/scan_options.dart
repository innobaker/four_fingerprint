import 'dart:typed_data';

import 'fp_constants.dart';
import 'fp_models.dart';

/// Where enrollment / templates are persisted after a successful scan.
enum StorageMode {
  /// Encrypt and store on-device via flutter_secure_storage.
  device,

  /// Do not store — only return result to the host app (e.g. upload to backend).
  callback,

  /// Store on-device AND return templates for backend upload.
  both,

  /// Neither persist nor require a callback (still returned via widget callback).
  none,
}

/// Scan purpose.
enum ScanMode {
  enroll,
  authenticate,
}

/// Which fingers to capture — 4-4-2 is optional.
///
/// ```dart
/// CaptureProfile.fourFour      // left 4 → right 4
/// CaptureProfile.fourFourTwo  // left 4 → right 4 → thumbs
/// CaptureProfile.thumbs       // both thumbs only
/// CaptureProfile.single       // one finger (set [singleFinger])
/// ```
enum CaptureProfile {
  /// Left four-finger slap → right four-finger slap → both thumbs.
  fourFourTwo,

  /// Left four-finger slap → right four-finger slap (no thumbs).
  fourFour,

  /// Left hand four fingers only.
  leftFour,

  /// Right hand four fingers only.
  rightFour,

  /// Both thumbs only.
  thumbs,

  /// A single finger (see [SlapScanOptions.singleFinger]).
  single,
}

/// One step in a capture sequence.
class CaptureStage {
  const CaptureStage({
    required this.id,
    required this.fingerCodes,
    required this.label,
    this.expectedHand,
  });

  final CaptureStep id;
  final List<FingerCode> fingerCodes;
  final String label;

  /// `left` / `right` / null (any / both).
  final String? expectedHand;

  int get fingerCount => fingerCodes.length;
  bool get isSlap => fingerCount >= 4;
  bool get isThumbs =>
      fingerCodes.length == 2 &&
      fingerCodes.every((c) =>
          c == FingerCode.leftThumb || c == FingerCode.rightThumb);
  bool get isSingle => fingerCount == 1;
}

/// Builds the ordered stage list for a [CaptureProfile].
List<CaptureStage> stagesFor(
  CaptureProfile profile, {
  FingerCode singleFinger = FingerCode.rightIndex,
}) {
  switch (profile) {
    case CaptureProfile.fourFourTwo:
      return const [
        CaptureStage(
          id: CaptureStep.leftSlap,
          fingerCodes: leftSlapFingerCodes,
          label: 'LEFT hand — four fingers',
          expectedHand: 'left',
        ),
        CaptureStage(
          id: CaptureStep.rightSlap,
          fingerCodes: rightSlapFingerCodes,
          label: 'RIGHT hand — four fingers',
          expectedHand: 'right',
        ),
        CaptureStage(
          id: CaptureStep.thumbs,
          fingerCodes: thumbsFingerCodes,
          label: 'Both thumbs',
        ),
      ];
    case CaptureProfile.fourFour:
      return const [
        CaptureStage(
          id: CaptureStep.leftSlap,
          fingerCodes: leftSlapFingerCodes,
          label: 'LEFT hand — four fingers',
          expectedHand: 'left',
        ),
        CaptureStage(
          id: CaptureStep.rightSlap,
          fingerCodes: rightSlapFingerCodes,
          label: 'RIGHT hand — four fingers',
          expectedHand: 'right',
        ),
      ];
    case CaptureProfile.leftFour:
      return const [
        CaptureStage(
          id: CaptureStep.leftSlap,
          fingerCodes: leftSlapFingerCodes,
          label: 'LEFT hand — four fingers',
          expectedHand: 'left',
        ),
      ];
    case CaptureProfile.rightFour:
      return const [
        CaptureStage(
          id: CaptureStep.rightSlap,
          fingerCodes: rightSlapFingerCodes,
          label: 'RIGHT hand — four fingers',
          expectedHand: 'right',
        ),
      ];
    case CaptureProfile.thumbs:
      return const [
        CaptureStage(
          id: CaptureStep.thumbs,
          fingerCodes: thumbsFingerCodes,
          label: 'Both thumbs',
        ),
      ];
    case CaptureProfile.single:
      final hand = singleFinger.code >= 6 ? 'left' : 'right';
      return [
        CaptureStage(
          id: CaptureStep.leftSlap, // reuse step slot for single
          fingerCodes: [singleFinger],
          label: 'Place ${singleFinger.name} finger',
          expectedHand: hand,
        ),
      ];
  }
}

/// Ring overlay mode for finger capture guidance.
enum RingMode {
  dynamic,
  static,
}

/// Options passed to [SlapScanner] / [FourFingerprint.scan].
class SlapScanOptions {
  const SlapScanOptions({
    required this.subjectId,
    this.mode = ScanMode.enroll,
    this.storage = StorageMode.device,
    this.profile = CaptureProfile.fourFour,
    this.singleFinger = FingerCode.rightIndex,
    @Deprecated('Use profile: CaptureProfile.fourFourTwo instead')
    this.includeThumbs = false,
    this.autoCapture = true,
    this.matchThreshold,
    this.countdownSeconds = 3,
    this.ringMode = RingMode.dynamic,
  });

  final String subjectId;
  final ScanMode mode;
  final StorageMode storage;

  /// Which fingers / sequence to capture (4-4, 4-4-2, thumbs, single, …).
  final CaptureProfile profile;

  /// Used when [profile] is [CaptureProfile.single].
  final FingerCode singleFinger;

  @Deprecated('Use profile: CaptureProfile.fourFourTwo instead')
  final bool includeThumbs;

  final bool autoCapture;
  final int? matchThreshold;

  /// Countdown seconds before auto-capture starts (0 = immediate).
  final int countdownSeconds;

  /// Whether finger rings follow landmarks or stay fixed.
  final RingMode ringMode;

  CaptureProfile get effectiveProfile {
    if (includeThumbs && profile == CaptureProfile.fourFour) {
      return CaptureProfile.fourFourTwo;
    }
    return profile;
  }

  List<CaptureStage> get stages =>
      stagesFor(effectiveProfile, singleFinger: singleFinger);
}

/// Result delivered to the host app after enroll / auth.
class SlapScanResult {
  const SlapScanResult({
    required this.subjectId,
    required this.mode,
    required this.success,
    this.profile = CaptureProfile.fourFour,
    this.enrollment,
    this.match,
    this.isoTemplates = const {},
    this.error,
  });

  final String subjectId;
  final ScanMode mode;
  final bool success;
  final CaptureProfile profile;
  final FpEnrollmentRecord? enrollment;
  final FpMatchResult? match;

  /// Finger name → ISO/IEC 19794-2 template bytes (for backend upload).
  final Map<FingerCodeKey, Uint8List> isoTemplates;
  final String? error;
}

typedef FingerCodeKey = String;
