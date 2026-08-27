import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Password and PIN hashing.
///
/// Iterated HMAC-SHA256 with a per-account salt — enough that a PIN is not
/// stored in the clear and a leaked snapshot cannot be read at a glance.
///
/// It is **not** a substitute for server-side authentication: everything here
/// runs on the device, so anyone who can modify local storage can replace a
/// hash. Real deployment needs the accounts to live behind an API.
abstract class Credentials {
  static const int _iterations = 20000;
  static final Random _random = Random.secure();

  static String newSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String hash(String secret, String salt) {
    final key = utf8.encode(salt);
    var digest = Hmac(sha256, key).convert(utf8.encode(secret)).bytes;
    for (var i = 1; i < _iterations; i++) {
      digest = Hmac(sha256, key).convert(digest).bytes;
    }
    return base64Url.encode(digest);
  }

  /// Constant-time comparison, so a wrong PIN cannot be narrowed down by
  /// timing how long the check took.
  static bool verify(String secret, String salt, String expectedHash) {
    final actual = hash(secret, salt);
    if (actual.length != expectedHash.length) return false;
    var mismatch = 0;
    for (var i = 0; i < actual.length; i++) {
      mismatch |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return mismatch == 0;
  }
}
