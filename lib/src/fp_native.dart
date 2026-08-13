import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../four_fingerprint_bindings_generated.dart';
import 'fp_constants.dart';
import 'fp_models.dart';

final FourFingerprintBindings _bindings = () {
  const libName = 'four_fingerprint';
  final dylib = () {
    if (Platform.isMacOS || Platform.isIOS) {
      return ffi.DynamicLibrary.open('$libName.framework/$libName');
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return ffi.DynamicLibrary.open('lib$libName.so');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('$libName.dll');
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }();
  return FourFingerprintBindings(dylib);
}();

/// High-level native bridge for fingerprint processing.
class FpNativeBridge {
  FpNativeBridge._();
  static final FpNativeBridge instance = FpNativeBridge._();

  String get version {
    final ptr = _bindings.fp_get_version();
    return ptr.cast<Utf8>().toDartString();
  }

  Future<void> initialize({String? nfiq2ModelDir}) async {
    if (nfiq2ModelDir != null) {
      await _runNative(() {
        final dir = nfiq2ModelDir.toNativeUtf8();
        try {
          _check(_bindings.fp_init_nfiq2(dir.cast()));
        } finally {
          malloc.free(dir);
        }
      });
    } else {
      await _runNative(() => _check(_bindings.fp_init_nfiq2(ffi.nullptr)));
    }
  }

  Future<double> calibrateScale({
    required Uint8List rgbFrame,
    required int width,
    required int height,
    required Float32List landmarks,
    required List<FingerCode> fingerCodes,
  }) async {
    return _runNative(() {
      final rgb = _copyUint8(rgbFrame);
      final lm = _copyFloat32(landmarks);
      final codes = calloc<ffi.Int32>(fingerCodes.length);
      final outScale = calloc<ffi.Float>();
      try {
        for (var i = 0; i < fingerCodes.length; i++) {
          codes[i] = fingerCodes[i].code;
        }
        _check(_bindings.fp_calibrate_scale(
          rgb, width, height, lm, kLandmarkCount, codes, fingerCodes.length, outScale,
        ));
        return outScale.value;
      } finally {
        calloc.free(rgb);
        calloc.free(lm);
        calloc.free(codes);
        calloc.free(outScale);
      }
    });
  }

  Future<int> checkLiveness({
    required Uint8List grayscale,
    required int width,
    required int height,
    required Float32List landmarks,
  }) async {
    return _runNative(() {
      final gray = _copyUint8(grayscale);
      final lm = _copyFloat32(landmarks);
      final outLive = calloc<ffi.Int32>();
      try {
        _check(_bindings.fp_check_liveness(
          gray, width, height, lm, kLandmarkCount, outLive,
        ));
        return outLive.value;
      } finally {
        calloc.free(gray);
        calloc.free(lm);
        calloc.free(outLive);
      }
    });
  }

  Future<FpQuality> assessQuality({
    required Uint8List grayscale,
    required int width,
    required int height,
    int ppi = kTargetPpi,
    FingerCode fingerCode = FingerCode.unknown,
  }) async {
    return _runNative(() {
      final gray = _copyUint8(grayscale);
      final outQ = calloc<ffi.Int32>();
      try {
        _check(_bindings.fp_assess_quality(
          gray, width, height, ppi, fingerCode.code, outQ,
        ));
        return FpQuality.fromScore(outQ.value);
      } finally {
        calloc.free(gray);
        calloc.free(outQ);
      }
    });
  }

  Future<List<FpMinutiaPoint>> extractMinutiae({
    required Uint8List grayscale,
    required int width,
    required int height,
    int ppi = kTargetPpi,
    int maxMinutiae = 200,
  }) async {
    return _runNative(() {
      final gray = _copyUint8(grayscale);
      final out = calloc<FpMinutia>(maxMinutiae);
      final count = calloc<ffi.Int32>();
      try {
        _check(_bindings.fp_extract_minutiae(
          gray, width, height, ppi, out, maxMinutiae, count,
        ));
        return _readMinutiae(out, count.value);
      } finally {
        calloc.free(gray);
        calloc.free(out);
        calloc.free(count);
      }
    });
  }

  Future<int> matchTemplates({
    required List<FpMinutiaPoint> probe,
    required List<FpMinutiaPoint> gallery,
  }) async {
    return _runNative(() {
      final p = _writeMinutiae(probe);
      final g = _writeMinutiae(gallery);
      final score = calloc<ffi.Int32>();
      try {
        _check(_bindings.fp_match_templates(
          p, probe.length, g, gallery.length, score,
        ));
        return score.value;
      } finally {
        calloc.free(p);
        calloc.free(g);
        calloc.free(score);
      }
    });
  }

  bool isMatch(int score) => score >= kContactlessMatchThreshold;

  Future<Uint8List> exportIsoTemplate({
    required List<FpMinutiaPoint> minutiae,
    required FingerCode fingerPosition,
    int ppi = kTargetPpi,
  }) async {
    return _runNative(() {
      final mins = _writeMinutiae(minutiae);
      final buf = calloc<ffi.Uint8>(8192);
      final len = calloc<ffi.Int32>();
      try {
        _check(_bindings.fp_export_iso_template(
          mins, minutiae.length, fingerPosition.code, ppi, buf, 8192, len,
        ));
        return Uint8List.fromList(buf.asTypedList(len.value));
      } finally {
        calloc.free(mins);
        calloc.free(buf);
        calloc.free(len);
      }
    });
  }

  Future<FpSlapCaptureResult> processSlapFrame({
    required Uint8List rgbFrame,
    required int width,
    required int height,
    required Float32List landmarks,
    required List<FingerCode> fingerCodes,
  }) async {
    return _runNative(() {
      final rgb = _copyUint8(rgbFrame);
      final lm = _copyFloat32(landmarks);
      final codes = calloc<ffi.Int32>(fingerCodes.length);
      final result = calloc<FpSlapResult>();
      final minBuf = calloc<FpMinutia>(800);
      final imgBuf = calloc<ffi.Uint8>(512 * 512);
      try {
        for (var i = 0; i < fingerCodes.length; i++) {
          codes[i] = fingerCodes[i].code;
        }
        _check(_bindings.fp_process_slap_frame(
          rgb, width, height, lm, kLandmarkCount, codes,
          result, minBuf, 800, imgBuf, 512 * 512,
        ));

        final fingers = <FpFingerCapture>[];
        for (var i = 0; i < result.ref.num_fingers; i++) {
          final f = result.ref.fingers[i];
          fingers.add(FpFingerCapture(
            fingerCode: FingerCode.fromCode(f.finger_code),
            quality: FpQuality.fromScore(f.quality_score),
            minutiae: const [],
            isLive: LivenessResult.fromValue(f.is_live),
            resolutionPpi: f.resolution_ppi,
            scaleFactor: f.scale_factor,
          ));
        }

        return FpSlapCaptureResult(
          success: result.ref.success == 1,
          fingers: fingers,
          totalMinutiae: result.ref.total_minutiae,
        );
      } finally {
        calloc.free(rgb);
        calloc.free(lm);
        calloc.free(codes);
        _bindings.fp_free_slap_result(result);
        calloc.free(result);
        calloc.free(minBuf);
        calloc.free(imgBuf);
      }
    });
  }

  Future<Uint8List> encrypt(Uint8List data, Uint8List key) async {
    return _runNative(() {
      final d = _copyUint8(data);
      final k = _copyUint8(key);
      final out = calloc<ffi.Uint8>(data.length + 32);
      final outLen = calloc<ffi.Int32>();
      try {
        _check(_bindings.fp_encrypt_data(d, data.length, k, key.length, out, outLen));
        return Uint8List.fromList(out.asTypedList(outLen.value));
      } finally {
        calloc.free(d);
        calloc.free(k);
        calloc.free(out);
        calloc.free(outLen);
      }
    });
  }

  Future<Uint8List> decrypt(Uint8List data, Uint8List key) async {
    return _runNative(() {
      final d = _copyUint8(data);
      final k = _copyUint8(key);
      final out = calloc<ffi.Uint8>(data.length);
      final outLen = calloc<ffi.Int32>();
      try {
        _check(_bindings.fp_decrypt_data(d, data.length, k, key.length, out, outLen));
        return Uint8List.fromList(out.asTypedList(outLen.value));
      } finally {
        calloc.free(d);
        calloc.free(k);
        calloc.free(out);
        calloc.free(outLen);
      }
    });
  }

  Future<T> _runNative<T>(T Function() fn) async {
    return Isolate.run(fn);
  }

  static void _check(int code) {
    if (code != FpResult.ok) {
      throw FpException(code);
    }
  }

  static ffi.Pointer<ffi.Uint8> _copyUint8(Uint8List data) {
    final ptr = calloc<ffi.Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    return ptr;
  }

  static ffi.Pointer<ffi.Float> _copyFloat32(Float32List data) {
    final ptr = calloc<ffi.Float>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    return ptr;
  }

  static List<FpMinutiaPoint> _readMinutiae(ffi.Pointer<FpMinutia> ptr, int count) {
    return List.generate(count, (i) {
      final m = ptr[i];
      return FpMinutiaPoint(
        x: m.x,
        y: m.y,
        direction: m.direction,
        type: m.type == 0 ? MinutiaType.bifurcation : MinutiaType.ridgeEnding,
        reliability: m.reliability,
      );
    });
  }

  static ffi.Pointer<FpMinutia> _writeMinutiae(List<FpMinutiaPoint> points) {
    final ptr = calloc<FpMinutia>(points.length);
    for (var i = 0; i < points.length; i++) {
      ptr[i].x = points[i].x;
      ptr[i].y = points[i].y;
      ptr[i].direction = points[i].direction;
      ptr[i].type = points[i].type.value;
      ptr[i].reliability = points[i].reliability;
    }
    return ptr;
  }
}

class FpException implements Exception {
  FpException(this.code);
  final int code;

  @override
  String toString() => 'FpException: ${FpResult.message(code)}';
}