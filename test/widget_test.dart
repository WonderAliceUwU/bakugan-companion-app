import 'package:flutter_test/flutter_test.dart';

import 'package:bakugan_companion/main.dart';

void main() {
  test('LeaderboardData reads saved player profiles and entries', () {
    final data = LeaderboardData.fromJson({
      'savedPlayers': [
        {'name': ' Dan ', 'character': 'dan'},
      ],
      'players': [
        {
          'name': 'Dan',
          'wins': 2,
          'points': 1032,
          'matches': 3,
          'gateCardsWon': 7,
        },
      ],
    });

    expect(data.savedPlayers, hasLength(1));
    expect(data.savedPlayers.first.name, 'Dan');
    expect(data.savedPlayers.first.character, 'dan');
    expect(data.players, hasLength(1));
    expect(data.players.first.wins, 2);
    expect(data.players.first.matches, 3);
    expect(data.players.first.gateCardsWon, 7);
    expect(data.players.first.isRanked, isFalse);
    expect(data.players.first.matchesUntilRanked, 2);
  });
}
