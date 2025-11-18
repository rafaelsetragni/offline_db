import 'dart:math';

sealed class UuidUtil {
  static const String _pushChars =
      '-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz';
  static final _random = Random();

  static String generateLuid({DateTime? fixedNow, bool sectionZeroed = false}) {
    int now = (fixedNow ?? DateTime.now()).millisecondsSinceEpoch;

    String timestampChars = '';
    // 8 characters for the timestamp from 48-bit time
    for (int i = 0; i < 8; i++) {
      final index = now % 64;
      timestampChars = _pushChars[index] + timestampChars;
      now = now ~/ 64;
    }

    String randomChars;
    if (sectionZeroed) {
      // 12 characters of the first char in the alphabet
      randomChars = _pushChars[0] * 12;
    } else {
      final randomBuilder = StringBuffer();
      // 12 random characters from 72-bits of randomness
      for (var i = 0; i < 12; i++) {
        randomBuilder.write(_pushChars[_random.nextInt(64)]);
      }
      randomChars = randomBuilder.toString();
    }

    return timestampChars + randomChars;
  }
}
