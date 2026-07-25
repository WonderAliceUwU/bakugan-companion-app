import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:bakugan_companion/main.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);

  final String tempPath;

  @override
  Future<String?> getApplicationSupportPath() async => tempPath;
}

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

  test('Leaderboard points loss scales down with loser gate cards won', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'bakugan_companion_test_',
    );
    final originalPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    addTearDown(() async {
      PathProviderPlatform.instance = originalPlatform;
      await tempDir.delete(recursive: true);
    });

    final repo = LeaderboardRepository.instance;
    await repo.savePlayerProfile(rawName: 'Winner', character: 'dan');
    await repo.savePlayerProfile(rawName: 'Loser0', character: 'shun');
    await repo.savePlayerProfile(rawName: 'Loser1', character: 'runo');
    await repo.savePlayerProfile(rawName: 'Loser2', character: 'alice');

    await repo.recordMatch(
      winners: const ['Winner'],
      losers: const ['Loser0'],
      gateCardsWonByPlayer: const {
        'Winner': 3,
        'Loser0': 0,
      },
    );
    await repo.recordMatch(
      winners: const ['Winner'],
      losers: const ['Loser1'],
      gateCardsWonByPlayer: const {
        'Winner': 3,
        'Loser1': 1,
      },
    );
    await repo.recordMatch(
      winners: const ['Winner'],
      losers: const ['Loser2'],
      gateCardsWonByPlayer: const {
        'Winner': 3,
        'Loser2': 2,
      },
    );

    final store = await repo.loadStore();
    final players = {
      for (final player in store.currentLeaderboard.players) player.name: player,
    };

    expect(players['Winner']!.points, 1036);
    expect(players['Winner']!.wins, 3);
    expect(players['Loser0']!.points, 984);
    expect(players['Loser1']!.points, 988);
    expect(players['Loser2']!.points, 992);
  });
}
