import 'dart:typed_data';

import 'fp_constants.dart';

class FpMinutiaPoint {
  const FpMinutiaPoint({
    required this.x,
    required this.y,
    required this.direction,
    required this.type,
    required this.reliability,
  });

  final int x;
  final int y;
  final int direction;
  final MinutiaType type;
  final double reliability;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'direction': direction,
        'type': type.name,
        'reliability': reliability,
      };
}

class FpFingerCapture {
  const FpFingerCapture({
    required this.fingerCode,
    required this.quality,
    required this.minutiae,
    required this.isLive,
    required this.resolutionPpi,
    required this.scaleFactor,
    this.normalizedImage,
    this.isoTemplate,
  });

  final FingerCode fingerCode;
  final FpQuality quality;
  final List<FpMinutiaPoint> minutiae;
  final LivenessResult isLive;
  final int resolutionPpi;
  final double scaleFactor;
  final Uint8List? normalizedImage;
  final Uint8List? isoTemplate;

  Map<String, dynamic> toJson() => {
        'fingerCode': fingerCode.name,
        'quality': quality.score,
        'minutiaCount': minutiae.length,
        'isLive': isLive.name,
        'resolutionPpi': resolutionPpi,
        'scaleFactor': scaleFactor,
      };
}

class FpSlapCaptureResult {
  const FpSlapCaptureResult({
    required this.success,
    required this.fingers,
    required this.totalMinutiae,
  });

  final bool success;
  final List<FpFingerCapture> fingers;
  final int totalMinutiae;
}

class FpEnrollmentRecord {
  const FpEnrollmentRecord({
    required this.subjectId,
    required this.fingers,
    required this.enrolledAt,
  });

  final String subjectId;
  final List<FpFingerCapture> fingers;
  final DateTime enrolledAt;

  List<FpMinutiaPoint> minutiaeFor(FingerCode code) {
    final finger = fingers.where((f) => f.fingerCode == code).firstOrNull;
    return finger?.minutiae ?? [];
  }
}

class FpMatchResult {
  const FpMatchResult({
    required this.score,
    required this.isMatch,
    required this.fingerCode,
  });

  final int score;
  final bool isMatch;
  final FingerCode fingerCode;
}

class FpGuidanceData {
  const FpGuidanceData({
    required this.handDistance,
    required this.fingerAlignment,
    required this.stability,
    required this.message,
    required this.guidanceRects,
  });

  final HandDistance handDistance;
  final FingerAlignment fingerAlignment;
  final StabilityStatus stability;
  final String message;
  final List<FpGuideRect> guidanceRects;
}

class FpGuideRect {
  const FpGuideRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.label,
    required this.status,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final String label;
  final String status;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
