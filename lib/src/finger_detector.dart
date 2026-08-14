import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'fp_constants.dart';

/// MediaPipe hand landmark indices (21 points).
abstract final class MpLandmark {
  static const wrist = 0;
  static const thumbCmc = 1;
  static const thumbMcp = 2;
  static const thumbIp = 3;
  static const thumbTip = 4;
  static const indexMcp = 5;
  static const indexPip = 6;
  static const indexDip = 7;
  static const indexTip = 8;
  static const middleMcp = 9;
  static const middlePip = 10;
  static const middleDip = 11;
  static const middleTip = 12;
  static const ringMcp = 13;
  static const ringPip = 14;
  static const ringDip = 15;
  static const ringTip = 16;
  static const pinkyMcp = 17;
  static const pinkyPip = 18;
  static const pinkyDip = 19;
  static const pinkyTip = 20;
}

/// Per-finger capture ring status (BioPassID-style).
enum FingerRingStatus {
  waiting,
  detecting,
  ready,
  capturing,
  captured,
  error,
}

/// One finger oval/circle overlay target.
class FingerRing {
  const FingerRing({
    required this.fingerCode,
    required this.center,
    required this.radius,
    required this.status,
    required this.label,
  });

  final FingerCode fingerCode;
  /// Normalized [0–1] center in image space.
  final Offset center;
  /// Normalized radius relative to image width.
  final double radius;
  final FingerRingStatus status;
  final String label;
}

/// Result of [FingerDetector] evaluation for a frame.
class FingerGuideResult {
  const FingerGuideResult({
    required this.handPresent,
    required this.correctHand,
    required this.fourFingersPresent,
    required this.tooFar,
    required this.tooClose,
    required this.fingerMissing,
    required this.fingersSeparated,
    required this.fingerOrderCorrect,
    required this.insideCaptureArea,
    required this.correctOrientation,
    required this.stable,
    required this.readyToCapture,
    required this.message,
    required this.rings,
    required this.landmarks,
    required this.handedness,
  });

  final bool handPresent;
  final bool correctHand;
  final bool fourFingersPresent;
  final bool tooFar;
  final bool tooClose;
  final bool fingerMissing;
  final bool fingersSeparated;
  final bool fingerOrderCorrect;
  final bool insideCaptureArea;
  final bool correctOrientation;
  final bool stable;
  final bool readyToCapture;
  final String message;
  final List<FingerRing> rings;
  final Float32List? landmarks;
  final HandednessHint handedness;

  bool get allChecksPass =>
      handPresent &&
      correctHand &&
      fourFingersPresent &&
      !tooFar &&
      !tooClose &&
      !fingerMissing &&
      fingersSeparated &&
      fingerOrderCorrect &&
      insideCaptureArea &&
      correctOrientation;
}

enum HandednessHint { unknown, left, right }

/// MediaPipe → guidance checks for slap capture (BioPassID-style).
class FingerDetector {
  FingerDetector({
    this.expectedHand,
    this.captureArea = const Rect.fromLTRB(0.08, 0.12, 0.92, 0.78),
    this.minPalmNorm = 0.18,
    this.maxPalmNorm = 0.72,
    this.minFingerGapNorm = 0.025,
    this.stabilityFramesRequired = 12,
  });

  /// Expected hand for current step (`left` / `right`), or null for either.
  HandednessHint? expectedHand;

  /// Normalized capture region where the slap must sit.
  final Rect captureArea;

  /// Palm span (MCP index→pinky) relative to image width.
  final double minPalmNorm;
  final double maxPalmNorm;
  final double minFingerGapNorm;
  final int stabilityFramesRequired;

  int _stableStreak = 0;
  Float32List? _prevLandmarks;
  final Set<FingerCode> _captured = {};

  void resetStability() {
    _stableStreak = 0;
    _prevLandmarks = null;
  }

  void markCaptured(FingerCode code) => _captured.add(code);

  void clearCaptured() => _captured.clear();

  bool isHandPresent(Float32List? lm) =>
      lm != null && lm.length >= kLandmarkCount * 3;

  bool isCorrectHand(HandednessHint detected) {
    if (expectedHand == null || expectedHand == HandednessHint.unknown) {
      return true; // any / both hands ok
    }
    if (detected == HandednessHint.unknown) return true; // soft fail
    return detected == expectedHand;
  }

  /// True when every finger in [fingerCodes] is extended / visible.
  bool isFourFingersPresent(Float32List lm, [List<FingerCode>? fingerCodes]) {
    return areRequiredFingersPresent(lm, fingerCodes ?? const [
          FingerCode.rightIndex,
          FingerCode.rightMiddle,
          FingerCode.rightRing,
          FingerCode.rightLittle,
        ]);
  }

  bool areRequiredFingersPresent(Float32List lm, List<FingerCode> fingerCodes) {
    for (final code in fingerCodes) {
      final tip = _tipIndex(code);
      final mcp = _mcpIndex(code);
      if (_dist(_pt(lm, tip), _pt(lm, mcp)) < 0.035) return false;
      if (!_visible(lm, tip) || !_visible(lm, mcp)) return false;
    }
    return true;
  }

  bool isTooFar(Float32List lm, {int fingerCount = 4}) {
    if (fingerCount <= 1) {
      // Single finger: use tip–MCP length as proxy for distance.
      final tip = _pt(lm, MpLandmark.indexTip);
      final mcp = _pt(lm, MpLandmark.indexMcp);
      return _dist(tip, mcp) < 0.08;
    }
    return _palmSpan(lm) < minPalmNorm * (fingerCount >= 4 ? 1.0 : 0.7);
  }

  bool isTooClose(Float32List lm, {int fingerCount = 4}) {
    if (fingerCount <= 1) {
      final tip = _pt(lm, MpLandmark.indexTip);
      final mcp = _pt(lm, MpLandmark.indexMcp);
      return _dist(tip, mcp) > 0.45;
    }
    return _palmSpan(lm) > maxPalmNorm;
  }

  bool isFingerMissing(Float32List lm, [List<FingerCode>? fingerCodes]) =>
      !areRequiredFingersPresent(
        lm,
        fingerCodes ??
            const [
              FingerCode.rightIndex,
              FingerCode.rightMiddle,
              FingerCode.rightRing,
              FingerCode.rightLittle,
            ],
      );

  bool areFingersSeparated(Float32List lm, [List<FingerCode>? fingerCodes]) {
    final codes = fingerCodes ??
        const [
          FingerCode.rightIndex,
          FingerCode.rightMiddle,
          FingerCode.rightRing,
          FingerCode.rightLittle,
        ];
    if (codes.length < 2) return true;
    final tips = codes.map((c) => _pt(lm, _tipIndex(c))).toList();
    for (var i = 0; i < tips.length - 1; i++) {
      if (_dist(tips[i], tips[i + 1]) < minFingerGapNorm) return false;
    }
    return true;
  }

  bool isFingerOrderCorrect(
    Float32List lm,
    HandednessHint hand, [
    List<FingerCode>? fingerCodes,
  ]) {
    final codes = fingerCodes ??
        const [
          FingerCode.rightIndex,
          FingerCode.rightMiddle,
          FingerCode.rightRing,
          FingerCode.rightLittle,
        ];
    if (codes.length < 2) return true;
    // Only enforce slap order for 4-finger lays.
    if (codes.length < 4) return true;
    final xs = codes.map((c) => _pt(lm, _tipIndex(c)).dx).toList();
    if (hand == HandednessHint.right) {
      return xs[0] < xs[1] && xs[1] < xs[2] && xs[2] < xs[3];
    }
    if (hand == HandednessHint.left) {
      return xs[0] > xs[1] && xs[1] > xs[2] && xs[2] > xs[3];
    }
    final asc = xs[0] < xs[1] && xs[1] < xs[2] && xs[2] < xs[3];
    final desc = xs[0] > xs[1] && xs[1] > xs[2] && xs[2] > xs[3];
    return asc || desc;
  }

  bool isInsideCaptureArea(Float32List lm, [List<FingerCode>? fingerCodes]) {
    final codes = fingerCodes ??
        const [
          FingerCode.rightIndex,
          FingerCode.rightMiddle,
          FingerCode.rightRing,
          FingerCode.rightLittle,
        ];
    for (final c in codes) {
      if (!captureArea.contains(_pt(lm, _tipIndex(c)))) return false;
    }
    return true;
  }

  bool isCorrectOrientation(Float32List lm, [List<FingerCode>? fingerCodes]) {
    final codes = fingerCodes ?? const [FingerCode.rightMiddle];
    final code = codes[codes.length ~/ 2];
    final tip = _pt(lm, _tipIndex(code));
    final mcp = _pt(lm, _mcpIndex(code));
    final wrist = _pt(lm, MpLandmark.wrist);
    final tipAboveMcp = tip.dy < mcp.dy + 0.02;
    final mcpAboveWrist = mcp.dy < wrist.dy + 0.08;
    return tipAboveMcp && mcpAboveWrist;
  }

  bool isStable(Float32List lm) {
    if (_prevLandmarks == null) {
      _prevLandmarks = Float32List.fromList(lm);
      _stableStreak = 0;
      return false;
    }
    var move = 0.0;
    for (var i = 0; i < kLandmarkCount; i++) {
      move += _dist(_pt(lm, i), _pt(_prevLandmarks!, i));
    }
    move /= kLandmarkCount;
    _prevLandmarks = Float32List.fromList(lm);
    if (move < 0.012) {
      _stableStreak++;
    } else {
      _stableStreak = 0;
    }
    return _stableStreak >= stabilityFramesRequired;
  }

  /// Evaluate one MediaPipe landmark frame for the current capture stage.
  FingerGuideResult evaluate({
    required Float32List? landmarks,
    required HandednessHint handedness,
    required List<FingerCode> fingerCodes,
  }) {
    if (!isHandPresent(landmarks)) {
      _stableStreak = 0;
      return FingerGuideResult(
        handPresent: false,
        correctHand: false,
        fourFingersPresent: false,
        tooFar: false,
        tooClose: false,
        fingerMissing: true,
        fingersSeparated: false,
        fingerOrderCorrect: false,
        insideCaptureArea: false,
        correctOrientation: false,
        stable: false,
        readyToCapture: false,
        message: 'Show your hand in the frame',
        rings: _emptyRings(fingerCodes),
        landmarks: null,
        handedness: HandednessHint.unknown,
      );
    }

    final lm = landmarks!;
    final n = fingerCodes.length;
    final present = true;
    final correct = isCorrectHand(handedness);
    final fingersOk = areRequiredFingersPresent(lm, fingerCodes);
    final far = isTooFar(lm, fingerCount: n);
    final close = isTooClose(lm, fingerCount: n);
    final missing = !fingersOk;
    final separated = areFingersSeparated(lm, fingerCodes);
    final order = isFingerOrderCorrect(lm, handedness, fingerCodes);
    final inside = isInsideCaptureArea(lm, fingerCodes);
    final orient = isCorrectOrientation(lm, fingerCodes);

    final checksOk = present &&
        correct &&
        fingersOk &&
        !far &&
        !close &&
        !missing &&
        separated &&
        order &&
        inside &&
        orient;

    final stable = checksOk && isStable(lm);
    if (!checksOk) _stableStreak = 0;

    final message = _message(
      correct: correct,
      four: fingersOk,
      far: far,
      close: close,
      separated: separated,
      order: order,
      inside: inside,
      orient: orient,
      stable: stable,
      fingerCount: n,
    );

    final rings = _buildRings(
      lm: lm,
      fingerCodes: fingerCodes,
      checksOk: checksOk,
      stable: stable,
    );

    return FingerGuideResult(
      handPresent: present,
      correctHand: correct,
      fourFingersPresent: fingersOk,
      tooFar: far,
      tooClose: close,
      fingerMissing: missing,
      fingersSeparated: separated,
      fingerOrderCorrect: order,
      insideCaptureArea: inside,
      correctOrientation: orient,
      stable: stable,
      readyToCapture: stable,
      message: message,
      rings: rings,
      landmarks: lm,
      handedness: handedness,
    );
  }

  List<FingerRing> _buildRings({
    required Float32List lm,
    required List<FingerCode> fingerCodes,
    required bool checksOk,
    required bool stable,
  }) {
    final rings = <FingerRing>[];
    for (final code in fingerCodes) {
      final tipIdx = _tipIndex(code);
      final pipIdx = _pipIndex(code);
      final tip = _pt(lm, tipIdx);
      final pip = _pt(lm, pipIdx);
      final center = Offset((tip.dx + pip.dx) / 2, (tip.dy + pip.dy) / 2);
      final radius = math.max(0.04, _dist(tip, pip) * 0.55);

      FingerRingStatus status;
      if (_captured.contains(code)) {
        status = FingerRingStatus.captured;
      } else if (stable) {
        status = FingerRingStatus.capturing;
      } else if (checksOk) {
        status = FingerRingStatus.ready;
      } else if (isHandPresent(lm)) {
        status = FingerRingStatus.detecting;
      } else {
        status = FingerRingStatus.waiting;
      }

      rings.add(FingerRing(
        fingerCode: code,
        center: center,
        radius: radius,
        status: status,
        label: _label(code),
      ));
    }
    return rings;
  }

  List<FingerRing> _emptyRings(List<FingerCode> codes) {
    final slots = [
      const Offset(0.28, 0.42),
      const Offset(0.42, 0.38),
      const Offset(0.56, 0.38),
      const Offset(0.70, 0.42),
    ];
    return List.generate(codes.length, (i) {
      return FingerRing(
        fingerCode: codes[i],
        center: slots[i % slots.length],
        radius: 0.07,
        status: FingerRingStatus.waiting,
        label: _label(codes[i]),
      );
    });
  }

  String _message({
    required bool correct,
    required bool four,
    required bool far,
    required bool close,
    required bool separated,
    required bool order,
    required bool inside,
    required bool orient,
    required bool stable,
    required int fingerCount,
  }) {
    if (!correct) {
      final want = expectedHand == HandednessHint.left ? 'LEFT' : 'RIGHT';
      return 'Use your $want hand';
    }
    if (far) return 'Move closer';
    if (close) return 'Move farther away';
    if (!four) {
      if (fingerCount <= 1) return 'Show the finger clearly';
      if (fingerCount == 2) return 'Show both thumbs';
      return 'Show all $fingerCount fingers';
    }
    if (!separated && fingerCount > 1) return 'Separate your fingers';
    if (!order && fingerCount >= 4) {
      return 'Keep fingers in order (index → pinky)';
    }
    if (!inside) return 'Move hand into the capture area';
    if (!orient) return 'Point fingers upward / flatten the slap';
    if (!stable) {
      final left = (stabilityFramesRequired - _stableStreak).clamp(0, 99);
      return 'Hold steady… ($left)';
    }
    return 'Capturing…';
  }

  static Offset _pt(Float32List lm, int idx) =>
      Offset(lm[idx * 3], lm[idx * 3 + 1]);

  static double _dist(Offset a, Offset b) => (a - b).distance;

  static bool _visible(Float32List lm, int idx) {
    final x = lm[idx * 3];
    final y = lm[idx * 3 + 1];
    return x >= 0 && x <= 1 && y >= 0 && y <= 1;
  }

  static double _palmSpan(Float32List lm) =>
      _dist(_pt(lm, MpLandmark.indexMcp), _pt(lm, MpLandmark.pinkyMcp));

  static int _tipIndex(FingerCode code) => switch (code) {
        FingerCode.rightThumb || FingerCode.leftThumb => MpLandmark.thumbTip,
        FingerCode.rightIndex || FingerCode.leftIndex => MpLandmark.indexTip,
        FingerCode.rightMiddle || FingerCode.leftMiddle => MpLandmark.middleTip,
        FingerCode.rightRing || FingerCode.leftRing => MpLandmark.ringTip,
        FingerCode.rightLittle || FingerCode.leftLittle => MpLandmark.pinkyTip,
        _ => MpLandmark.indexTip,
      };

  static int _pipIndex(FingerCode code) => switch (code) {
        FingerCode.rightThumb || FingerCode.leftThumb => MpLandmark.thumbIp,
        FingerCode.rightIndex || FingerCode.leftIndex => MpLandmark.indexPip,
        FingerCode.rightMiddle || FingerCode.leftMiddle => MpLandmark.middlePip,
        FingerCode.rightRing || FingerCode.leftRing => MpLandmark.ringPip,
        FingerCode.rightLittle || FingerCode.leftLittle => MpLandmark.pinkyPip,
        _ => MpLandmark.indexPip,
      };

  static int _mcpIndex(FingerCode code) => switch (code) {
        FingerCode.rightThumb || FingerCode.leftThumb => MpLandmark.thumbMcp,
        FingerCode.rightIndex || FingerCode.leftIndex => MpLandmark.indexMcp,
        FingerCode.rightMiddle || FingerCode.leftMiddle => MpLandmark.middleMcp,
        FingerCode.rightRing || FingerCode.leftRing => MpLandmark.ringMcp,
        FingerCode.rightLittle || FingerCode.leftLittle => MpLandmark.pinkyMcp,
        _ => MpLandmark.indexMcp,
      };

  static String _label(FingerCode code) => switch (code) {
        FingerCode.rightThumb || FingerCode.leftThumb => 'Thumb',
        FingerCode.rightIndex || FingerCode.leftIndex => 'Index',
        FingerCode.rightMiddle || FingerCode.leftMiddle => 'Middle',
        FingerCode.rightRing || FingerCode.leftRing => 'Ring',
        FingerCode.rightLittle || FingerCode.leftLittle => 'Little',
        _ => 'Finger',
      };
}
