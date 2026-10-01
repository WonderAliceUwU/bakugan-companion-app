import 'dart:io';

import 'package:flutter/material.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test(
    'Bakugan inventory keeps active variants in the saved store JSON',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'bakugan_inventory_test_',
      );
      final originalPlatform = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      addTearDown(() async {
        PathProviderPlatform.instance = originalPlatform;
        await tempDir.delete(recursive: true);
      });

      final variant = BakuganVariant(
        speciesName: 'Dragonoid',
        attribute: 'pyrus',
        modelPath: 'assets/models/dragonoid/open.obj',
        closedModelPath: 'assets/models/dragonoid/closed.obj',
        texturePath: 'assets/models/dragonoid/pyrus.png',
        color: Colors.red,
        gPower: 600,
      );

      await LeaderboardRepository.instance.saveBakuganInventory([variant]);
      final store = await LeaderboardRepository.instance.loadStore();
      final json = store.toJson();

      expect(store.bakuganInventory.isConfigured, isTrue);
      expect(store.bakuganInventory.bakugans, hasLength(1));
      expect(store.bakuganInventory.bakugans.single.speciesName, 'Dragonoid');
      expect(store.bakuganInventory.bakugans.single.attribute, 'pyrus');
      expect(store.bakuganInventory.bakugans.single.gPower, 600);
      expect(json['bakuganInventory']['configured'], isTrue);
      expect(json['bakuganInventory']['bakugans'], hasLength(1));
    },
  );

  test('Bakugan inventory stays opt-in for legacy saved games', () {
    final store = LeaderboardStore.fromJson({
      'currentLeaderboard': <String, dynamic>{},
      'currentSeasonNumber': 2,
      'archivedSeasons': <dynamic>[],
      'matchHistory': <dynamic>[],
    });

    expect(store.bakuganInventory.isConfigured, isFalse);
    expect(store.bakuganInventory.bakugans, isEmpty);
  });

  test('Bakugan catalog prefers dedicated model assets over illustrations', () async {
    availableBakugans = [];
    addTearDown(() => availableBakugans = []);

    await loadAvailableBakugans();

    expect(
      availableBakugans.any((bakugan) => bakugan.name.contains('WIPNaga')),
      isFalse,
    );

    final fencer = availableBakugans.firstWhere(
      (bakugan) => bakugan.name == 'Fencer',
    );
    expect(
      fencer.variants.map((variant) => variant.modelPath),
      contains(
        'assets/models/Season_2_New_Vestroia/Fencer/fencer_aquos_550g.png',
      ),
    );

    final nemus = availableBakugans.firstWhere(
      (bakugan) => bakugan.name == 'Nemus',
    );
    expect(
      nemus.variants.map((variant) => variant.modelPath),
      contains(
        'assets/models/Season_2_New_Vestroia/Nemus/nemus_pyrus_690g.glb',
      ),
    );

    final delta = availableBakugans.firstWhere(
      (bakugan) => bakugan.name == 'Delta Dragonoid',
    );
    final deltaPyrus = delta.variants.firstWhere(
      (variant) => variant.attribute == 'pyrus',
    );
    expect(
      deltaPyrus.modelPath,
      'assets/models/Season_1_Battle_Brawlers/Delta_Dragonoid/Delta Dragonoid Open.obj',
    );
    expect(
      deltaPyrus.closedModelPath,
      'assets/models/Season_1_Battle_Brawlers/Delta_Dragonoid/Delta Dragonoid Closed.obj',
    );

    final silentNaga = availableBakugans.firstWhere(
      (bakugan) => bakugan.name == 'Silent Naga',
    );
    expect(
      silentNaga.variants.map((variant) => variant.modelPath),
      contains(
        'assets/models/Season_1_Battle_Brawlers/Silent_Naga/Silent Naga Open.obj',
      ),
    );
    expect(
      silentNaga.variants.map((variant) => variant.texturePath),
      contains(
        'assets/models/Season_1_Battle_Brawlers/Silent_Naga/Textures/Cores/Pyrus Silent Naga.png',
      ),
    );
  });

  test(
    'Leaderboard points loss scales down with loser gate cards won',
    () async {
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
        gateCardsWonByPlayer: const {'Winner': 3, 'Loser0': 0},
      );
      await repo.recordMatch(
        winners: const ['Winner'],
        losers: const ['Loser1'],
        gateCardsWonByPlayer: const {'Winner': 3, 'Loser1': 1},
      );
      await repo.recordMatch(
        winners: const ['Winner'],
        losers: const ['Loser2'],
        gateCardsWonByPlayer: const {'Winner': 3, 'Loser2': 2},
      );

      final store = await repo.loadStore();
      final players = {
        for (final player in store.currentLeaderboard.players)
          player.name: player,
      };

      expect(players['Winner']!.points, 1036);
      expect(players['Winner']!.wins, 3);
      expect(players['Loser0']!.points, 984);
      expect(players['Loser1']!.points, 988);
      expect(players['Loser2']!.points, 992);
    },
  );
}
