library;

export 'src/fp_capture_controller.dart';
export 'src/fp_constants.dart';
export 'src/fp_models.dart';
export 'src/fp_native.dart';
export 'src/fp_storage.dart';

import 'src/fp_native.dart';

/// Plugin entry point.
class FourFingerprint {
  FourFingerprint._();

  static final FourFingerprint instance = FourFingerprint._();

  /// Native library version string.
  String get version => FpNativeBridge.instance.version;

  /// Initialize native processing (NFIQ2, etc.).
  Future<void> initialize({String? nfiq2ModelDir}) =>
      FpNativeBridge.instance.initialize(nfiq2ModelDir: nfiq2ModelDir);
}
