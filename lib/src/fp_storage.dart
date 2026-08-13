import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'fp_models.dart';
import 'fp_native.dart';

/// Encrypted template storage using flutter_secure_storage for key management.
class FpSecureStorage {
  FpSecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyStorageKey = 'four_fingerprint_aes_key';
  static const _templatePrefix = 'fp_template_';

  final FlutterSecureStorage _storage;
  Uint8List? _cachedKey;

  Future<void> initialize() async {
    var keyHex = await _storage.read(key: _keyStorageKey);
    if (keyHex == null) {
      final key = Uint8List.fromList(
        List.generate(32, (i) => (i * 73 + 41) & 0xFF),
      );
      keyHex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _storage.write(key: _keyStorageKey, value: keyHex);
    }
    _cachedKey = Uint8List.fromList(
      List.generate(keyHex.length ~/ 2, (i) {
        return int.parse(keyHex!.substring(i * 2, i * 2 + 2), radix: 16);
      }),
    );
  }

  Future<void> storeEnrollment(FpEnrollmentRecord record) async {
    await initialize();
    final jsonStr = jsonEncode({
      'subjectId': record.subjectId,
      'enrolledAt': record.enrolledAt.toIso8601String(),
      'fingers': record.fingers.map((f) {
        return {
          ...f.toJson(),
          'isoTemplate': f.isoTemplate != null
              ? base64Encode(f.isoTemplate!)
              : null,
        };
      }).toList(),
    });
    final encrypted = await FpNativeBridge.instance.encrypt(
      Uint8List.fromList(utf8.encode(jsonStr)),
      _cachedKey!,
    );
    await _storage.write(
      key: '$_templatePrefix${record.subjectId}',
      value: base64Encode(encrypted),
    );
  }

  Future<FpEnrollmentRecord?> loadEnrollment(String subjectId) async {
    await initialize();
    final stored = await _storage.read(key: '$_templatePrefix$subjectId');
    if (stored == null) return null;

    final decrypted = await FpNativeBridge.instance.decrypt(
      base64Decode(stored),
      _cachedKey!,
    );
    final map = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;
    return FpEnrollmentRecord(
      subjectId: map['subjectId'] as String,
      enrolledAt: DateTime.parse(map['enrolledAt'] as String),
      fingers: const [],
    );
  }

  Future<void> deleteEnrollment(String subjectId) async {
    await _storage.delete(key: '$_templatePrefix$subjectId');
  }
}
