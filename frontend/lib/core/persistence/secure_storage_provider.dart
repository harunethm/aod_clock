import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Interface so callers (and tests) depend on this, not the package type
/// directly — keeps `core/persistence` swappable and fakeable without a
/// real platform channel. Mirrors catan-game/infera's identical wrapper.
abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStorageImpl implements SecureStorage {
  const FlutterSecureStorageImpl(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return const FlutterSecureStorageImpl(FlutterSecureStorage());
});
