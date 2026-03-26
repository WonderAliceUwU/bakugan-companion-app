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

String _sanitizePlayerName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

String _playerNameKey(String value) => _sanitizePlayerName(value).toLowerCase();

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

  const SavedPlayerProfile({
    required this.name,
    required this.character,
  });

  factory SavedPlayerProfile.fromJson(Map<String, dynamic> json) {
    return SavedPlayerProfile(
      name: _sanitizePlayerName((json['name'] ?? '').toString()),
      character: (json['character'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'character': character,
  };

  SavedPlayerProfile copyWith({
    String? name,
    String? character,
  }) {
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

  const LeaderboardEntry({
    required this.name,
    required this.wins,
    required this.points,
    required this.matches,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      name: _sanitizePlayerName((json['name'] ?? '').toString()),
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      points:
          (json['points'] as num?)?.toInt() ?? _defaultLeaderboardPoints,
      matches: (json['matches'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'wins': wins,
    'points': points,
    'matches': matches,
  };

  LeaderboardEntry copyWith({
    String? name,
    int? wins,
    int? points,
    int? matches,
  }) {
    return LeaderboardEntry(
      name: name ?? this.name,
      wins: wins ?? this.wins,
      points: points ?? this.points,
      matches: matches ?? this.matches,
    );
  }
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
                .map((entry) => SavedPlayerProfile.fromJson(
                      Map<String, dynamic>.from(entry),
                    ))
                .where(
                  (entry) => entry.name.isNotEmpty && entry.character.isNotEmpty,
                )
                .toList()
          : const [],
      players: rawPlayers is List
          ? rawPlayers
                .whereType<Map>()
                .map((entry) => LeaderboardEntry.fromJson(
                      Map<String, dynamic>.from(entry),
                    ))
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

class LeaderboardRepository {
  LeaderboardRepository._();

  static final LeaderboardRepository instance = LeaderboardRepository._();

  Future<File> _dataFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/bakugan_leaderboard.json');
  }

  Future<LeaderboardData> load() async {
    try {
      final file = await _dataFile();
      if (!await file.exists()) {
        return const LeaderboardData();
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const LeaderboardData();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const LeaderboardData();
      }
      return _normalizeData(
        LeaderboardData.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } catch (_) {
      return const LeaderboardData();
    }
  }

  Future<LeaderboardData> savePlayerProfile({
    required String rawName,
    required String character,
  }) async {
    final name = _sanitizePlayerName(rawName);
    final data = await load();
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
      ),
    );

    return _persist(
      LeaderboardData(
        savedPlayers: savedPlayers,
        players: playersByKey.values.toList(),
      ),
    );
  }

  Future<LeaderboardData> deleteSavedPlayer(String rawName) async {
    final key = _playerNameKey(rawName);
    if (key.isEmpty) {
      return load();
    }

    final data = await load();
    final savedPlayers = data.savedPlayers
        .where((entry) => _playerNameKey(entry.name) != key)
        .toList();
    final players = data.players
        .where((entry) => _playerNameKey(entry.name) != key)
        .toList();

    return _persist(
      LeaderboardData(
        savedPlayers: savedPlayers,
        players: players,
      ),
    );
  }

  Future<LeaderboardData> recordMatch({
    required List<String> winners,
    required List<String> losers,
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

    final data = await load();
    final savedPlayers = List<SavedPlayerProfile>.from(data.savedPlayers);
    final playersByKey = {
      for (final entry in data.players) _playerNameKey(entry.name): entry,
    };

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
    final delta = loserEntries.isEmpty
        ? _minimumLeaderboardDelta
        : max(
            _minimumLeaderboardDelta,
            (_eloKFactor *
                    (1 -
                        (1 /
                            (1 +
                                pow(
                                  10,
                                  ((loserEntries.fold<int>(
                                                0,
                                                (sum, entry) =>
                                                    sum + entry.points,
                                              ) /
                                              loserEntries.length) -
                                          (winnerEntries.fold<int>(
                                                0,
                                                (sum, entry) =>
                                                    sum + entry.points,
                                              ) /
                                              winnerEntries.length)) /
                                      400,
                                )))))
                .round(),
          );

    for (final name in winnerNames) {
      final key = _playerNameKey(name);
      final current = playersByKey[key]!;
      playersByKey[key] = current.copyWith(
        points: current.points + delta,
        wins: current.wins + 1,
        matches: current.matches + 1,
      );
    }

    for (final name in loserNames) {
      final key = _playerNameKey(name);
      final current = playersByKey[key]!;
      playersByKey[key] = current.copyWith(
        points: max(0, current.points - delta),
        matches: current.matches + 1,
      );
    }

    return _persist(
      LeaderboardData(
        savedPlayers: savedPlayers,
        players: playersByKey.values.toList(),
      ),
    );
  }

  Future<LeaderboardData> _persist(LeaderboardData data) async {
    final normalized = _normalizeData(data);
    final file = await _dataFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(normalized.toJson()),
    );
    return normalized;
  }

  LeaderboardData _normalizeData(LeaderboardData data) {
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
        final pointsCompare = b.points.compareTo(a.points);
        if (pointsCompare != 0) return pointsCompare;
        final winsCompare = b.wins.compareTo(a.wins);
        if (winsCompare != 0) return winsCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return LeaderboardData(
      savedPlayers: savedPlayersByKey.values.toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        ),
      players: players,
      topPlayer: players.isEmpty ? null : players.first.name,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }
}
