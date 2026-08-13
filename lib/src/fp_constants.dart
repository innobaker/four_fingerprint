/// Finger position codes (ISO/IEC 19794-2).
enum FingerCode {
  unknown(0),
  rightThumb(1),
  rightIndex(2),
  rightMiddle(3),
  rightRing(4),
  rightLittle(5),
  leftThumb(6),
  leftIndex(7),
  leftMiddle(8),
  leftRing(9),
  leftLittle(10);

  const FingerCode(this.code);
  final int code;

  static FingerCode fromCode(int code) =>
      FingerCode.values.firstWhere((e) => e.code == code, orElse: () => unknown);
}

enum MinutiaType {
  bifurcation(0),
  ridgeEnding(1);

  const MinutiaType(this.value);
  final int value;
}

enum LivenessResult {
  notLive(0),
  live(1),
  unknown(-1);

  const LivenessResult(this.value);
  final int value;

  static LivenessResult fromValue(int v) => switch (v) {
        0 => notLive,
        1 => live,
        _ => unknown,
      };
}

enum CaptureStep {
  idle(0),
  leftSlap(1),
  rightSlap(2),
  thumbs(3),
  processing(4),
  complete(5);

  const CaptureStep(this.value);
  final int value;

  static CaptureStep fromValue(int v) => CaptureStep.values.firstWhere(
        (e) => e.value == v,
        orElse: () => idle,
      );
}

enum CaptureEvent {
  start(0),
  leftSlapDone(1),
  rightSlapDone(2),
  thumbsDone(3),
  reset(4);

  const CaptureEvent(this.value);
  final int value;
}

enum FpQuality {
  excellent(1),
  good(2),
  fair(3),
  poor(4),
  unclassifiable(5);

  const FpQuality(this.score);
  final int score;

  static FpQuality fromScore(int s) => FpQuality.values.firstWhere(
        (e) => e.score == s,
        orElse: () => unclassifiable,
      );
}

/// Native return codes.
abstract final class FpResult {
  static const ok = 0;
  static const errInvalidInput = -1;
  static const errProcessingFailed = -2;
  static const errOutOfMemory = -3;
  static const errNotInitialized = -4;
  static const errBufferTooSmall = -5;
  static const errLivenessFailed = -6;

  static String message(int code) => switch (code) {
        ok => 'Success',
        errInvalidInput => 'Invalid input',
        errProcessingFailed => 'Processing failed',
        errOutOfMemory => 'Out of memory',
        errNotInitialized => 'Not initialized',
        errBufferTooSmall => 'Buffer too small',
        errLivenessFailed => 'Liveness check failed',
        _ => 'Unknown error ($code)',
      };
}

/// Recalibrated BOZORTH3 threshold for contactless captures.
const int kContactlessMatchThreshold = 25;

const int kTargetPpi = 500;
const int kBurstFrameCount = 8;
const int kLandmarkCount = 21;

/// Finger codes for each capture step in 4-4-2 sequencing.
const leftSlapFingerCodes = [
  FingerCode.leftIndex,
  FingerCode.leftMiddle,
  FingerCode.leftRing,
  FingerCode.leftLittle,
];

const rightSlapFingerCodes = [
  FingerCode.rightIndex,
  FingerCode.rightMiddle,
  FingerCode.rightRing,
  FingerCode.rightLittle,
];

const thumbsFingerCodes = [
  FingerCode.leftThumb,
  FingerCode.rightThumb,
];
