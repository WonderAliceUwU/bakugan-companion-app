part of '../../main.dart';

// --- MODELOS DE DATOS ---
class BakuganVariant {
  final String attribute;
  final String modelPath;
  final Color color;
  final int gPower;
  final String speciesName;

  BakuganVariant({
    required this.attribute,
    required this.modelPath,
    required this.color,
    required this.gPower,
    required this.speciesName,
  });
}

class Bakugan {
  final String name;
  final List<BakuganVariant> variants;

  Bakugan({required this.name, required this.variants});
}

class PlayerData {
  final String name;
  final String character;
  final bool isSavedProfile;
  final List<BakuganVariant> deck = [];

  PlayerData({
    required this.name,
    required this.character,
    this.isSavedProfile = false,
  });

  int get totalGPower => deck.fold(0, (sum, item) => sum + item.gPower);
}

const int _defaultLeaderboardPoints = 1000;
const int _eloKFactor = 32;
const int _minimumLeaderboardDelta = 1;
const int _minimumRankedMatches = 5;
const int _currentSeasonNumber = 2;

String _sanitizePlayerName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

String _playerNameKey(String value) => _sanitizePlayerName(value).toLowerCase();

double _expectedScore(int playerPoints, int opponentPoints) {
  return 1 / (1 + pow(10, (opponentPoints - playerPoints) / 400));
}

Map<String, int> _roundPointDeltasPreservingTotal(
  Map<String, double> rawDeltas,
) {
  final rounded = <String, int>{};
  final residuals = <String, double>{};

  for (final entry in rawDeltas.entries) {
    final value = entry.value.round();
    rounded[entry.key] = value;
    residuals[entry.key] = entry.value - value;
  }

  int remainder = -rounded.values.fold(0, (sum, value) => sum + value);
  if (remainder == 0) return rounded;

  final keys = rawDeltas.keys.toList();
  keys.sort((a, b) {
    final residualCompare = remainder > 0
        ? residuals[b]!.compareTo(residuals[a]!)
        : residuals[a]!.compareTo(residuals[b]!);
    if (residualCompare != 0) return residualCompare;
    return a.compareTo(b);
  });

  int index = 0;
  while (remainder != 0 && keys.isNotEmpty) {
    final key = keys[index % keys.length];
    rounded[key] = (rounded[key] ?? 0) + (remainder > 0 ? 1 : -1);
    remainder += remainder > 0 ? -1 : 1;
    index++;
  }

  return rounded;
}

Map<String, int> _computeZeroSumMatchDeltas({
  required List<LeaderboardEntry> winnerEntries,
  required List<LeaderboardEntry> loserEntries,
}) {
  if (winnerEntries.isEmpty) return const {};
  if (loserEntries.isEmpty) {
    return {
      for (final winner in winnerEntries)
        _playerNameKey(winner.name): _minimumLeaderboardDelta,
    };
  }

  final rawDeltas = <String, double>{
    for (final winner in winnerEntries) _playerNameKey(winner.name): 0,
    for (final loser in loserEntries) _playerNameKey(loser.name): 0,
  };

  final pairKFactor =
      _eloKFactor / max(winnerEntries.length, loserEntries.length);

  for (final winner in winnerEntries) {
    final winnerKey = _playerNameKey(winner.name);
    for (final loser in loserEntries) {
      final loserKey = _playerNameKey(loser.name);
      final expectedWinner = _expectedScore(winner.points, loser.points);
      final pairDelta = pairKFactor * (1 - expectedWinner);
      rawDeltas[winnerKey] = (rawDeltas[winnerKey] ?? 0) + pairDelta;
      rawDeltas[loserKey] = (rawDeltas[loserKey] ?? 0) - pairDelta;
    }
  }

  final rounded = _roundPointDeltasPreservingTotal(rawDeltas);
  final capped = <String, int>{};

  for (final winner in winnerEntries) {
    final key = _playerNameKey(winner.name);
    capped[key] = max(0, rounded[key] ?? 0);
  }

  int totalLossesApplied = 0;
  for (final loser in loserEntries) {
    final key = _playerNameKey(loser.name);
    final plannedLoss = max(0, -(rounded[key] ?? 0));
    final appliedLoss = min(plannedLoss, loser.points);
    capped[key] = -appliedLoss;
    totalLossesApplied += appliedLoss;
  }

  final positiveKeys = [
    for (final winner in winnerEntries)
      if ((capped[_playerNameKey(winner.name)] ?? 0) > 0)
        _playerNameKey(winner.name),
  ];

  if (positiveKeys.isEmpty) return capped;

  final scaledPositiveRaw = <String, double>{};
  final totalPositivePlanned = positiveKeys.fold<int>(
    0,
    (sum, key) => sum + (capped[key] ?? 0),
  );

  if (totalPositivePlanned <= 0) return capped;

  for (final key in positiveKeys) {
    scaledPositiveRaw[key] =
        (capped[key] ?? 0) * totalLossesApplied / totalPositivePlanned;
  }

  final scaledPositive = _roundPointDeltasPreservingTotal(scaledPositiveRaw);
  for (final key in positiveKeys) {
    capped[key] = max(0, scaledPositive[key] ?? 0);
  }

  return capped;
}

Color _leaderboardRankColor(int index) {
  switch (index) {
    case 0:
      return Colors.amberAccent;
    case 1:
      return const Color(0xFFE8EDF2);
    case 2:
      return const Color(0xFFE1B089);
    default:
      return Colors.white70;
  }
}

class SavedPlayerProfile {
  final String name;
  final String character;

  const SavedPlayerProfile({required this.name, required this.character});

  factory SavedPlayerProfile.fromJson(Map<String, dynamic> json) {
    return SavedPlayerProfile(
      name: _sanitizePlayerName((json['name'] ?? '').toString()),
      character: (json['character'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'character': character};

  SavedPlayerProfile copyWith({String? name, String? character}) {
    return SavedPlayerProfile(
      name: name ?? this.name,
      character: character ?? this.character,
    );
  }
}

class LeaderboardEntry {
  final String name;
  final int wins;
  final int points;
  final int matches;
  final int gateCardsWon;

  const LeaderboardEntry({
    required this.name,
    required this.wins,
    required this.points,
    required this.matches,
    required this.gateCardsWon,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      name: _sanitizePlayerName((json['name'] ?? '').toString()),
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? _defaultLeaderboardPoints,
      matches: (json['matches'] as num?)?.toInt() ?? 0,
      gateCardsWon: (json['gateCardsWon'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'wins': wins,
    'points': points,
    'matches': matches,
    'gateCardsWon': gateCardsWon,
  };

  LeaderboardEntry copyWith({
    String? name,
    int? wins,
    int? points,
    int? matches,
    int? gateCardsWon,
  }) {
    return LeaderboardEntry(
      name: name ?? this.name,
      wins: wins ?? this.wins,
      points: points ?? this.points,
      matches: matches ?? this.matches,
      gateCardsWon: gateCardsWon ?? this.gateCardsWon,
    );
  }

  bool get isRanked => matches >= _minimumRankedMatches;

  int get matchesUntilRanked => max(0, _minimumRankedMatches - matches);

  double get winRate => matches == 0 ? 0 : wins / matches;
}

class LeaderboardData {
  final List<SavedPlayerProfile> savedPlayers;
  final List<LeaderboardEntry> players;
  final String? topPlayer;
  final String? updatedAt;

  const LeaderboardData({
    this.savedPlayers = const [],
    this.players = const [],
    this.topPlayer,
    this.updatedAt,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> json) {
    final rawSavedPlayers = json['savedPlayers'];
    final rawPlayers = json['players'];

    return LeaderboardData(
      savedPlayers: rawSavedPlayers is List
          ? rawSavedPlayers
                .whereType<Map>()
                .map(
                  (entry) => SavedPlayerProfile.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .where(
                  (entry) =>
                      entry.name.isNotEmpty && entry.character.isNotEmpty,
                )
                .toList()
          : const [],
      players: rawPlayers is List
          ? rawPlayers
                .whereType<Map>()
                .map(
                  (entry) => LeaderboardEntry.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .where((entry) => entry.name.isNotEmpty)
                .toList()
          : const [],
      topPlayer: (json['topPlayer'] ?? '').toString().trim().isEmpty
          ? null
          : _sanitizePlayerName(json['topPlayer'].toString()),
      updatedAt: (json['updatedAt'] ?? '').toString().trim().isEmpty
          ? null
          : json['updatedAt'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'savedPlayers': savedPlayers.map((entry) => entry.toJson()).toList(),
    'topPlayer': topPlayer,
    'updatedAt': updatedAt,
    'players': players.map((entry) => entry.toJson()).toList(),
  };

  LeaderboardData copyWith({
    List<SavedPlayerProfile>? savedPlayers,
    List<LeaderboardEntry>? players,
    String? topPlayer,
    String? updatedAt,
  }) {
    return LeaderboardData(
      savedPlayers: savedPlayers ?? this.savedPlayers,
      players: players ?? this.players,
      topPlayer: topPlayer ?? this.topPlayer,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LeaderboardSeason {
  final int seasonNumber;
  final String title;
  final LeaderboardData leaderboard;
  final String? finalizedAt;

  const LeaderboardSeason({
    required this.seasonNumber,
    required this.title,
    required this.leaderboard,
    this.finalizedAt,
  });

  factory LeaderboardSeason.fromJson(Map<String, dynamic> json) {
    return LeaderboardSeason(
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 1,
      title: (json['title'] ?? '').toString().trim().isEmpty
          ? 'Season ${(json['seasonNumber'] as num?)?.toInt() ?? 1}'
          : json['title'].toString().trim(),
      leaderboard: LeaderboardData.fromJson(
        Map<String, dynamic>.from((json['leaderboard'] as Map?) ?? const {}),
      ),
      finalizedAt: (json['finalizedAt'] ?? '').toString().trim().isEmpty
          ? null
          : json['finalizedAt'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'seasonNumber': seasonNumber,
    'title': title,
    'leaderboard': leaderboard.toJson(),
    'finalizedAt': finalizedAt,
  };

  LeaderboardSeason copyWith({
    int? seasonNumber,
    String? title,
    LeaderboardData? leaderboard,
    String? finalizedAt,
  }) {
    return LeaderboardSeason(
      seasonNumber: seasonNumber ?? this.seasonNumber,
      title: title ?? this.title,
      leaderboard: leaderboard ?? this.leaderboard,
      finalizedAt: finalizedAt ?? this.finalizedAt,
    );
  }
}

class LeaderboardStore {
  final int currentSeasonNumber;
  final LeaderboardData currentLeaderboard;
  final List<LeaderboardSeason> archivedSeasons;
  final List<MatchHistoryEntry> matchHistory;

  const LeaderboardStore({
    required this.currentSeasonNumber,
    required this.currentLeaderboard,
    this.archivedSeasons = const [],
    this.matchHistory = const [],
  });

  factory LeaderboardStore.fromJson(Map<String, dynamic> json) {
    final rawArchivedSeasons = json['archivedSeasons'];
    return LeaderboardStore(
      currentSeasonNumber:
          (json['currentSeasonNumber'] as num?)?.toInt() ??
          _currentSeasonNumber,
      currentLeaderboard: LeaderboardData.fromJson(
        Map<String, dynamic>.from(
          (json['currentLeaderboard'] as Map?) ?? const {},
        ),
      ),
      archivedSeasons: rawArchivedSeasons is List
          ? rawArchivedSeasons
                .whereType<Map>()
                .map(
                  (entry) => LeaderboardSeason.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList()
          : const [],
      matchHistory: json['matchHistory'] is List
          ? (json['matchHistory'] as List)
                .whereType<Map>()
                .map(
                  (entry) => MatchHistoryEntry.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'currentSeasonNumber': currentSeasonNumber,
    'currentLeaderboard': currentLeaderboard.toJson(),
    'archivedSeasons': archivedSeasons.map((entry) => entry.toJson()).toList(),
    'matchHistory': matchHistory.map((entry) => entry.toJson()).toList(),
  };

  LeaderboardStore copyWith({
    int? currentSeasonNumber,
    LeaderboardData? currentLeaderboard,
    List<LeaderboardSeason>? archivedSeasons,
    List<MatchHistoryEntry>? matchHistory,
  }) {
    return LeaderboardStore(
      currentSeasonNumber: currentSeasonNumber ?? this.currentSeasonNumber,
      currentLeaderboard: currentLeaderboard ?? this.currentLeaderboard,
      archivedSeasons: archivedSeasons ?? this.archivedSeasons,
      matchHistory: matchHistory ?? this.matchHistory,
    );
  }
}

class MatchHistoryPlayerEntry {
  final String name;
  final String character;
  final bool isSavedProfile;
  final bool isWinner;
  final int gateCardsWon;
  final List<MatchHistoryBakuganEntry> bakuganUsed;
  final List<String> abilitiesUsed;
  final List<MatchHistoryAbilitySlotEntry> abilitySlots;

  const MatchHistoryPlayerEntry({
    required this.name,
    required this.character,
    required this.isSavedProfile,
    required this.isWinner,
    required this.gateCardsWon,
    this.bakuganUsed = const [],
    this.abilitiesUsed = const [],
    this.abilitySlots = const [],
  });

  factory MatchHistoryPlayerEntry.fromJson(Map<String, dynamic> json) {
    List<String> parseList(String key) => json[key] is List
        ? (json[key] as List)
              .map((entry) => entry.toString())
              .where((entry) => entry.trim().isNotEmpty)
              .toList()
        : const [];

    return MatchHistoryPlayerEntry(
      name: _sanitizePlayerName((json['name'] ?? '').toString()),
      character: (json['character'] ?? '').toString(),
      isSavedProfile: json['isSavedProfile'] == true,
      isWinner: json['isWinner'] == true,
      gateCardsWon: (json['gateCardsWon'] as num?)?.toInt() ?? 0,
      bakuganUsed: json['bakuganUsed'] is List
          ? (json['bakuganUsed'] as List)
                .map((entry) {
                  if (entry is Map) {
                    return MatchHistoryBakuganEntry.fromJson(
                      Map<String, dynamic>.from(entry),
                    );
                  }
                  return MatchHistoryBakuganEntry.fromLegacyLabel(
                    entry.toString(),
                  );
                })
                .where((entry) => entry.speciesName.trim().isNotEmpty)
                .toList()
          : const [],
      abilitiesUsed: parseList('abilitiesUsed'),
      abilitySlots: json['abilitySlots'] is List
          ? (json['abilitySlots'] as List)
                .whereType<Map>()
                .map(
                  (entry) => MatchHistoryAbilitySlotEntry.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'character': character,
    'isSavedProfile': isSavedProfile,
    'isWinner': isWinner,
    'gateCardsWon': gateCardsWon,
    'bakuganUsed': bakuganUsed.map((entry) => entry.toJson()).toList(),
    'abilitiesUsed': abilitiesUsed,
    'abilitySlots': abilitySlots.map((entry) => entry.toJson()).toList(),
  };
}

class MatchBattleRecord {
  final int battleNumber;
  final String leftPlayerName;
  final String rightPlayerName;
  final MatchHistoryBattleSideEntry leftSide;
  final MatchHistoryBattleSideEntry rightSide;
  final String? winnerName;
  final MatchHistoryCardEntry? revealedGateCard;
  final List<MatchHistoryCardEntry> externalAbilitiesUsed;

  const MatchBattleRecord({
    required this.battleNumber,
    required this.leftPlayerName,
    required this.rightPlayerName,
    required this.leftSide,
    required this.rightSide,
    this.winnerName,
    this.revealedGateCard,
    this.externalAbilitiesUsed = const [],
  });

  factory MatchBattleRecord.fromJson(Map<String, dynamic> json) {
    return MatchBattleRecord(
      battleNumber: (json['battleNumber'] as num?)?.toInt() ?? 0,
      leftPlayerName: _sanitizePlayerName(
        (json['leftPlayerName'] ?? '').toString(),
      ),
      rightPlayerName: _sanitizePlayerName(
        (json['rightPlayerName'] ?? '').toString(),
      ),
      leftSide: json['leftSide'] is Map
          ? MatchHistoryBattleSideEntry.fromJson(
              Map<String, dynamic>.from(json['leftSide'] as Map),
            )
          : MatchHistoryBattleSideEntry.fromLegacy(
              bakuganName: (json['leftBakugan'] ?? '').toString(),
              abilitiesUsed: json['leftAbilitiesUsed'] is List
                  ? (json['leftAbilitiesUsed'] as List)
                        .map((entry) => entry.toString())
                        .where((entry) => entry.trim().isNotEmpty)
                        .toList()
                  : const [],
            ),
      rightSide: json['rightSide'] is Map
          ? MatchHistoryBattleSideEntry.fromJson(
              Map<String, dynamic>.from(json['rightSide'] as Map),
            )
          : MatchHistoryBattleSideEntry.fromLegacy(
              bakuganName: (json['rightBakugan'] ?? '').toString(),
              abilitiesUsed: json['rightAbilitiesUsed'] is List
                  ? (json['rightAbilitiesUsed'] as List)
                        .map((entry) => entry.toString())
                        .where((entry) => entry.trim().isNotEmpty)
                        .toList()
                  : const [],
            ),
      winnerName: (json['winnerName'] ?? '').toString().trim().isEmpty
          ? null
          : _sanitizePlayerName(json['winnerName'].toString()),
      revealedGateCard: json['revealedGateCard'] is Map
          ? MatchHistoryCardEntry.fromJson(
              Map<String, dynamic>.from(json['revealedGateCard'] as Map),
            )
          : (json['revealedGateCard'] ?? '').toString().trim().isEmpty
          ? null
          : MatchHistoryCardEntry(
              name: json['revealedGateCard'].toString(),
              imagePath: 'assets/images/cards/anverse.png',
            ),
      externalAbilitiesUsed: json['externalAbilitiesUsed'] is List
          ? (json['externalAbilitiesUsed'] as List)
                .map((entry) {
                  if (entry is Map) {
                    return MatchHistoryCardEntry.fromJson(
                      Map<String, dynamic>.from(entry),
                    );
                  }
                  return MatchHistoryCardEntry(
                    name: entry.toString(),
                    imagePath: 'assets/images/cards/anverse.png',
                  );
                })
                .where((entry) => entry.name.trim().isNotEmpty)
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'battleNumber': battleNumber,
    'leftPlayerName': leftPlayerName,
    'rightPlayerName': rightPlayerName,
    'leftSide': leftSide.toJson(),
    'rightSide': rightSide.toJson(),
    'winnerName': winnerName,
    'revealedGateCard': revealedGateCard?.toJson(),
    'externalAbilitiesUsed': externalAbilitiesUsed
        .map((entry) => entry.toJson())
        .toList(),
  };
}

class MatchHistoryBakuganEntry {
  final String speciesName;
  final String attribute;
  final int gPower;
  final String? modelPath;
  final String? imagePath;

  const MatchHistoryBakuganEntry({
    required this.speciesName,
    required this.attribute,
    required this.gPower,
    required this.modelPath,
    required this.imagePath,
  });

  factory MatchHistoryBakuganEntry.fromJson(Map<String, dynamic> json) {
    return MatchHistoryBakuganEntry(
      speciesName: (json['speciesName'] ?? '').toString(),
      attribute: (json['attribute'] ?? '').toString(),
      gPower: (json['gPower'] as num?)?.toInt() ?? 0,
      modelPath: json['modelPath']?.toString(),
      imagePath: json['imagePath']?.toString(),
    );
  }

  factory MatchHistoryBakuganEntry.fromLegacyLabel(String label) {
    final trimmed = label.trim();
    final regex = RegExp(r'^(.*?)\s*\(([A-Z]+)\s+(\d+)G\)$');
    final match = regex.firstMatch(trimmed);
    if (match == null) {
      return MatchHistoryBakuganEntry(
        speciesName: trimmed,
        attribute: '',
        gPower: 0,
        modelPath: null,
        imagePath: null,
      );
    }
    final speciesName = match.group(1)?.trim() ?? trimmed;
    final attribute = (match.group(2) ?? '').toLowerCase();
    return MatchHistoryBakuganEntry(
      speciesName: speciesName,
      attribute: attribute,
      gPower: int.tryParse(match.group(3) ?? '') ?? 0,
      modelPath: null,
      imagePath: null,
    );
  }

  Map<String, dynamic> toJson() => {
    'speciesName': speciesName,
    'attribute': attribute,
    'gPower': gPower,
    'modelPath': modelPath,
    'imagePath': imagePath,
  };
}

class MatchHistoryCardEntry {
  final String name;
  final String imagePath;

  const MatchHistoryCardEntry({required this.name, required this.imagePath});

  factory MatchHistoryCardEntry.fromJson(Map<String, dynamic> json) {
    return MatchHistoryCardEntry(
      name: (json['name'] ?? '').toString(),
      imagePath: (json['imagePath'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'imagePath': imagePath};
}

class MatchHistoryAbilitySlotEntry {
  final int slotIndex;
  final MatchHistoryCardEntry? card;

  const MatchHistoryAbilitySlotEntry({required this.slotIndex, this.card});

  factory MatchHistoryAbilitySlotEntry.fromJson(Map<String, dynamic> json) {
    return MatchHistoryAbilitySlotEntry(
      slotIndex: (json['slotIndex'] as num?)?.toInt() ?? 0,
      card: json['card'] is Map
          ? MatchHistoryCardEntry.fromJson(
              Map<String, dynamic>.from(json['card'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'slotIndex': slotIndex,
    'card': card?.toJson(),
  };
}

class MatchHistoryBattleSideEntry {
  final MatchHistoryBakuganEntry bakugan;
  final int finalGPower;
  final bool isWinner;
  final List<MatchHistoryCardEntry> abilitiesUsed;

  const MatchHistoryBattleSideEntry({
    required this.bakugan,
    required this.finalGPower,
    required this.isWinner,
    this.abilitiesUsed = const [],
  });

  factory MatchHistoryBattleSideEntry.fromJson(Map<String, dynamic> json) {
    return MatchHistoryBattleSideEntry(
      bakugan: json['bakugan'] is Map
          ? MatchHistoryBakuganEntry.fromJson(
              Map<String, dynamic>.from(json['bakugan'] as Map),
            )
          : MatchHistoryBakuganEntry.fromLegacyLabel(
              (json['bakuganName'] ?? '').toString(),
            ),
      finalGPower: (json['finalGPower'] as num?)?.toInt() ?? 0,
      isWinner: json['isWinner'] == true,
      abilitiesUsed: json['abilitiesUsed'] is List
          ? (json['abilitiesUsed'] as List)
                .map((entry) {
                  if (entry is Map) {
                    return MatchHistoryCardEntry.fromJson(
                      Map<String, dynamic>.from(entry),
                    );
                  }
                  return MatchHistoryCardEntry(
                    name: entry.toString(),
                    imagePath: 'assets/images/cards/anverse.png',
                  );
                })
                .where((entry) => entry.name.trim().isNotEmpty)
                .toList()
          : const [],
    );
  }

  factory MatchHistoryBattleSideEntry.fromLegacy({
    required String bakuganName,
    required List<String> abilitiesUsed,
  }) {
    return MatchHistoryBattleSideEntry(
      bakugan: MatchHistoryBakuganEntry.fromLegacyLabel(bakuganName),
      finalGPower: 0,
      isWinner: false,
      abilitiesUsed: abilitiesUsed
          .map(
            (entry) => MatchHistoryCardEntry(
              name: entry,
              imagePath: 'assets/images/cards/anverse.png',
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'bakugan': bakugan.toJson(),
    'finalGPower': finalGPower,
    'isWinner': isWinner,
    'abilitiesUsed': abilitiesUsed.map((entry) => entry.toJson()).toList(),
  };
}

String _historyBakuganSpeciesSlug(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String _historyBakuganImagePath({
  required String speciesName,
  required String attribute,
}) {
  final speciesSlug = _historyBakuganSpeciesSlug(speciesName);
  final attributeSlug = attribute.trim().toLowerCase();
  return 'assets/images/bakugan/$speciesSlug/${speciesSlug}_$attributeSlug.png';
}

class MatchHistoryEntry {
  final String id;
  final int seasonNumber;
  final bool isTeamBattle;
  final String playedAt;
  final List<String> winnerNames;
  final List<MatchHistoryPlayerEntry> players;
  final List<MatchBattleRecord> battles;

  const MatchHistoryEntry({
    required this.id,
    required this.seasonNumber,
    required this.isTeamBattle,
    required this.playedAt,
    required this.winnerNames,
    required this.players,
    this.battles = const [],
  });

  factory MatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MatchHistoryEntry(
      id: (json['id'] ?? '').toString(),
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 1,
      isTeamBattle: json['isTeamBattle'] == true,
      playedAt: (json['playedAt'] ?? '').toString(),
      winnerNames: json['winnerNames'] is List
          ? (json['winnerNames'] as List)
                .map((entry) => _sanitizePlayerName(entry.toString()))
                .where((entry) => entry.isNotEmpty)
                .toList()
          : const [],
      players: json['players'] is List
          ? (json['players'] as List)
                .whereType<Map>()
                .map(
                  (entry) => MatchHistoryPlayerEntry.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList()
          : const [],
      battles: json['battles'] is List
          ? (json['battles'] as List)
                .whereType<Map>()
                .map(
                  (entry) => MatchBattleRecord.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'seasonNumber': seasonNumber,
    'isTeamBattle': isTeamBattle,
    'playedAt': playedAt,
    'winnerNames': winnerNames,
    'players': players.map((entry) => entry.toJson()).toList(),
    'battles': battles.map((entry) => entry.toJson()).toList(),
  };
}

class LeaderboardRepository {
  LeaderboardRepository._();

  static final LeaderboardRepository instance = LeaderboardRepository._();

  Future<File> _dataFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/bakugan_leaderboard.json');
  }

  Future<String> suggestedBackupPath() async {
    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    await directory.create(recursive: true);
    final now = DateTime.now();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return '${directory.path}/bakugan_stadium_leaderboard_$timestamp.json';
  }

  Future<LeaderboardData> load() async {
    final store = await loadStore();
    return store.currentLeaderboard;
  }

  Future<LeaderboardStore> loadStore() async {
    try {
      final file = await _dataFile();
      if (!await file.exists()) {
        return _defaultStore();
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return _defaultStore();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return _defaultStore();
      }
      final data = Map<String, dynamic>.from(decoded);
      if (data.containsKey('currentLeaderboard')) {
        return _normalizeStore(LeaderboardStore.fromJson(data));
      }
      return _migrateLegacyStore(LeaderboardData.fromJson(data));
    } catch (_) {
      return _defaultStore();
    }
  }

  Future<String> exportToFile([String? rawPath]) async {
    final path = (rawPath ?? '').trim().isEmpty
        ? await suggestedBackupPath()
        : rawPath!.trim();
    final file = File(path);
    await file.parent.create(recursive: true);
    final store = await loadStore();
    final normalized = _normalizeStore(store);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(normalized.toJson()),
    );
    return file.path;
  }

  Future<LeaderboardData> importFromFile(String rawPath) async {
    final path = rawPath.trim();
    if (path.isEmpty) {
      throw const FileSystemException('Path is empty.');
    }

    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File not found.', path);
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      throw FileSystemException('File is empty.', path);
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid leaderboard file format.');
    }

    final mapped = Map<String, dynamic>.from(decoded);
    if (mapped.containsKey('currentLeaderboard')) {
      final store = await _persistStore(
        _normalizeStore(LeaderboardStore.fromJson(mapped)),
      );
      return store.currentLeaderboard;
    }
    final store = await _migrateLegacyStore(LeaderboardData.fromJson(mapped));
    return store.currentLeaderboard;
  }

  Future<LeaderboardData> savePlayerProfile({
    required String rawName,
    required String character,
  }) async {
    final name = _sanitizePlayerName(rawName);
    final store = await loadStore();
    final data = store.currentLeaderboard;
    if (name.isEmpty || character.trim().isEmpty) {
      return data;
    }

    final savedPlayers = List<SavedPlayerProfile>.from(data.savedPlayers);
    final savedIndex = savedPlayers.indexWhere(
      (entry) => _playerNameKey(entry.name) == _playerNameKey(name),
    );
    final profile = SavedPlayerProfile(name: name, character: character);
    if (savedIndex >= 0) {
      savedPlayers[savedIndex] = profile;
    } else {
      savedPlayers.add(profile);
    }

    final playersByKey = {
      for (final entry in data.players) _playerNameKey(entry.name): entry,
    };
    playersByKey.putIfAbsent(
      _playerNameKey(name),
      () => LeaderboardEntry(
        name: name,
        wins: 0,
        points: _defaultLeaderboardPoints,
        matches: 0,
        gateCardsWon: 0,
      ),
    );

    final updated = await _persistCurrentLeaderboard(
      store,
      LeaderboardData(
        savedPlayers: savedPlayers,
        players: playersByKey.values.toList(),
      ),
    );
    return updated.currentLeaderboard;
  }

  Future<LeaderboardData> deleteSavedPlayer(String rawName) async {
    final key = _playerNameKey(rawName);
    if (key.isEmpty) {
      return load();
    }

    final store = await loadStore();
    final data = store.currentLeaderboard;
    final savedPlayers = data.savedPlayers
        .where((entry) => _playerNameKey(entry.name) != key)
        .toList();
    final players = data.players
        .where((entry) => _playerNameKey(entry.name) != key)
        .toList();

    final updated = await _persistCurrentLeaderboard(
      store,
      LeaderboardData(savedPlayers: savedPlayers, players: players),
    );
    return updated.currentLeaderboard;
  }

  Future<LeaderboardData> recordMatch({
    required List<String> winners,
    required List<String> losers,
    Map<String, int> gateCardsWonByPlayer = const {},
  }) async {
    final winnerNames = winners
        .map(_sanitizePlayerName)
        .where((entry) => entry.isNotEmpty)
        .toList();
    final loserNames = losers
        .map(_sanitizePlayerName)
        .where((entry) => entry.isNotEmpty)
        .toList();

    if (winnerNames.isEmpty) {
      return load();
    }

    final store = await loadStore();
    final data = store.currentLeaderboard;
    final savedPlayers = List<SavedPlayerProfile>.from(data.savedPlayers);
    final playersByKey = {
      for (final entry in data.players) _playerNameKey(entry.name): entry,
    };
    final sanitizedGateCardsWonByPlayer = <String, int>{};
    gateCardsWonByPlayer.forEach((name, gateCardsWon) {
      final key = _playerNameKey(name);
      if (key.isEmpty) return;
      sanitizedGateCardsWonByPlayer[key] = max(0, gateCardsWon);
    });

    LeaderboardEntry? ensureEntry(String name) {
      final key = _playerNameKey(name);
      if (!savedPlayers.any((entry) => _playerNameKey(entry.name) == key)) {
        return null;
      }
      return playersByKey.putIfAbsent(
        key,
        () => LeaderboardEntry(
          name: name,
          wins: 0,
          points: _defaultLeaderboardPoints,
          matches: 0,
          gateCardsWon: 0,
        ),
      );
    }

    final winnerEntries = winnerNames
        .map(ensureEntry)
        .whereType<LeaderboardEntry>()
        .toList();
    final loserEntries = loserNames
        .map(ensureEntry)
        .whereType<LeaderboardEntry>()
        .toList();

    if (winnerEntries.isEmpty) {
      return data;
    }
    final pointDeltas = _computeZeroSumMatchDeltas(
      winnerEntries: winnerEntries,
      loserEntries: loserEntries,
    );

    for (final name in winnerNames) {
      final key = _playerNameKey(name);
      final current = playersByKey[key]!;
      final delta = pointDeltas[key] ?? 0;
      playersByKey[key] = current.copyWith(
        points: current.points + delta,
        wins: current.wins + 1,
        matches: current.matches + 1,
        gateCardsWon:
            current.gateCardsWon + (sanitizedGateCardsWonByPlayer[key] ?? 0),
      );
    }

    for (final name in loserNames) {
      final key = _playerNameKey(name);
      final current = playersByKey[key]!;
      final delta = -(pointDeltas[key] ?? 0);
      playersByKey[key] = current.copyWith(
        points: max(0, current.points - delta),
        matches: current.matches + 1,
        gateCardsWon:
            current.gateCardsWon + (sanitizedGateCardsWonByPlayer[key] ?? 0),
      );
    }

    final updated = await _persistCurrentLeaderboard(
      store,
      LeaderboardData(
        savedPlayers: savedPlayers,
        players: playersByKey.values.toList(),
      ),
    );
    return updated.currentLeaderboard;
  }

  Future<LeaderboardStore> recordMatchHistory(MatchHistoryEntry entry) async {
    final store = await loadStore();
    final updatedHistory = [entry, ...store.matchHistory];
    return _persistStore(store.copyWith(matchHistory: updatedHistory));
  }

  LeaderboardStore _defaultStore() {
    return LeaderboardStore(
      currentSeasonNumber: _currentSeasonNumber,
      currentLeaderboard: _freshSeasonLeaderboard(const []),
      matchHistory: const [],
    );
  }

  Future<LeaderboardStore> _persistCurrentLeaderboard(
    LeaderboardStore store,
    LeaderboardData data,
  ) {
    return _persistStore(store.copyWith(currentLeaderboard: data));
  }

  Future<LeaderboardStore> _persistStore(LeaderboardStore store) async {
    final normalized = _normalizeStore(store);
    final file = await _dataFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(normalized.toJson()),
    );
    return normalized;
  }

  Future<LeaderboardStore> _migrateLegacyStore(
    LeaderboardData legacyData,
  ) async {
    final normalizedLegacy = _normalizeData(
      legacyData,
      refreshUpdatedAt: false,
    );
    final archivedSeason = LeaderboardSeason(
      seasonNumber: 1,
      title: 'Season 1',
      leaderboard: normalizedLegacy,
      finalizedAt: DateTime.now().toIso8601String(),
    );
    final store = LeaderboardStore(
      currentSeasonNumber: _currentSeasonNumber,
      currentLeaderboard: _freshSeasonLeaderboard(
        normalizedLegacy.savedPlayers,
      ),
      archivedSeasons: [archivedSeason],
      matchHistory: const [],
    );
    return _persistStore(store);
  }

  LeaderboardStore _normalizeStore(LeaderboardStore store) {
    final archivedSeasons =
        store.archivedSeasons
            .map(
              (season) => season.copyWith(
                title: season.title.trim().isEmpty
                    ? 'Season ${season.seasonNumber}'
                    : season.title.trim(),
                leaderboard: _normalizeData(
                  season.leaderboard,
                  refreshUpdatedAt: false,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => b.seasonNumber.compareTo(a.seasonNumber));

    return LeaderboardStore(
      currentSeasonNumber: max(1, store.currentSeasonNumber),
      currentLeaderboard: _normalizeData(store.currentLeaderboard),
      archivedSeasons: archivedSeasons,
      matchHistory: List<MatchHistoryEntry>.from(store.matchHistory)
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt)),
    );
  }

  LeaderboardData _freshSeasonLeaderboard(
    List<SavedPlayerProfile> savedPlayers,
  ) {
    return _normalizeData(
      LeaderboardData(
        savedPlayers: savedPlayers,
        players: [
          for (final player in savedPlayers)
            LeaderboardEntry(
              name: player.name,
              wins: 0,
              points: _defaultLeaderboardPoints,
              matches: 0,
              gateCardsWon: 0,
            ),
        ],
      ),
    );
  }

  LeaderboardData _normalizeData(
    LeaderboardData data, {
    bool refreshUpdatedAt = true,
  }) {
    final savedPlayersByKey = <String, SavedPlayerProfile>{};
    for (final profile in data.savedPlayers) {
      final cleanedName = _sanitizePlayerName(profile.name);
      final cleanedCharacter = profile.character.trim();
      if (cleanedName.isEmpty || cleanedCharacter.isEmpty) continue;
      savedPlayersByKey.putIfAbsent(
        _playerNameKey(cleanedName),
        () => profile.copyWith(name: cleanedName, character: cleanedCharacter),
      );
    }

    final playersByKey = <String, LeaderboardEntry>{};
    for (final entry in data.players) {
      final cleanedName = _sanitizePlayerName(entry.name);
      if (cleanedName.isEmpty) continue;
      final key = _playerNameKey(cleanedName);
      playersByKey[key] = entry.copyWith(name: cleanedName);
    }

    final players = playersByKey.values.toList()
      ..sort((a, b) {
        if (a.isRanked != b.isRanked) {
          return a.isRanked ? -1 : 1;
        }
        if (!a.isRanked && !b.isRanked) {
          final matchesCompare = b.matches.compareTo(a.matches);
          if (matchesCompare != 0) return matchesCompare;
        }
        final pointsCompare = b.points.compareTo(a.points);
        if (pointsCompare != 0) return pointsCompare;
        final winsCompare = b.wins.compareTo(a.wins);
        if (winsCompare != 0) return winsCompare;
        final gateCardsCompare = b.gateCardsWon.compareTo(a.gateCardsWon);
        if (gateCardsCompare != 0) return gateCardsCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    String? topPlayer;
    for (final player in players) {
      if (player.isRanked) {
        topPlayer = player.name;
        break;
      }
    }

    return LeaderboardData(
      savedPlayers: savedPlayersByKey.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      players: players,
      topPlayer: topPlayer,
      updatedAt: refreshUpdatedAt
          ? DateTime.now().toIso8601String()
          : data.updatedAt,
    );
  }
}
