import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecretStoreException implements Exception {
  const SecretStoreException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Stockage des clés API.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Trousseau du système : Keystore Android, libsecret (GNOME Keyring /
/// KWallet) sous Linux.
class SecureSecretStore implements SecretStore {
  const SecureSecretStore();

  static const _storage = FlutterSecureStorage();

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw SecretStoreException(
        'Le trousseau sécurisé du système est indisponible ($error). '
        'Sous Linux, vérifiez qu’un service de trousseau (gnome-keyring ou KWallet) est actif.',
      );
    }
  }

  @override
  Future<String?> read(String key) => _guard(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _guard(() => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) => _guard(() => _storage.delete(key: key));
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
