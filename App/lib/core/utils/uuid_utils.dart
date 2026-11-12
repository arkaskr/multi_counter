import 'dart:math';

/// Pure-Dart UUID v4 generator backed by [Random.secure] for offline-first IDs.
class UuidUtils {
  UuidUtils._();

  static final Random _random = Random.secure();

  static String v4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(hex).toList(growable: false);
    return '${b.sublist(0, 4).join()}-'
        '${b.sublist(4, 6).join()}-'
        '${b.sublist(6, 8).join()}-'
        '${b.sublist(8, 10).join()}-'
        '${b.sublist(10, 16).join()}';
  }
}

