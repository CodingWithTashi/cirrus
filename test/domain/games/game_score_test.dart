import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/games/games.dart';

void main() {
  test(
    'beats: zero never sets a best, the first real score does, ties do not',
    () {
      expect(GameScore.beats(0, null), isFalse);
      expect(GameScore.beats(1, null), isTrue);
      expect(GameScore.beats(40, 40), isFalse);
      expect(GameScore.beats(39, 40), isFalse);
      expect(GameScore.beats(41, 40), isTrue);
    },
  );
}
