import 'package:flutter/material.dart';

import '../finger_detector.dart';
import '../scan_options.dart';

class FingerOverlayPainter extends CustomPainter {
  FingerOverlayPainter({
    required this.rings,
    required this.captureArea,
    required this.message,
    required this.ringMode,
  });

  final List<FingerRing> rings;
  final Rect captureArea;
  final String message;
  final RingMode ringMode;

  @override
  void paint(Canvas canvas, Size size) {
    _paintCaptureArea(canvas, size);
    for (final ring in rings) {
      _paintRing(canvas, size, ring);
    }
    _paintMessage(canvas, size);
  }

  void _paintCaptureArea(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      captureArea.left * size.width,
      captureArea.top * size.height,
      captureArea.right * size.width,
      captureArea.bottom * size.height,
    );
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      border,
    );
  }

  void _paintRing(Canvas canvas, Size size, FingerRing ring) {
    Offset c;
    if (ringMode == RingMode.static && ring.status != FingerRingStatus.captured) {
      final idx = rings.indexOf(ring);
      final slots = const [
        Offset(0.28, 0.42),
        Offset(0.42, 0.38),
        Offset(0.56, 0.38),
        Offset(0.70, 0.42),
      ];
      c = Offset(
        (idx < slots.length ? slots[idx] : slots.last).dx * size.width,
        (idx < slots.length ? slots[idx] : slots.last).dy * size.height,
      );
    } else {
      c = Offset(ring.center.dx * size.width, ring.center.dy * size.height);
    }
    final r = ring.radius * size.width;
    final color = switch (ring.status) {
      FingerRingStatus.waiting => Colors.white54,
      FingerRingStatus.detecting => Colors.orangeAccent,
      FingerRingStatus.ready => Colors.lightGreenAccent,
      FingerRingStatus.capturing => Colors.greenAccent,
      FingerRingStatus.captured => Colors.green,
      FingerRingStatus.error => Colors.redAccent,
    };

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(
        alpha: ring.status == FingerRingStatus.captured ? 0.35 : 0.12,
      );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring.status == FingerRingStatus.capturing ? 4 : 2.5
      ..color = color;

    final oval = Rect.fromCenter(center: c, width: r * 1.35, height: r * 1.9);
    canvas.drawOval(oval, fill);
    canvas.drawOval(oval, stroke);

    if (ring.status == FingerRingStatus.captured) {
      final check = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(c.dx - r * 0.25, c.dy),
        Offset(c.dx - r * 0.05, c.dy + r * 0.25),
        check,
      );
      canvas.drawLine(
        Offset(c.dx - r * 0.05, c.dy + r * 0.25),
        Offset(c.dx + r * 0.35, c.dy - r * 0.25),
        check,
      );
    }

    final tp = TextPainter(
      text: TextSpan(
        text: ring.label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, oval.bottom + 4));
  }

  void _paintMessage(Canvas canvas, Size size) {
    if (message.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width * 0.9);
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, size.height * 0.82),
    );
  }

  @override
  bool shouldRepaint(covariant FingerOverlayPainter oldDelegate) =>
      oldDelegate.rings != rings ||
      oldDelegate.message != message ||
      oldDelegate.captureArea != captureArea ||
      oldDelegate.ringMode != ringMode;
}

class FingerGuideOverlay extends StatelessWidget {
  const FingerGuideOverlay({
    super.key,
    required this.guide,
    this.captureArea = const Rect.fromLTRB(0.08, 0.12, 0.92, 0.78),
    this.ringMode = RingMode.dynamic,
  });

  final FingerGuideResult? guide;
  final Rect captureArea;
  final RingMode ringMode;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FingerOverlayPainter(
        rings: guide?.rings ?? const [],
        captureArea: captureArea,
        message: guide?.message ?? 'Place hand in the frame',
        ringMode: ringMode,
      ),
      child: const SizedBox.expand(),
    );
  }
}
