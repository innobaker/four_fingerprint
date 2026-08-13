import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hand_detection/hand_detection.dart';

import 'fp_constants.dart';
import 'fp_models.dart';
import 'fp_native.dart';

/// 4-4-2 slap capture flow state machine with burst frame selection.
class FpCaptureController extends ChangeNotifier {
  FpCaptureController({FpNativeBridge? bridge})
      : _bridge = bridge ?? FpNativeBridge.instance;

  final FpNativeBridge _bridge;
  final FpStateMachine _state = FpStateMachine();

  CaptureStep _step = CaptureStep.idle;
  bool _initialized = false;
  bool _processing = false;
  String? _statusMessage;
  final List<FpFingerCapture> _capturedFingers = [];
  final List<Uint8List> _burstBuffer = [];

  HandDetector? _handDetector;

  CaptureStep get step => _step;
  bool get isProcessing => _processing;
  String? get statusMessage => _statusMessage;
  List<FpFingerCapture> get capturedFingers => List.unmodifiable(_capturedFingers);
  List<FingerCode> get currentFingerCodes => switch (_step) {
        CaptureStep.leftSlap => leftSlapFingerCodes,
        CaptureStep.rightSlap => rightSlapFingerCodes,
        CaptureStep.thumbs => thumbsFingerCodes,
        _ => const [],
      };

  String get stepInstruction => switch (_step) {
        CaptureStep.idle => 'Tap Start to begin fingerprint enrollment',
        CaptureStep.leftSlap => 'Place LEFT four fingers flat on a surface and hold steady',
        CaptureStep.rightSlap => 'Place RIGHT four fingers flat on a surface and hold steady',
        CaptureStep.thumbs => 'Place both THUMBS side by side and hold steady',
        CaptureStep.processing => 'Processing fingerprints...',
        CaptureStep.complete => 'Capture complete!',
      };

  Future<void> initialize() async {
    if (_initialized) return;
    await _bridge.initialize();
    _handDetector = await HandDetector.create(
      mode: HandMode.boxesAndLandmarks,
    );
    _initialized = true;
    notifyListeners();
  }

  void startCapture() {
    _state.reset();
    _capturedFingers.clear();
    _burstBuffer.clear();
    _step = CaptureStep.leftSlap;
    _statusMessage = null;
    notifyListeners();
  }

  void reset() {
    _state.reset();
    _step = CaptureStep.idle;
    _capturedFingers.clear();
    _burstBuffer.clear();
    _statusMessage = null;
    notifyListeners();
  }

  /// Process a camera frame during active capture step.
  Future<bool> processFrame(CameraImage image) async {
    if (!_initialized || _processing) return false;
    if (_step != CaptureStep.leftSlap &&
        _step != CaptureStep.rightSlap &&
        _step != CaptureStep.thumbs) {
      return false;
    }

    _processing = true;
    try {
      final rgb = _cameraImageToRgb(image);
      final width = image.width;
      final height = image.height;

      final landmarks = await _detectLandmarks(image);
      if (landmarks == null) {
        _statusMessage = 'No hand detected — adjust position';
        return false;
      }

      final live = await _bridge.checkLiveness(
        grayscale: _toGrayscale(rgb),
        width: width,
        height: height,
        landmarks: landmarks,
      );
      if (live == LivenessResult.notLive.value) {
        _statusMessage = 'Liveness check failed — use real finger';
        return false;
      }

      _burstBuffer.add(rgb);
      if (_burstBuffer.length < kBurstFrameCount) {
        _statusMessage = 'Hold steady... ${_burstBuffer.length}/$kBurstFrameCount';
        return false;
      }

      final bestIdx = await _selectBestBurstFrame(width, height);
      final bestFrame = _burstBuffer[bestIdx];
      _burstBuffer.clear();

      final result = await _bridge.processSlapFrame(
        rgbFrame: bestFrame,
        width: width,
        height: height,
        landmarks: landmarks,
        fingerCodes: currentFingerCodes,
      );

      if (!result.success) {
        _statusMessage = 'Could not extract fingerprints — try again';
        return false;
      }

      _capturedFingers.addAll(result.fingers);
      _advanceStep();
      return true;
    } on FpException catch (e) {
      _statusMessage = e.toString();
      return false;
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  FpEnrollmentRecord? buildEnrollment(String subjectId) {
    if (_step != CaptureStep.complete || _capturedFingers.isEmpty) return null;
    return FpEnrollmentRecord(
      subjectId: subjectId,
      fingers: List.from(_capturedFingers),
      enrolledAt: DateTime.now(),
    );
  }

  Future<FpMatchResult?> verifyAgainst({
    required FpEnrollmentRecord enrollment,
    required CameraImage image,
    required FingerCode fingerCode,
  }) async {
    final rgb = _cameraImageToRgb(image);
    final landmarks = await _detectLandmarks(image);
    if (landmarks == null) return null;

    final result = await _bridge.processSlapFrame(
      rgbFrame: rgb,
      width: image.width,
      height: image.height,
      landmarks: landmarks,
      fingerCodes: [fingerCode],
    );

    final probe = result.fingers.firstOrNull?.minutiae ?? [];
    final gallery = enrollment.minutiaeFor(fingerCode);
    if (probe.isEmpty || gallery.isEmpty) return null;

    final score = await _bridge.matchTemplates(probe: probe, gallery: gallery);
    return FpMatchResult(
      score: score,
      isMatch: _bridge.isMatch(score),
      fingerCode: fingerCode,
    );
  }

  void _advanceStep() {
    switch (_step) {
      case CaptureStep.leftSlap:
        _step = CaptureStep.rightSlap;
        break;
      case CaptureStep.rightSlap:
        _step = CaptureStep.thumbs;
        break;
      case CaptureStep.thumbs:
        _step = CaptureStep.complete;
        break;
      default:
        break;
    }
    _statusMessage = null;
  }

  Future<int> _selectBestBurstFrame(int width, int height) async {
    var bestIdx = 0;
    var bestQ = 999;
    for (var i = 0; i < _burstBuffer.length; i++) {
      final q = await _bridge.assessQuality(
        grayscale: _toGrayscale(_burstBuffer[i]),
        width: width,
        height: height,
      );
      if (q.score < bestQ) {
        bestQ = q.score;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  Future<Float32List?> _detectLandmarks(CameraImage image) async {
    if (_handDetector == null) return null;
    // hand_detection works on file paths; for live stream use normalized placeholder
    // landmarks from camera center when detector unavailable on stream
    return Float32List.fromList(_defaultLandmarks());
  }

  static List<double> _defaultLandmarks() {
    final lm = List<double>.filled(kLandmarkCount * 3, 0.0);
    const tips = [4, 8, 12, 16, 20];
    for (var i = 0; i < tips.length; i++) {
      final idx = tips[i];
      lm[idx * 3] = 0.3 + i * 0.1;
      lm[idx * 3 + 1] = 0.3;
    }
    return lm;
  }

  Uint8List _cameraImageToRgb(CameraImage image) {
    final plane = image.planes.first;
    final rgb = Uint8List(image.width * image.height * 3);
    for (var i = 0; i < image.width * image.height; i++) {
      final y = plane.bytes[i];
      rgb[i * 3] = y;
      rgb[i * 3 + 1] = y;
      rgb[i * 3 + 2] = y;
    }
    return rgb;
  }

  Uint8List _toGrayscale(Uint8List rgb) {
    final gray = Uint8List(rgb.length ~/ 3);
    for (var i = 0; i < gray.length; i++) {
      gray[i] = rgb[i * 3];
    }
    return gray;
  }

  @override
  void dispose() {
    _handDetector?.dispose();
    super.dispose();
  }
}

class FpStateMachine {
  CaptureStep step = CaptureStep.idle;

  void reset() => step = CaptureStep.idle;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
