import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:four_fingerprint/four_fingerprint.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SlapCaptureApp());
}

class SlapCaptureApp extends StatelessWidget {
  const SlapCaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Four Fingerprint SLAP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SlapCaptureScreen(),
    );
  }
}

class SlapCaptureScreen extends StatefulWidget {
  const SlapCaptureScreen({super.key});

  @override
  State<SlapCaptureScreen> createState() => _SlapCaptureScreenState();
}

class _SlapCaptureScreenState extends State<SlapCaptureScreen> {
  final _controller = FpCaptureController();
  final _storage = FpSecureStorage();
  final _subjectController = TextEditingController(text: 'user_001');

  CameraController? _camera;
  bool _loading = true;
  String? _error;
  Timer? _frameTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await FourFingerprint.instance.initialize();
      await _controller.initialize();
      await _storage.initialize();

      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _camera = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _camera!.initialize();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startCapture() {
    _controller.startCapture();
    _startFrameProcessing();
  }

  void _startFrameProcessing() {
    _frameTimer?.cancel();
    _camera?.startImageStream((image) async {
      if (_controller.step == CaptureStep.complete ||
          _controller.step == CaptureStep.idle) {
        return;
      }
      await _controller.processFrame(image);
      if (mounted) setState(() {});
    });
  }

  Future<void> _saveEnrollment() async {
    final record = _controller.buildEnrollment(_subjectController.text.trim());
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete capture before saving')),
      );
      return;
    }
    await _storage.storeEnrollment(record);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrolled ${record.subjectId}')),
      );
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _camera?.dispose();
    _controller.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Error: $_error')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('SLAP Capture v${FourFingerprint.instance.version}'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _camera != null && _camera!.value.isInitialized
                ? CameraPreview(_camera!)
                : const Center(child: Text('Camera unavailable')),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StepIndicator(step: _controller.step),
                      const SizedBox(height: 12),
                      Text(
                        _controller.stepInstruction,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_controller.statusMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _controller.statusMessage!,
                          style: TextStyle(color: Colors.orange.shade800),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Fingers captured: ${_controller.capturedFingers.length}',
                      ),
                      const Spacer(),
                      TextField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _controller.step == CaptureStep.idle
                                  ? _startCapture
                                  : null,
                              child: const Text('Start 4-4-2 Capture'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _controller.step == CaptureStep.complete
                                  ? _saveEnrollment
                                  : null,
                              child: const Text('Save Enrollment'),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          _frameTimer?.cancel();
                          _camera?.stopImageStream();
                          _controller.reset();
                          setState(() {});
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final CaptureStep step;

  @override
  Widget build(BuildContext context) {
    const steps = [
      CaptureStep.leftSlap,
      CaptureStep.rightSlap,
      CaptureStep.thumbs,
      CaptureStep.complete,
    ];
    const labels = ['Left 4', 'Right 4', 'Thumbs', 'Done'];

    return Row(
      children: List.generate(steps.length, (i) {
        final active = steps[i].value <= step.value && step != CaptureStep.idle;
        final current = steps[i] == step;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: current
                  ? Theme.of(context).colorScheme.primary
                  : active
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              labels[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: current ? FontWeight.bold : FontWeight.normal,
                color: current ? Colors.white : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}
