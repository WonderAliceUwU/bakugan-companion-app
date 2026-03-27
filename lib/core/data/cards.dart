part of '../../main.dart';

class GateCardBonusBreakdown {
  final int baseBonus;
  final List<int> effectBonusSegments;

  const GateCardBonusBreakdown({
    required this.baseBonus,
    this.effectBonusSegments = const [],
  });

  int get totalBonus =>
      baseBonus + effectBonusSegments.fold(0, (sum, bonus) => sum + bonus);

  bool get hasBonusEffect => effectBonusSegments.isNotEmpty;

  List<int> get bonusSegments => [
    if (baseBonus > 0) baseBonus,
    ...effectBonusSegments.where((segment) => segment > 0),
  ];
}

class GateCard {
  final String key;
  final String name;
  final Map<String, int> attributes;
  final String imagePath;
  final String? descriptionEn;
  final String? descriptionEs;
  final String cardClass;
  final bool hasEffect;
  final List<dynamic> effects;

  const GateCard({
    required this.key,
    required this.name,
    required this.attributes,
    required this.imagePath,
    required this.descriptionEn,
    required this.descriptionEs,
    required this.cardClass,
    required this.hasEffect,
    this.effects = const [],
  });

  int bonusFor(String attribute) => attributes[attribute.toLowerCase()] ?? 0;

  GateCardBonusBreakdown bonusBreakdownFor(
    BakuganVariant variant, {
    int usedGateCardsInAllPiles = 0,
    int ownerUsedAbilityCards = 0,
    int ownerUsedGateCards = 0,
    int opponentUsedGateCards = 0,
    bool ownerHasAttributeBonusContext = true,
    Iterable<BakuganVariant> teamBakugans = const [],
  }) {
    final int baseBonus = bonusFor(variant.attribute);
    final List<int> effectBonusSegments = [];

    for (final effect in effects) {
      if (effect is Map && effect['type'] == 'named_bakugan_extra_gate_bonus') {
        final String? targetBakugan = effect['bakugan'];
        if (targetBakugan != null &&
            variant.speciesName.toLowerCase() == targetBakugan.toLowerCase()) {
          final dynamic extraApplicationsValue =
              effect['extra_attribute_bonus_applications'];
          if (extraApplicationsValue is num) {
            final int extraApplications = extraApplicationsValue.toInt();
            for (int i = 0; i < extraApplications; i++) {
              if (baseBonus > 0) {
                effectBonusSegments.add(baseBonus);
              }
            }
          }
        }
      }

      if (effect is Map &&
          effect['type'] == 'named_bakugan_bonus_per_used_gate') {
        final String? targetBakugan = effect['bakugan'];
        if (targetBakugan != null &&
            variant.speciesName.toLowerCase() == targetBakugan.toLowerCase()) {
          final dynamic valueRaw = effect['value'];
          if (valueRaw is num) {
            final int perUsedGateBonus = valueRaw.toInt();
            final int dynamicBonus = perUsedGateBonus * usedGateCardsInAllPiles;
            if (dynamicBonus > 0) {
              effectBonusSegments.add(dynamicBonus);
            }
          }
        }
      }

      if (effect is Map &&
          effect['type'] == 'gain_per_distinct_bakugan_attribute_in_team') {
        final dynamic valueRaw = effect['value'];
        final String target = (effect['target'] ?? '').toString().toLowerCase();
        if (valueRaw is num && target == 'each_bakugan') {
          final distinctAttributeCount = teamBakugans
              .map((bakugan) => bakugan.attribute.toLowerCase())
              .where((attribute) => attribute.isNotEmpty)
              .toSet()
              .length;
          final int dynamicBonus = valueRaw.toInt() * distinctAttributeCount;
          if (dynamicBonus > 0) {
            effectBonusSegments.add(dynamicBonus);
          }
        }
      }

      if (effect is Map && effect['type'] == 'fewest_used_gate_gets_bonus') {
        final String target = (effect['target'] ?? '').toString().toLowerCase();
        final dynamic valueRaw = effect['value'];
        if (target == 'owner_bakugan' &&
            valueRaw is num &&
            ownerUsedGateCards < opponentUsedGateCards) {
          final int dynamicBonus = valueRaw.toInt();
          if (dynamicBonus > 0) {
            effectBonusSegments.add(dynamicBonus);
          }
        }
      }

      if (effect is Map &&
          effect['type'] == 'gate_bonus_plus_per_used_ability') {
        final dynamic valueRaw = effect['value'];
        if (valueRaw is num && ownerUsedAbilityCards > 0) {
          final int dynamicBonus = valueRaw.toInt() * ownerUsedAbilityCards;
          if (dynamicBonus > 0) {
            effectBonusSegments.add(dynamicBonus);
          }
        }
      }
    }

    return GateCardBonusBreakdown(
      baseBonus: baseBonus,
      effectBonusSegments: effectBonusSegments,
    );
  }

  int calculateBonus(
    BakuganVariant variant, {
    int usedGateCardsInAllPiles = 0,
    int ownerUsedAbilityCards = 0,
    int ownerUsedGateCards = 0,
    int opponentUsedGateCards = 0,
    bool ownerHasAttributeBonusContext = true,
    Iterable<BakuganVariant> teamBakugans = const [],
  }) {
    return bonusBreakdownFor(
      variant,
      usedGateCardsInAllPiles: usedGateCardsInAllPiles,
      ownerUsedAbilityCards: ownerUsedAbilityCards,
      ownerUsedGateCards: ownerUsedGateCards,
      opponentUsedGateCards: opponentUsedGateCards,
      ownerHasAttributeBonusContext: ownerHasAttributeBonusContext,
      teamBakugans: teamBakugans,
    ).totalBonus;
  }

  bool get swapsPrintedGPower => effects.any(
    (effect) => effect is Map && effect['type'] == 'swap_printed_g_power',
  );

  bool get returnsAllUsedAbilityCards => effects.any(
    (effect) =>
        effect is Map && effect['type'] == 'return_all_used_ability_cards',
  );

  bool get requiresOwnerSelection => effects.any(
    (effect) =>
        effect is Map &&
        effect['type'] == 'lowest_lose_bonus_if_owner_has_attribute',
  );

  bool forbidsAbilityCards({
    required int leftPrintedGPower,
    required int rightPrintedGPower,
  }) {
    for (final effect in effects) {
      if (effect is! Map || effect['type'] != 'forbid_ability_cards') {
        continue;
      }

      final condition = effect['condition'];
      if (condition is! Map) {
        return true;
      }

      final dynamic thresholdRaw = condition['printed_g_power_difference_gte'];
      if (thresholdRaw is num &&
          (leftPrintedGPower - rightPrintedGPower).abs() >=
              thresholdRaw.toInt()) {
        return true;
      }
    }
    return false;
  }

  bool lowestTotalGPowerWins({
    required int leftPrintedGPower,
    required int rightPrintedGPower,
  }) {
    for (final effect in effects) {
      if (effect is! Map) continue;
      if (effect['type'] != 'lowest_total_g_power_wins_battle') {
        continue;
      }

      final condition = effect['condition'];
      if (condition is! Map) {
        return true;
      }

      final dynamic thresholdRaw = condition['printed_g_power_difference_gte'];
      if (thresholdRaw is num &&
          (leftPrintedGPower - rightPrintedGPower).abs() >=
              thresholdRaw.toInt()) {
        return true;
      }
    }
    return false;
  }
}

class AbilityCard {
  final String key;
  final String name;
  final Map<String, int> attributes;
  final String imagePath;
  final String? descriptionEn;
  final String? descriptionEs;
  final String cardClass;
  final Set<String> timings;
  final List<dynamic> effects;

  const AbilityCard({
    required this.key,
    required this.name,
    required this.attributes,
    required this.imagePath,
    required this.descriptionEn,
    required this.descriptionEs,
    required this.cardClass,
    required this.timings,
    this.effects = const [],
  });

  int bonusFor(String attribute) => attributes[attribute.toLowerCase()] ?? 0;

  int calculateBonus(BakuganVariant variant) {
    return bonusFor(variant.attribute);
  }

  int calculateBattleBonus(
    BakuganVariant variant, {
    required int ownPrintedGPower,
    required int opponentPrintedGPower,
  }) {
    int bonus = calculateBonus(variant);

    for (final effect in effects) {
      if (effect is! Map) continue;
      if (effect['type'] != 'highest_printed_g_power_gets_bonus') continue;
      if (ownPrintedGPower <= opponentPrintedGPower) continue;

      final valueRaw = effect['value'];
      if (valueRaw is num) {
        bonus += valueRaw.toInt();
      }
    }

    return bonus;
  }

  bool get setsAllPrintedGPowerToZero => effects.any(
    (effect) => effect is Map && effect['type'] == 'set_all_printed_g_power_to_zero',
  );

  bool get supportsBeforeBattle => timings.contains('start_of_battle');

  bool get supportsDuringBattle => timings.contains('during_battle');

  bool get isMatchStageCard => !supportsBeforeBattle && !supportsDuringBattle;
}

class MatchPresentedAbility {
  final AbilityCard card;
  final bool isActive;

  const MatchPresentedAbility({required this.card, this.isActive = true});

  MatchPresentedAbility copyWith({AbilityCard? card, bool? isActive}) {
    return MatchPresentedAbility(
      card: card ?? this.card,
      isActive: isActive ?? this.isActive,
    );
  }
}

const double _gateCardAspectRatio = 842 / 1130;
const double _gateCardHeight = 560;
const double _gateCardWidth = _gateCardHeight * _gateCardAspectRatio;
const Offset _battleBonusAnchor = Offset(-40, 0);
const Offset _battlePendingBonusOffset = Offset(0, -10);
const double _battleBonusRiseStart = 42;
const Map<String, List<Color>> _gateDescriptionBorderGradients = {
  'copper': [
    Color(0xFF6B432B),
    Color(0xFFAA7249),
    Color(0xFFDAB497),
    Color(0xFF8B5A39),
  ],
  'gold': [
    Color(0xFF6E5A2A),
    Color(0xFF9F8445),
    Color(0xFFDCC9A7),
    Color(0xFF7A6432),
  ],
  'silver': [
    Color(0xFF5C6168),
    Color(0xFF9EA0A0),
    Color(0xFFD9DDE2),
    Color(0xFF6C737C),
  ],
};

const Map<String, List<Color>> _abilityDescriptionBorderGradients = {
  'green': [
    Color(0xFF163D31),
    Color(0xFF2F8A6C),
    Color(0xFF2F8A6C),
    Color(0xFF0E241D),
  ],
  'blue': [
    Color(0xFF283440),
    Color(0xFF41505F),
    Color(0xFF6A7D91),
    Color(0xFF182028),
  ],
  'red': [
    Color(0xFF4A1714),
    Color(0xFF9F322D),
    Color(0xFFC15E58),
    Color(0xFF2C0E0D),
  ],
};

const Map<String, Color> _abilityDescriptionAccentColors = {
  'green': Color(0xFF5FD0A2),
  'blue': Color(0xFF8FA7BB),
  'red': Color(0xFFE07A73),
};

const Map<String, Color> _gateDescriptionAccentColors = {
  'copper': Color(0xFFE1B089),
  'gold': Color(0xFFF2DDAF),
  'silver': Color(0xFFE8EDF2),
};
const double _abilityPresentationCardScale = 0.84;
const double _abilityPresentationWidth = 500;
const double _abilityPresentationHeight = 660;
const double _abilityPresentationCardHeight =
    _gateCardHeight * _abilityPresentationCardScale;
const double _abilityPresentationGap = 44;

const double _matchAbilityRailSpacing = 6;

String _normalizeCardLookup(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

List<String> _cardLookupWords(String value) {
  return value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .where((word) => !{'the', 'your', 'of', 'and'}.contains(word))
      .toList();
}

Set<String> _cardLookupPatterns(String value) {
  final trimmed = value.trim().toLowerCase();
  final words = _cardLookupWords(trimmed);
  final patterns = <String>{};

  void addPattern(String candidate) {
    final normalized = candidate.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      patterns.add(normalized);
    }
  }

  addPattern(trimmed);
  addPattern(trimmed.replaceAll(' ', '_'));
  addPattern(trimmed.replaceAll(' ', '-'));
  addPattern(trimmed.replaceAll(RegExp(r'[\s_-]+'), ''));

  if (words.isNotEmpty) {
    addPattern(words.join('_'));
    addPattern(words.join('-'));
    addPattern(words.join());
    if (words.length > 1) {
      for (var i = 0; i < words.length - 1; i++) {
        addPattern('${words[i]}_${words[i + 1]}');
        addPattern('${words[i]}-${words[i + 1]}');
        addPattern('${words[i]}${words[i + 1]}');
      }
    }
  }

  for (final prefix in ['the ', 'the_', 'the-']) {
    if (trimmed.startsWith(prefix)) {
      final withoutPrefix = trimmed.substring(prefix.length);
      addPattern(withoutPrefix);
      addPattern(withoutPrefix.replaceAll(' ', '_'));
      addPattern(withoutPrefix.replaceAll(' ', '-'));
      addPattern(withoutPrefix.replaceAll(RegExp(r'[\s_-]+'), ''));
    }
  }

  return patterns;
}

String? _matchCardImagePath({
  required String cardKey,
  required String cardName,
  required List<String> assetPaths,
  String? fileName,
}) {
  if (fileName != null) {
    final directMatch = assetPaths.firstWhere(
      (path) => path.toLowerCase().endsWith(fileName.toLowerCase()),
      orElse: () => '',
    );
    if (directMatch.isNotEmpty) {
      return directMatch;
    }
  }
  final lookupPatterns = {
    ..._cardLookupPatterns(cardKey),
    ..._cardLookupPatterns(cardName),
  };
  final lookupWords = {
    ..._cardLookupWords(cardKey),
    ..._cardLookupWords(cardName),
  };

  final ranked =
      assetPaths
          .map((path) {
            final fileName = path.split('/').last.toLowerCase();
            final normalizedFile = _normalizeCardLookup(fileName);

            int score = 0;
            for (final pattern in lookupPatterns) {
              if (fileName.contains(pattern)) score += 1000;
              if (normalizedFile.contains(_normalizeCardLookup(pattern))) {
                score += 400;
              }
            }
            if (lookupWords.isNotEmpty &&
                lookupWords.every(fileName.contains)) {
              score += 200;
            }

            return (path: path, score: score);
          })
          .where((entry) => entry.score > 0)
          .toList()
        ..sort((a, b) {
          final scoreCompare = b.score.compareTo(a.score);
          if (scoreCompare != 0) return scoreCompare;
          return a.path
              .split('/')
              .last
              .length
              .compareTo(b.path.split('/').last.length);
        });

  if (ranked.isNotEmpty) return ranked.first.path;
  return null;
}

List<Bakugan> availableBakugans = [];

Future<void> loadAvailableBakugans() async {
  if (availableBakugans.isNotEmpty) return;
  try {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
      rootBundle,
    );
    final bakuganAssetPaths = manifest
        .listAssets()
        .where(
          (String key) =>
              key.startsWith('assets/models/') &&
              (key.endsWith('.glb') ||
                  key.endsWith('.gltf') ||
                  key.endsWith('.png')),
        )
        .toList();

    Map<String, List<BakuganVariant>> grouped = {};

    for (var path in bakuganAssetPaths) {
      final String fileNameWithExtension = path.split('/').last;
      final int extensionIndex = fileNameWithExtension.lastIndexOf('.');
      final String fileName = extensionIndex >= 0
          ? fileNameWithExtension.substring(0, extensionIndex)
          : fileNameWithExtension;
      List<String> parts = fileName.split('_');

      // Allow filenames like `gorem_darkus_520g_banned` without breaking
      // species grouping or metadata parsing.
      if (parts.isNotEmpty && parts.last.toLowerCase() == 'banned') {
        parts.removeLast();
      }

      // Extract G-Power if present (e.g., "550g")
      int gPower = 0;
      if (parts.isNotEmpty && parts.last.endsWith('g')) {
        gPower =
            int.tryParse(parts.last.substring(0, parts.last.length - 1)) ?? 0;
        parts.removeLast(); // Remove the gPower part for further processing
      }

      if (parts.isEmpty) {
        continue;
      }

      String attribute = parts.last.toLowerCase();
      String speciesName = parts.length > 1
          ? parts
                .sublist(0, parts.length - 1)
                .map((word) => word[0].toUpperCase() + word.substring(1))
                .join(' ')
          : fileName[0].toUpperCase() + fileName.substring(1);

      Color color = Colors.red;
      if (attribute.contains('pyrus')) {
        color = Colors.red;
      } else if (attribute.contains('aquos')) {
        color = Colors.blue;
      } else if (attribute.contains('subterra')) {
        color = Colors.brown;
      } else if (attribute.contains('haos')) {
        color = Colors.limeAccent;
      } else if (attribute.contains('darkus')) {
        color = Colors.deepPurple;
      } else if (attribute.contains('ventus')) {
        color = Colors.teal;
      }
      grouped
          .putIfAbsent(speciesName, () => [])
          .add(
            BakuganVariant(
              attribute: attribute,
              modelPath: path,
              color: color,
              gPower: gPower,
              speciesName: speciesName,
            ),
          );
    }

    availableBakugans = grouped.entries
        .map((e) => Bakugan(name: e.key, variants: e.value))
        .toList();

    if (availableBakugans.isEmpty) {
      _loadFallback();
    }
  } catch (e) {
    debugPrint("Error loading models: $e");
    _loadFallback();
  }
}

Future<void> _loadFallback() async {
  availableBakugans = [
    Bakugan(
      name: 'Dragonoid',
      variants: [
        BakuganVariant(
          attribute: 'pyrus',
          modelPath: 'assets/models/dragonoid/dragonoid_pyrus_510g.glb',
          color: Colors.red,
          gPower: 550,
          speciesName: 'Dragonoid',
        ),
      ],
    ),
  ];
}
