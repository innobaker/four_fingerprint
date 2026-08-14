import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../fp_capture_controller.dart';
import '../fp_constants.dart';
import '../scan_options.dart';
import 'finger_overlay.dart';

class SlapScanner extends StatefulWidget {
  const SlapScanner({
    super.key,
    required this.subjectId,
    this.mode = ScanMode.enroll,
    this.storage = StorageMode.device,
    this.profile = CaptureProfile.fourFour,
    this.singleFinger = FingerCode.rightIndex,
    @Deprecated('Use profile: CaptureProfile.fourFourTwo')
    this.includeThumbs = false,
    this.autoCapture = true,
    this.countdownSeconds = 3,
    this.ringMode = RingMode.dynamic,
    this.onResult,
    this.onStepChanged,
    this.showControls = true,
  });

  final String subjectId;
  final ScanMode mode;
  final StorageMode storage;
  final CaptureProfile profile;
  final FingerCode singleFinger;
  @Deprecated('Use profile: CaptureProfile.fourFourTwo')
  final bool includeThumbs;
  final bool autoCapture;
  final int countdownSeconds;
  final RingMode ringMode;
  final ValueChanged<SlapScanResult>? onResult;
  final ValueChanged<CaptureStep>? onStepChanged;
  final bool showControls;

  @override
  State<SlapScanner> createState() => _SlapScannerState();
}

class _SlapScannerState extends State<SlapScanner> {
  final _engine = FpCaptureController();
  CameraController? _camera;
  bool _loading = true;
  String? _error;
  bool _streaming = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await _engine.initialize();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No camera found';
        });
        return;
      }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _camera = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _camera!.initialize();
      _engine.addListener(_onEngine);
      setState(() => _loading = false);
      _start();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onEngine() {
    if (!mounted) return;
    setState(() {});
    widget.onStepChanged?.call(_engine.step);
    if (_engine.step == CaptureStep.complete && !_finishing) {
      _finish();
    }
  }

  Future<void> _start() async {
    _engine.startCapture(
      options: SlapScanOptions(
        subjectId: widget.subjectId,
        mode: widget.mode,
        storage: widget.storage,
        profile: widget.profile,
        singleFinger: widget.singleFinger,
        includeThumbs: widget.includeThumbs,
        autoCapture: widget.autoCapture,
        countdownSeconds: widget.countdownSeconds,
        ringMode: widget.ringMode,
      ),
    );
    await _ensureStream();
  }

  Future<void> _ensureStream() async {
    if (_streaming || _camera == null || !_camera!.value.isInitialized) return;
    _streaming = true;
    await _camera!.startImageStream((image) async {
      if (!_streaming) return;
      await _engine.processFrame(image);
    });
  }

  Future<void> _finish() async {
    _finishing = true;
    await _stopStream();
    final result = await _engine.finish();
    widget.onResult?.call(result);
  }

  Future<void> _stopStream() async {
    if (!_streaming) return;
    _streaming = false;
    try {
      await _camera?.stopImageStream();
    } catch (_) {}
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngine);
    _stopStream();
    _camera?.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }

    final guide = _engine.guide;
    final showCountdown = _engine.countdownActive && _engine.countdownRemaining > 0;

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_camera != null && _camera!.value.isInitialized)
                  CameraPreview(_camera!),
                FingerGuideOverlay(
                  guide: guide,
                  captureArea: _engine.fingerDetector.captureArea,
                  ringMode: widget.ringMode,
                ),
                if (showCountdown)
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_engine.countdownRemaining}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _StageChips(
                    stages: _engine.stages,
                    stageIndex: _engine.stageIndex,
                    complete: _engine.step == CaptureStep.complete,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.showControls) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  _engine.stepInstruction,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  guide?.message ?? _engine.statusMessage ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.teal.shade800),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await _stopStream();
                          _finishing = false;
                          _engine.reset();
                          await _start();
                        },
                        child: const Text('Restart'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _engine.step == CaptureStep.complete
                            ? () => _finish()
                            : null,
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StageChips extends StatelessWidget {
  const _StageChips({
    required this.stages,
    required this.stageIndex,
    required this.complete,
  });

  final List<CaptureStage> stages;
  final int stageIndex;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) return const SizedBox.shrink();
    final labels = stages.map((s) {
      if (s.isSingle) return s.fingerCodes.first.name;
      if (s.isThumbs) return 'Thumbs';
      if (s.expectedHand == 'left') return 'Left 4';
      if (s.expectedHand == 'right') return 'Right 4';
      return s.label;
    }).toList();

    return Row(
      children: List.generate(labels.length, (i) {
        final on = complete || i < stageIndex;
        final cur = !complete && i == stageIndex;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: cur
                  ? Colors.teal
                  : on
                      ? Colors.teal.shade200
                      : Colors.black45,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              labels[i],
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: cur ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        );
      }),
    );
  }
}

Future<SlapScanResult?> openSlapScanner(
  BuildContext context, {
  required String subjectId,
  ScanMode mode = ScanMode.enroll,
  StorageMode storage = StorageMode.device,
  CaptureProfile profile = CaptureProfile.fourFour,
  FingerCode singleFinger = FingerCode.rightIndex,
  @Deprecated('Use profile: CaptureProfile.fourFourTwo')
  bool includeThumbs = false,
  int countdownSeconds = 3,
  RingMode ringMode = RingMode.dynamic,
}) {
  return Navigator.of(context).push<SlapScanResult>(
    MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: const Text('Fingerprint scan')),
        body: SafeArea(
          child: SlapScanner(
            subjectId: subjectId,
            mode: mode,
            storage: storage,
            profile: profile,
            singleFinger: singleFinger,
            includeThumbs: includeThumbs,
            countdownSeconds: countdownSeconds,
            ringMode: ringMode,
            onResult: (r) => Navigator.of(ctx).pop(r),
          ),
        ),
      ),
    ),
  );
}
