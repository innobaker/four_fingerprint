import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hand_detection/hand_detection.dart';
import 'package:image/image.dart' as img;

import 'finger_detector.dart';

/// MediaPipe-style 21-landmark hand tracker (Android / iOS / desktop).
///
/// Uses on-device TFLite MediaPipe hand models via [hand_detection].
/// Android CameraX / iOS AVFoundation frames are fed through Flutter `camera`.
class MediaPipeHands {
  HandDetector? _detector;
  bool _busy = false;

  bool get isReady => _detector != null;

  Future<void> initialize() async {
    _detector ??= await HandDetector.create(
      mode: HandMode.boxesAndLandmarks,
      maxDetections: 1,
      enableTracking: true,
    );
  }

  Future<void> dispose() async {
    await _detector?.dispose();
    _detector = null;
  }

  /// Detect hand landmarks from a live [CameraImage] frame.
  Future<MediaPipeHandFrame?> detectCameraImage(CameraImage image) async {
    if (_detector == null || _busy) return null;
    _busy = true;
    try {
      final jpeg = await compute(_yuv420ToJpeg, _YuvPacket.from(image));
      if (jpeg == null) return null;
      return await detectJpeg(jpeg);
    } finally {
      _busy = false;
    }
  }

  Future<MediaPipeHandFrame?> detectJpeg(Uint8List jpegBytes) async {
    if (_detector == null) return null;
    final hands = await _detector!.detect(jpegBytes);
    if (hands.isEmpty) return null;
    final hand = hands.first;
    if (!hand.hasLandmarks) return null;

    final w = hand.imageWidth.toDouble().clamp(1, 100000);
    final h = hand.imageHeight.toDouble().clamp(1, 100000);
    final lm = Float32List(21 * 3);
    for (var i = 0; i < 21; i++) {
      final type = HandLandmarkType.values[i];
      final p = hand.getLandmark(type);
      if (p == null) continue;
      lm[i * 3] = (p.x / w).clamp(0.0, 1.0);
      lm[i * 3 + 1] = (p.y / h).clamp(0.0, 1.0);
      lm[i * 3 + 2] = p.z;
    }

    final handedness = switch (hand.handedness) {
      Handedness.left => HandednessHint.left,
      Handedness.right => HandednessHint.right,
      null => HandednessHint.unknown,
    };

    return MediaPipeHandFrame(
      landmarks: lm,
      handedness: handedness,
      score: hand.score,
    );
  }
}

class MediaPipeHandFrame {
  const MediaPipeHandFrame({
    required this.landmarks,
    required this.handedness,
    required this.score,
  });

  final Float32List landmarks;
  final HandednessHint handedness;
  final double score;
}

class _YuvPacket {
  _YuvPacket({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  factory _YuvPacket.from(CameraImage image) {
    final y = image.planes[0];
    final u = image.planes.length > 1 ? image.planes[1] : image.planes[0];
    final v = image.planes.length > 2 ? image.planes[2] : u;
    return _YuvPacket(
      width: image.width,
      height: image.height,
      y: Uint8List.fromList(y.bytes),
      u: Uint8List.fromList(u.bytes),
      v: Uint8List.fromList(v.bytes),
      yRowStride: y.bytesPerRow,
      uvRowStride: u.bytesPerRow,
      uvPixelStride: u.bytesPerPixel ?? 1,
    );
  }

  final int width;
  final int height;
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
}

Uint8List? _yuv420ToJpeg(_YuvPacket p) {
  try {
    final rgba = img.Image(width: p.width, height: p.height);
    for (var row = 0; row < p.height; row++) {
      for (var col = 0; col < p.width; col++) {
        final yIndex = row * p.yRowStride + col;
        final uvIndex =
            (row ~/ 2) * p.uvRowStride + (col ~/ 2) * p.uvPixelStride;
        final yp = p.y[yIndex];
        final up = p.u[uvIndex];
        final vp = p.v[uvIndex];
        final r = (yp + 1.370705 * (vp - 128)).round().clamp(0, 255);
        final g =
            (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128))
                .round()
                .clamp(0, 255);
        final b = (yp + 1.732446 * (up - 128)).round().clamp(0, 255);
        rgba.setPixelRgb(col, row, r, g, b);
      }
    }
    // Downscale for faster MediaPipe inference on device.
    final scaled = img.copyResize(rgba, width: 320);
    return Uint8List.fromList(img.encodeJpg(scaled, quality: 70));
  } catch (_) {
    return null;
  }
}

/// Convert CameraImage → packed RGB for native pipeline.
Uint8List cameraImageToRgb(CameraImage image) {
  if (image.planes.length == 1) {
    final plane = image.planes.first;
    final out = Uint8List(image.width * image.height * 3);
    for (var i = 0; i < image.width * image.height; i++) {
      final y = plane.bytes[i];
      out[i * 3] = y;
      out[i * 3 + 1] = y;
      out[i * 3 + 2] = y;
    }
    return out;
  }

  final y = image.planes[0];
  final u = image.planes[1];
  final v = image.planes[2];
  final out = Uint8List(image.width * image.height * 3);
  final uvPixelStride = u.bytesPerPixel ?? 1;
  for (var row = 0; row < image.height; row++) {
    for (var col = 0; col < image.width; col++) {
      final yi = row * y.bytesPerRow + col;
      final uvi = (row ~/ 2) * u.bytesPerRow + (col ~/ 2) * uvPixelStride;
      final yp = y.bytes[yi];
      final up = u.bytes[uvi];
      final vp = v.bytes[uvi];
      final r = (yp + 1.370705 * (vp - 128)).round().clamp(0, 255);
      final g =
          (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128)).round().clamp(0, 255);
      final b = (yp + 1.732446 * (up - 128)).round().clamp(0, 255);
      final o = (row * image.width + col) * 3;
      out[o] = r;
      out[o + 1] = g;
      out[o + 2] = b;
    }
  }
  // Front camera on Android often needs mirror for natural slap UX.
  if (!kIsWeb && Platform.isAndroid) {
    return out;
  }
  return out;
}
