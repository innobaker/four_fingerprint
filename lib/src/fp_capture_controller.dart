import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'finger_detector.dart';
import 'fp_constants.dart';
import 'fp_models.dart';
import 'fp_native.dart';
import 'fp_storage.dart';
import 'mediapipe_hands.dart';
import 'scan_options.dart';

class FpCaptureController extends ChangeNotifier {
  FpCaptureController({
    FpNativeBridge? bridge,
    FpSecureStorage? storage,
    FingerDetector? detector,
    MediaPipeHands? mediaPipe,
  })  : _bridge = bridge ?? FpNativeBridge.instance,
        _storage = storage ?? FpSecureStorage(),
        _detector = detector ?? FingerDetector(),
        _mediaPipe = mediaPipe ?? MediaPipeHands();

  final FpNativeBridge _bridge;
  final FpSecureStorage _storage;
  final FingerDetector _detector;
  final MediaPipeHands _mediaPipe;

  CaptureStep _step = CaptureStep.idle;
  bool _initialized = false;
  bool _processing = false;
  bool _capturing = false;
  String? _statusMessage;
  FingerGuideResult? _guide;
  SlapScanOptions? _options;
  List<CaptureStage> _stages = const [];
  int _stageIndex = 0;
  final List<FpFingerCapture> _capturedFingers = [];
  int _countdownRemaining = 0;
  bool _countdownActive = false;
  Timer? _countdownTimer;

  CaptureStep get step => _step;
  bool get isProcessing => _processing || _capturing;
  String? get statusMessage => _statusMessage;
  FingerGuideResult? get guide => _guide;
  FingerDetector get fingerDetector => _detector;
  CaptureProfile get profile =>
      _options?.effectiveProfile ?? CaptureProfile.fourFour;
  List<CaptureStage> get stages => List.unmodifiable(_stages);
  int get stageIndex => _stageIndex;
  CaptureStage? get currentStage =>
      (_stageIndex >= 0 && _stageIndex < _stages.length)
          ? _stages[_stageIndex]
          : null;
  List<FpFingerCapture> get capturedFingers =>
      List.unmodifiable(_capturedFingers);
  int get countdownRemaining => _countdownRemaining;
  bool get countdownActive => _countdownActive;

  List<FingerCode> get currentFingerCodes =>
      currentStage?.fingerCodes ?? const [];

  String get stepInstruction =>
      currentStage?.label ??
      (_step == CaptureStep.complete ? 'Done' : 'Ready to scan');

  Future<void> initialize() async {
    if (_initialized) return;
    await _bridge.initialize();
    await _mediaPipe.initialize();
    await _storage.initialize();
    _initialized = true;
    notifyListeners();
  }

  void startCapture({SlapScanOptions? options}) {
    _options = options ??
        const SlapScanOptions(
          subjectId: 'anonymous',
          storage: StorageMode.none,
          profile: CaptureProfile.fourFour,
        );
    _stages = _options!.stages;
    _stageIndex = 0;
    _capturedFingers.clear();
    _detector.clearCaptured();
    _detector.resetStability();
    _applyStage(0);
    _statusMessage = null;
    _guide = null;
    notifyListeners();
  }

  void reset() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownActive = false;
    _countdownRemaining = 0;
    _step = CaptureStep.idle;
    _stages = const [];
    _stageIndex = 0;
    _capturedFingers.clear();
    _detector.clearCaptured();
    _detector.resetStability();
    _statusMessage = null;
    _guide = null;
    _capturing = false;
    notifyListeners();
  }

  void _applyStage(int index) {
    _countdownTimer?.cancel();
    _countdownTimer = null;

    if (index < 0 || index >= _stages.length) {
      _step = CaptureStep.complete;
      _detector.expectedHand = null;
      _countdownActive = false;
      _countdownRemaining = 0;
      notifyListeners();
      return;
    }

    _stageIndex = index;
    final stage = _stages[index];
    _step = stage.id;
    _detector.expectedHand = switch (stage.expectedHand) {
      'left' => HandednessHint.left,
      'right' => HandednessHint.right,
      _ => null,
    };
    _detector.resetStability();

    int countdown = _options?.countdownSeconds ?? 3;
    if (countdown > 0) {
      _countdownActive = true;
      _countdownRemaining = countdown;
      notifyListeners();

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _countdownRemaining--;
        if (_countdownRemaining <= 0) {
          timer.cancel();
          _countdownTimer = null;
          _countdownActive = false;
        }
        notifyListeners();
      });
    } else {
      _countdownActive = false;
      _countdownRemaining = 0;
    }
    notifyListeners();
  }

  Future<bool> processFrame(CameraImage image) async {
    if (!_initialized || _processing || _capturing) return false;
    if (_step == CaptureStep.idle ||
        _step == CaptureStep.complete ||
        _step == CaptureStep.processing) {
      return false;
    }
    if (currentStage == null) return false;

    _processing = true;
    try {
      final mp = await _mediaPipe.detectCameraImage(image);
      final guide = _detector.evaluate(
        landmarks: mp?.landmarks,
        handedness: mp?.handedness ?? HandednessHint.unknown,
        fingerCodes: currentFingerCodes,
      );
      _guide = guide;
      _statusMessage = guide.message;
      notifyListeners();

      final auto = _options?.autoCapture ?? true;
      if (auto && guide.readyToCapture && !_countdownActive) {
        return await _captureNow(image, guide);
      }
      return false;
    } finally {
      _processing = false;
    }
  }

  Future<bool> _captureNow(CameraImage image, FingerGuideResult guide) async {
    if (_capturing) return false;
    _capturing = true;
    _statusMessage = 'Capturing fingerprints…';
    notifyListeners();

    try {
      final rgb = cameraImageToRgb(image);
      final landmarks = guide.landmarks;
      if (landmarks == null) return false;

      final live = await _bridge.checkLiveness(
        grayscale: _toGray(rgb),
        width: image.width,
        height: image.height,
        landmarks: landmarks,
      );
      if (live == LivenessResult.notLive.value) {
        _statusMessage = 'Liveness failed — use a real hand';
        _detector.resetStability();
        return false;
      }

      final result = await _bridge.processSlapFrame(
        rgbFrame: rgb,
        width: image.width,
        height: image.height,
        landmarks: landmarks,
        fingerCodes: currentFingerCodes,
      );

      if (!result.success || result.fingers.isEmpty) {
        _statusMessage = 'Extraction failed — try again';
        _detector.resetStability();
        return false;
      }

      for (final f in result.fingers) {
        _capturedFingers.add(f);
        _detector.markCaptured(f.fingerCode);
      }
      _advanceStage();
      return true;
    } on FpException catch (e) {
      _statusMessage = e.toString();
      _detector.resetStability();
      return false;
    } finally {
      _capturing = false;
      notifyListeners();
    }
  }

  void _advanceStage() {
    final next = _stageIndex + 1;
    if (next >= _stages.length) {
      _step = CaptureStep.complete;
      _statusMessage = 'Capture complete';
      return;
    }
    _applyStage(next);
    _statusMessage = currentStage?.label ?? 'Next…';
  }

  FpEnrollmentRecord? buildEnrollment(String subjectId) {
    if (_step != CaptureStep.complete || _capturedFingers.isEmpty) return null;
    return FpEnrollmentRecord(
      subjectId: subjectId,
      fingers: List.from(_capturedFingers),
      enrolledAt: DateTime.now(),
    );
  }

  Future<SlapScanResult> finish() async {
    final opts = _options ??
        const SlapScanOptions(
          subjectId: 'anonymous',
          storage: StorageMode.none,
        );
    final enrollment = buildEnrollment(opts.subjectId);
    if (enrollment == null) {
      return SlapScanResult(
        subjectId: opts.subjectId,
        mode: opts.mode,
        success: false,
        profile: opts.effectiveProfile,
        error: 'Capture incomplete',
      );
    }

    final templates = <String, Uint8List>{};
    for (final f in enrollment.fingers) {
      if (f.isoTemplate != null) {
        templates[f.fingerCode.name] = f.isoTemplate!;
      }
    }

    if (opts.storage == StorageMode.device || opts.storage == StorageMode.both) {
      await _storage.storeEnrollment(enrollment);
    }

    return SlapScanResult(
      subjectId: opts.subjectId,
      mode: opts.mode,
      success: true,
      profile: opts.effectiveProfile,
      enrollment: enrollment,
      isoTemplates: templates,
    );
  }

  Future<FpMatchResult?> authenticate({
    required String subjectId,
    required CameraImage image,
    FingerCode fingerCode = FingerCode.rightIndex,
  }) async {
    final enrollment = await _storage.loadEnrollment(subjectId);
    if (enrollment == null) return null;

    final mp = await _mediaPipe.detectCameraImage(image);
    if (mp == null) return null;

    final rgb = cameraImageToRgb(image);
    final result = await _bridge.processSlapFrame(
      rgbFrame: rgb,
      width: image.width,
      height: image.height,
      landmarks: mp.landmarks,
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

  Uint8List _toGray(Uint8List rgb) {
    final gray = Uint8List(rgb.length ~/ 3);
    for (var i = 0; i < gray.length; i++) {
      gray[i] =
          ((77 * rgb[i * 3] + 150 * rgb[i * 3 + 1] + 29 * rgb[i * 3 + 2]) >> 8);
    }
    return gray;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    unawaited(_mediaPipe.dispose());
    super.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
