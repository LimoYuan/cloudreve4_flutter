/// Cloudreve obfuscated thumbnail URL decoder.
/// Ported from the Go reference implementation in the API documentation.
class TimeFlowDecoder {
  /// Decode an obfuscated time-flow string.
  /// Tries current time, then ±1000ms to account for clock drift.
  /// Returns null if all attempts fail.
  static String? decodeTimeFlowString(String str) {
    if (str.isEmpty) return null;

    final timeNow = DateTime.now().millisecondsSinceEpoch;

    for (final offset in [0, -1000, 1000]) {
      final result = _decodeTimeFlowStringTime(str, timeNow + offset);
      if (result != null) return result;
    }

    return null;
  }

  static String? _decodeTimeFlowStringTime(String str, int timeNowMillis) {
    if (str.isEmpty) return null;

    int timeNow = timeNowMillis ~/ 1000;
    final timeNowBackup = timeNow;

    final timeDigits = <int>[];
    if (timeNow == 0) {
      timeDigits.add(0);
    } else {
      int tempTime = timeNow;
      while (tempTime > 0) {
        timeDigits.add(tempTime % 10);
        tempTime = tempTime ~/ 10;
      }
    }

    final res = str.split('');
    var secret = str.split('');

    var add = secret.length % 2 == 0;
    var timeDigitIndex = (secret.length - 1) % timeDigits.length;
    final l = secret.length;

    for (int pos = 0; pos < l; pos++) {
      final targetIndex = l - 1 - pos;

      int newIndex = targetIndex;
      if (add) {
        newIndex += timeDigits[timeDigitIndex] * timeDigitIndex;
      } else {
        newIndex = 2 * timeDigitIndex * timeDigits[timeDigitIndex] - newIndex;
      }

      if (newIndex < 0) {
        newIndex = newIndex.abs();
      }

      newIndex = newIndex % secret.length;

      res[targetIndex] = secret[newIndex];

      // Swap secret[newIndex] with last element, then shrink
      final lastSecretIndex = secret.length - 1;
      final a = secret[lastSecretIndex];
      final b = secret[newIndex];
      secret[newIndex] = a;
      secret[lastSecretIndex] = b;
      secret = secret.sublist(0, lastSecretIndex);

      add = !add;
      timeDigitIndex--;
      if (timeDigitIndex < 0) {
        timeDigitIndex = timeDigits.length - 1;
      }
    }

    final resStr = res.join('');
    final pipeIndex = resStr.indexOf('|');
    if (pipeIndex < 0) return null;

    final timestampPart = resStr.substring(0, pipeIndex);
    if (timestampPart != timeNowBackup.toString()) return null;

    return resStr.substring(pipeIndex + 1);
  }
}
