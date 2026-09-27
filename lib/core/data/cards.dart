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

  bool _matchesNamedTargets(BakuganVariant variant, dynamic targetsRaw) {
    final targets = targetsRaw is List
        ? targetsRaw
        : targetsRaw == null
        ? const []
        : [targetsRaw];
    final normalizedSpecies = variant.speciesName.toLowerCase();
    return targets.any((target) {
      final normalizedTarget = target.toString().toLowerCase().trim();
      if (normalizedTarget.isEmpty) return false;
      return normalizedSpecies == normalizedTarget ||
          normalizedSpecies.contains(normalizedTarget);
    });
  }

  GateCardBonusBreakdown bonusBreakdownFor(
    BakuganVariant variant, {
    int usedGateCardsInAllPiles = 0,
    int ownerUsedAbilityCards = 0,
    int opponentUsedAbilityCards = 0,
    int ownerUsedGateCards = 0,
    int opponentUsedGateCards = 0,
    bool ownerHasAttributeBonusContext = true,
    Iterable<BakuganVariant> teamBakugans = const [],
    Iterable<BakuganVariant> ownerUsedBakugans = const [],
    Iterable<String> battleAttributes = const [],
    bool isLowestPrinted = false,
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

      if (effect is Map && effect['type'] == 'named_bakugan_bonus') {
        if (!_matchesNamedTargets(variant, effect['targets'])) {
          continue;
        }

        final condition = effect['condition'];
        if (condition is Map) {
          if (condition['lowest_printed'] == true && !isLowestPrinted) {
            continue;
          }
        }

        final scaling = effect['scaling'];
        if (scaling is Map) {
          final per = (scaling['per'] ?? '').toString().toLowerCase();
          if (per == 'base_gate_bonus') {
            final countRaw = scaling['count'];
            if (countRaw is num) {
              for (int i = 0; i < countRaw.toInt(); i++) {
                if (baseBonus > 0) {
                  effectBonusSegments.add(baseBonus);
                }
              }
            }
            continue;
          }
          final valueRaw = effect['value'];
          if (valueRaw is! num) continue;
          if (per == 'used_gate') {
            final dynamicBonus = valueRaw.toInt() * usedGateCardsInAllPiles;
            if (dynamicBonus > 0) {
              effectBonusSegments.add(dynamicBonus);
            }
            continue;
          }
          if (per == 'used_ability') {
            final scope = (scaling['scope'] ?? 'owner_used_pile')
                .toString()
                .toLowerCase();
            final abilityCount = switch (scope) {
              'all_used_piles' =>
                ownerUsedAbilityCards + opponentUsedAbilityCards,
              'opponent_used_pile' => opponentUsedAbilityCards,
              _ => ownerUsedAbilityCards,
            };
            final dynamicBonus = valueRaw.toInt() * abilityCount;
            if (dynamicBonus > 0) {
              effectBonusSegments.add(dynamicBonus);
            }
            continue;
          }
        }

        final valueRaw = effect['value'];
        if (valueRaw is num) {
          final int dynamicBonus = valueRaw.toInt();
          if (dynamicBonus > 0) {
            effectBonusSegments.add(dynamicBonus);
          }
        }
      }

      if (effect is Map && effect['type'] == 'flat_bonus') {
        final condition = effect['condition'];
        if (condition is Map) {
          if (condition['lowest_printed'] == true && !isLowestPrinted) {
            continue;
          }
          final minDistinctAttributes =
              condition['min_distinct_owner_attributes'];
          if (minDistinctAttributes is num) {
            final distinctAttributeCount = teamBakugans
                .map((bakugan) => bakugan.attribute.toLowerCase())
                .where((attribute) => attribute.isNotEmpty)
                .toSet()
                .length;
            if (distinctAttributeCount < minDistinctAttributes.toInt()) {
              continue;
            }
          }

          final ownerHasNamedInUsed =
              condition['owner_has_named_bakugan_in_used_pile'];
          if (ownerHasNamedInUsed is List) {
            final hasNamedUsed = ownerUsedBakugans.any(
              (bakugan) => _matchesNamedTargets(bakugan, ownerHasNamedInUsed),
            );
            if (!hasNamedUsed) {
              continue;
            }
          }
        }

        final target = (effect['target'] ?? '').toString().toLowerCase();
        if (target == 'each_bakugan' || target == 'matching_bakugan') {
          final scaling = effect['scaling'];
          if (scaling is Map) {
            final per = (scaling['per'] ?? '').toString().toLowerCase();
            if (per == 'opponent_used_ability') {
              final valueSource = (scaling['value_source'] ?? '')
                  .toString()
                  .toLowerCase();
              if (valueSource == 'base_gate_bonus') {
                for (int i = 0; i < opponentUsedAbilityCards; i++) {
                  if (baseBonus > 0) {
                    effectBonusSegments.add(baseBonus);
                  }
                }
                continue;
              }

              final valueRaw = effect['value'];
              if (valueRaw is num) {
                final dynamicBonus =
                    valueRaw.toInt() * opponentUsedAbilityCards;
                if (dynamicBonus > 0) {
                  effectBonusSegments.add(dynamicBonus);
                }
              }
              continue;
            }
          }

          final valueRaw = effect['value'];
          if (valueRaw is num) {
            final int dynamicBonus = valueRaw.toInt();
            if (dynamicBonus > 0) {
              effectBonusSegments.add(dynamicBonus);
            }
          }
        }
      }

      if (effect is Map && effect['type'] == 'attribute_bonus') {
        final condition = effect['condition'];
        if (condition is Map) {
          final requiredBattleAttributes =
              condition['battle_contains_any_attributes'];
          if (requiredBattleAttributes is List) {
            final battleAttributeSet = battleAttributes
                .map((attribute) => attribute.toLowerCase())
                .toSet();
            final hasRequired = requiredBattleAttributes.any(
              (attribute) => battleAttributeSet.contains(
                attribute.toString().toLowerCase(),
              ),
            );
            if (!hasRequired) {
              continue;
            }
          }
        }

        final targetAttributes = effect['target_attributes'];
        final valueRaw = effect['value'];
        if (targetAttributes is List &&
            valueRaw is num &&
            targetAttributes
                .map((attribute) => attribute.toString().toLowerCase())
                .contains(variant.attribute.toLowerCase())) {
          final int dynamicBonus = valueRaw.toInt();
          if (dynamicBonus > 0) {
            effectBonusSegments.add(dynamicBonus);
          }
        }
      }

      if (effect is Map &&
          effect['type'] == 'gain_per_opponent_used_gate_by_attribute') {
        final target = (effect['target'] ?? '').toString().toLowerCase();
        final attributes = effect['attributes'];
        final valueRaw = effect['value'];
        if ((target == 'matching_bakugan' || target == 'each_bakugan') &&
            attributes is List &&
            valueRaw is num &&
            attributes
                .map((attribute) => attribute.toString().toLowerCase())
                .contains(variant.attribute.toLowerCase())) {
          final dynamicBonus = valueRaw.toInt() * opponentUsedGateCards;
          if (dynamicBonus > 0) {
            effectBonusSegments.add(dynamicBonus);
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
    int opponentUsedAbilityCards = 0,
    int ownerUsedGateCards = 0,
    int opponentUsedGateCards = 0,
    bool ownerHasAttributeBonusContext = true,
    Iterable<BakuganVariant> teamBakugans = const [],
    Iterable<BakuganVariant> ownerUsedBakugans = const [],
    Iterable<String> battleAttributes = const [],
    bool isLowestPrinted = false,
  }) {
    return bonusBreakdownFor(
      variant,
      usedGateCardsInAllPiles: usedGateCardsInAllPiles,
      ownerUsedAbilityCards: ownerUsedAbilityCards,
      opponentUsedAbilityCards: opponentUsedAbilityCards,
      ownerUsedGateCards: ownerUsedGateCards,
      opponentUsedGateCards: opponentUsedGateCards,
      ownerHasAttributeBonusContext: ownerHasAttributeBonusContext,
      teamBakugans: teamBakugans,
      ownerUsedBakugans: ownerUsedBakugans,
      battleAttributes: battleAttributes,
      isLowestPrinted: isLowestPrinted,
    ).totalBonus;
  }

  bool get swapsPrintedGPower => effects.any(
    (effect) => effect is Map && effect['type'] == 'swap_printed_g_power',
  );

  bool get returnsAllUsedAbilityCards => effects.any(
    (effect) =>
        effect is Map && effect['type'] == 'return_all_used_ability_cards',
  );

  bool get hasUsedPileGlobalAttributeBonus => effects.any(
    (effect) =>
        effect is Map && effect['type'] == 'used_pile_global_attribute_bonus',
  );

  int usedPileGlobalAttributeBonusFor(String attribute) {
    int total = 0;
    final normalizedAttribute = attribute.toLowerCase();
    for (final effect in effects) {
      if (effect is! Map ||
          effect['type'] != 'used_pile_global_attribute_bonus') {
        continue;
      }
      final attributes = effect['attributes'];
      final valueRaw = effect['value'];
      if (attributes is! List || valueRaw is! num) continue;
      final matches = attributes.any(
        (entry) => entry.toString().toLowerCase() == normalizedAttribute,
      );
      if (matches) {
        total += valueRaw.toInt();
      }
    }
    return total;
  }

  bool get requiresOwnerSelection => effects.any(
    (effect) =>
        effect is Map &&
        effect['type'] == 'suppress_gate_bonus' &&
        effect['target'] == 'lowest_printed_bakugan',
  );

  ({bool left, bool right, Set<String> leftClasses, Set<String> rightClasses})
  abilityRestrictions({
    required int leftPrintedGPower,
    required int rightPrintedGPower,
    required int leftUsedGateCards,
    required int rightUsedGateCards,
    required BakuganVariant leftVariant,
    required BakuganVariant rightVariant,
    required Iterable<BakuganVariant> leftTeamBakugans,
    required Iterable<BakuganVariant> rightTeamBakugans,
  }) {
    bool forbidLeft = false;
    bool forbidRight = false;
    final leftClasses = <String>{};
    final rightClasses = <String>{};

    for (final effect in effects) {
      if (effect is! Map || effect['type'] != 'forbid_ability_cards') {
        continue;
      }

      final target = (effect['target'] ?? '').toString().toLowerCase();
      final classes =
          ((effect['classes'] as List?)
                      ?.map((entry) => entry.toString().toLowerCase())
                      .where((entry) => entry.isNotEmpty) ??
                  const Iterable<String>.empty())
              .toSet();

      void forbidBoth() {
        if (classes.isEmpty) {
          forbidLeft = true;
          forbidRight = true;
        } else {
          leftClasses.addAll(classes);
          rightClasses.addAll(classes);
        }
      }

      void forbidSingle(bool isLeft) {
        if (classes.isEmpty) {
          if (isLeft) {
            forbidLeft = true;
          } else {
            forbidRight = true;
          }
        } else if (isLeft) {
          leftClasses.addAll(classes);
        } else {
          rightClasses.addAll(classes);
        }
      }

      if (target == 'highest_printed_bakugan') {
        if (leftPrintedGPower > rightPrintedGPower) {
          forbidSingle(true);
        } else if (rightPrintedGPower > leftPrintedGPower) {
          forbidSingle(false);
        }
        continue;
      }
      if (target == 'lowest_printed_bakugan') {
        if (leftPrintedGPower < rightPrintedGPower) {
          forbidSingle(true);
        } else if (rightPrintedGPower < leftPrintedGPower) {
          forbidSingle(false);
        }
        continue;
      }
      if (target == 'most_used_gates_player') {
        if (leftUsedGateCards > rightUsedGateCards) {
          forbidSingle(true);
        } else if (rightUsedGateCards > leftUsedGateCards) {
          forbidSingle(false);
        }
        continue;
      }
      if (target == 'players_with_matching_attributes_in_battle') {
        if (leftVariant.attribute.toLowerCase() ==
            rightVariant.attribute.toLowerCase()) {
          forbidBoth();
        }
        continue;
      }
      if (target == 'players_with_duplicate_bakugan_types') {
        final leftSpecies = leftTeamBakugans
            .map((bakugan) => bakugan.speciesName.toLowerCase())
            .where((species) => species.isNotEmpty)
            .toList();
        final rightSpecies = rightTeamBakugans
            .map((bakugan) => bakugan.speciesName.toLowerCase())
            .where((species) => species.isNotEmpty)
            .toList();
        if (leftSpecies.toSet().length != leftSpecies.length) {
          forbidSingle(true);
        }
        if (rightSpecies.toSet().length != rightSpecies.length) {
          forbidSingle(false);
        }
        continue;
      }

      final condition = effect['condition'];
      if (condition is! Map) {
        forbidBoth();
        continue;
      }

      final dynamic thresholdRaw = condition['printed_g_power_difference_gte'];
      if (thresholdRaw is num &&
          (leftPrintedGPower - rightPrintedGPower).abs() >=
              thresholdRaw.toInt()) {
        forbidBoth();
      }
    }
    return (
      left: forbidLeft,
      right: forbidRight,
      leftClasses: leftClasses,
      rightClasses: rightClasses,
    );
  }

  String? lowestWinsMetric({
    required int leftPrintedGPower,
    required int rightPrintedGPower,
    required BakuganVariant leftVariant,
    required BakuganVariant rightVariant,
  }) {
    for (final effect in effects) {
      if (effect is! Map) continue;
      if (effect['type'] != 'lowest_wins') {
        continue;
      }

      final condition = effect['condition'];
      if (condition is Map) {
        final missingAttributes = condition['battle_lacks_any_attributes'];
        if (missingAttributes is List) {
          final battleAttributes = {
            leftVariant.attribute.toLowerCase(),
            rightVariant.attribute.toLowerCase(),
          };
          final hasForbiddenPresence = missingAttributes.any(
            (attribute) =>
                battleAttributes.contains(attribute.toString().toLowerCase()),
          );
          if (hasForbiddenPresence) {
            continue;
          }
        }

        final dynamic thresholdRaw =
            condition['printed_g_power_difference_gte'];
        if (thresholdRaw is num &&
            (leftPrintedGPower - rightPrintedGPower).abs() <
                thresholdRaw.toInt()) {
          continue;
        }
      }
      final metric = (effect['metric'] ?? 'total_g_power')
          .toString()
          .toLowerCase();
      return metric;
    }
    return null;
  }

  int? namedBakuganAutoWinSide({
    required BakuganVariant leftVariant,
    required BakuganVariant rightVariant,
    required int leftPrintedGPower,
    required int rightPrintedGPower,
  }) {
    for (final effect in effects) {
      if (effect is! Map ||
          effect['type'] != 'named_bakugan_auto_win_on_printed_margin') {
        continue;
      }

      final targetBakugan = effect['bakugan'];
      final thresholdRaw = effect['min_printed_g_power_lead'];
      if (thresholdRaw is! num) continue;
      final threshold = thresholdRaw.toInt();

      final leftMatches = _matchesNamedTargets(leftVariant, targetBakugan);
      final rightMatches = _matchesNamedTargets(rightVariant, targetBakugan);

      if (leftMatches && leftPrintedGPower - rightPrintedGPower >= threshold) {
        return 0;
      }
      if (rightMatches && rightPrintedGPower - leftPrintedGPower >= threshold) {
        return 1;
      }
    }
    return null;
  }

  int abilityGPowerModifierMultiplier({
    required AbilityCard sourceCard,
    required bool sourceIsLeft,
    required int leftPrintedGPower,
    required int rightPrintedGPower,
  }) {
    int multiplier = 1;

    for (final effect in effects) {
      if (effect is! Map ||
          effect['type'] != 'ability_card_g_power_modifier_multiplier') {
        continue;
      }

      final classes =
          ((effect['classes'] as List?)
                      ?.map((entry) => entry.toString().toLowerCase())
                      .where((entry) => entry.isNotEmpty) ??
                  const Iterable<String>.empty())
              .toSet();
      if (classes.isNotEmpty &&
          !classes.contains(sourceCard.cardClass.toLowerCase())) {
        continue;
      }

      final target = (effect['target'] ?? 'battle').toString().toLowerCase();
      if (target == 'lowest_printed_bakugan') {
        final sourcePrinted = sourceIsLeft
            ? leftPrintedGPower
            : rightPrintedGPower;
        final opponentPrinted = sourceIsLeft
            ? rightPrintedGPower
            : leftPrintedGPower;
        if (sourcePrinted >= opponentPrinted) {
          continue;
        }
      }

      final multiplierRaw = effect['multiplier'];
      if (multiplierRaw is num) {
        multiplier *= multiplierRaw.toInt();
      }
    }

    return multiplier;
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
    bool opponentAttributeMatchesHighestGateBonus = false,
    String? opponentAttribute,
  }) {
    int bonus = calculateBonus(variant);

    for (final effect in effects) {
      if (effect is! Map) continue;
      if (effect['type'] == 'named_bakugan_bonus') {
        final targets = effect['targets'];
        final targetList = targets is List
            ? targets
            : targets == null
            ? const []
            : [targets];
        final normalizedSpecies = variant.speciesName.toLowerCase();
        final matchesTarget = targetList.any((target) {
          final normalizedTarget = target.toString().toLowerCase().trim();
          if (normalizedTarget.isEmpty) return false;
          return normalizedSpecies == normalizedTarget ||
              normalizedSpecies.contains(normalizedTarget);
        });
        if (!matchesTarget) continue;

        final condition = effect['condition'];
        if (condition is Map &&
            condition['opponent_attribute_matches_highest_gate_bonus'] ==
                true &&
            !opponentAttributeMatchesHighestGateBonus) {
          continue;
        }

        final valueRaw = effect['value'];
        if (valueRaw is num) {
          bonus += valueRaw.toInt();
        }
        continue;
      }
      if (effect['type'] == 'flat_bonus') {
        final condition = effect['condition'];
        if (condition is Map) {
          final opponentAttributeIn = condition['opponent_attribute_in'];
          if (opponentAttributeIn is List) {
            final normalizedOpponentAttribute =
                opponentAttribute?.toLowerCase() ?? '';
            final matchesAttribute = opponentAttributeIn.any(
              (attribute) =>
                  attribute.toString().toLowerCase() ==
                  normalizedOpponentAttribute,
            );
            if (!matchesAttribute) continue;
          }

          final printedGPowerLte = condition['printed_g_power_lte'];
          if (printedGPowerLte is num &&
              ownPrintedGPower > printedGPowerLte.toInt()) {
            continue;
          }
        }

        final valueRaw = effect['value'];
        if (valueRaw is num) {
          bonus += valueRaw.toInt();
        }
        continue;
      }
    }

    return bonus;
  }

  int abilityGPowerModifierMultiplier({
    required AbilityCard sourceCard,
    required bool sourceIsLeft,
    required int leftPrintedGPower,
    required int rightPrintedGPower,
  }) {
    int multiplier = 1;

    for (final effect in effects) {
      if (effect is! Map ||
          effect['type'] != 'ability_card_g_power_modifier_multiplier') {
        continue;
      }

      final classes =
          ((effect['classes'] as List?)
                      ?.map((entry) => entry.toString().toLowerCase())
                      .where((entry) => entry.isNotEmpty) ??
                  const Iterable<String>.empty())
              .toSet();
      if (classes.isNotEmpty &&
          !classes.contains(sourceCard.cardClass.toLowerCase())) {
        continue;
      }

      final target = (effect['target'] ?? 'battle').toString().toLowerCase();
      if (target == 'lowest_printed_bakugan') {
        final sourcePrinted = sourceIsLeft
            ? leftPrintedGPower
            : rightPrintedGPower;
        final opponentPrinted = sourceIsLeft
            ? rightPrintedGPower
            : leftPrintedGPower;
        if (sourcePrinted >= opponentPrinted) {
          continue;
        }
      }

      final multiplierRaw = effect['multiplier'];
      if (multiplierRaw is num) {
        multiplier *= multiplierRaw.toInt();
      }
    }

    return multiplier;
  }

  ({int leftDelta, int rightDelta}) battleStateBonusDeltas({
    required BakuganVariant leftVariant,
    required BakuganVariant rightVariant,
    required int leftPrintedGPower,
    required int rightPrintedGPower,
    required int leftTotalGPower,
    required int rightTotalGPower,
  }) {
    int leftDelta = 0;
    int rightDelta = 0;

    for (final effect in effects) {
      if (effect is! Map || effect['type'] != 'battle_state_bonus') continue;

      final valueRaw = effect['value'];
      if (valueRaw is! num) continue;
      final value = valueRaw.toInt();
      if (value == 0) continue;

      final target = (effect['target'] ?? '').toString().toLowerCase();
      switch (target) {
        case 'highest_printed_bakugan':
          if (leftPrintedGPower > rightPrintedGPower) {
            leftDelta += value;
          } else if (rightPrintedGPower > leftPrintedGPower) {
            rightDelta += value;
          }
          break;
        case 'lowest_total_bakugan':
          if (leftTotalGPower < rightTotalGPower) {
            leftDelta += value;
          } else if (rightTotalGPower < leftTotalGPower) {
            rightDelta += value;
          }
          break;
      }
    }

    return (leftDelta: leftDelta, rightDelta: rightDelta);
  }

  bool get setsAllPrintedGPowerToZero => effects.any(
    (effect) =>
        effect is Map && effect['type'] == 'set_all_printed_g_power_to_zero',
  );

  bool get returnsOneUsedGateToOwnerIfOpponentHasMoreUsedGates => effects.any(
    (effect) =>
        effect is Map &&
        effect['type'] ==
            'return_one_used_gate_to_owner_if_opponent_has_more_used_gates',
  );

  bool get removesLosingBakuganFromGame => effects.any(
    (effect) =>
        effect is Map && effect['type'] == 'remove_loser_bakugan_from_game',
  );

  bool get supportsBeforeBattle => timings.contains('start_of_battle');

  bool get supportsDuringBattle => timings.contains('during_battle');

  bool get supportsAfterBattle => timings.contains('after_battle');

  bool get preventsGateCaptureAfterCloseLoss => effects.any(
    (effect) =>
        effect is Map &&
        effect['type'] == 'prevent_gate_capture_after_close_loss',
  );

  bool get setsPrintedGPowerFromOpponentUsedBakugan => effects.any(
    (effect) =>
        effect is Map &&
        effect['type'] == 'set_printed_g_power_from_opponent_used_bakugan',
  );

  bool get isMatchStageCard =>
      !supportsBeforeBattle && !supportsDuringBattle && !supportsAfterBattle;
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
// Battle bonus text positioning. Adjust these to fine-tune where the floating
// `+G` animation and the fixed pending `+G` label appear.
const Offset _battleAnimatedBonusBaseOffset = Offset(-40, 90);
const Offset _battlePendingBonusBaseOffset = Offset(-40, 170);
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

const _seasonOneModelsRoot = 'assets/models/Season 1 - Battle Brawlers/';
const _seasonTwoModelsRoot = 'assets/models/Season 2 - New Vestroia/';
const _normalBakuganAttributes = [
  'pyrus',
  'aquos',
  'subterra',
  'haos',
  'darkus',
  'ventus',
];

final Map<String, String> _normalTexturePathsByModelAndAttribute = {};

String? normalTexturePathForModel(String modelPath, String attribute) {
  return _normalTexturePathsByModelAndAttribute['$modelPath|${attribute.toLowerCase()}'];
}

const _legacyBannedSpeciesAndAttributes = {
  'gorem|darkus',
  'hammer gorem|subterra',
  'harpus|haos',
};

String _modelSpeciesRoot(String path) {
  final root = path.startsWith(_seasonOneModelsRoot)
      ? _seasonOneModelsRoot
      : _seasonTwoModelsRoot;
  final relativePath = path.substring(root.length);
  final speciesFolder = relativePath.split('/').first;
  return '$root$speciesFolder';
}

String _speciesNameFromRoot(String speciesRoot) {
  final name = speciesRoot.split('/').last;
  return switch (name) {
    'Preyas II Angelo' => 'Preyas Angelo',
    'Preyas II Diablo' => 'Preyas Diablo',
    _ => name,
  };
}

bool _isVisualObj(String path) {
  final lowerPath = path.toLowerCase();
  return lowerPath.endsWith('.obj') && !lowerPath.contains('hitbox');
}

int _visualModelPriority(String path) {
  final fileName = path.split('/').last.toLowerCase();
  if (fileName.contains('open')) return 0;
  if (fileName.contains('stand')) return 1;
  if (fileName.contains('closed')) return 2;
  return 3;
}

bool _isNormalTexture(String path) {
  final lowerPath = path.toLowerCase();
  if (!lowerPath.endsWith('.png') &&
      !lowerPath.endsWith('.jpg') &&
      !lowerPath.endsWith('.jpeg')) {
    return false;
  }

  final pathWithoutSpaces = lowerPath.replaceAll(' ', '');
  if (path.startsWith(_seasonOneModelsRoot)) {
    return pathWithoutSpaces.contains('/textures/core/') ||
        pathWithoutSpaces.contains('/textures/cores/');
  }

  final relativePath = path.substring(_seasonTwoModelsRoot.length).split('/');
  return relativePath.length == 3 &&
      relativePath[1].toLowerCase() == 'textures';
}

List<String> _attributeAliases(String attribute) {
  return switch (attribute) {
    'subterra' => ['subterra', 'subeterra'],
    'ventus' => ['ventus', 'ventis'],
    _ => [attribute],
  };
}

String _speciesNameFromImageSlug(String slug) {
  return slug
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _assetSlug(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

bool _isRenderableModelFallback(String path) {
  final lowerPath = path.toLowerCase();
  return lowerPath.endsWith('.glb') ||
      lowerPath.endsWith('.gltf') ||
      lowerPath.endsWith('.png') ||
      lowerPath.endsWith('.jpg') ||
      lowerPath.endsWith('.jpeg');
}

int _modelFallbackPriority(String path) {
  final lowerPath = path.toLowerCase();
  if (lowerPath.endsWith('.glb') || lowerPath.endsWith('.gltf')) return 0;
  return 1;
}

Map<String, Map<String, String>> _findModelFallbacks(List<String> assetPaths) {
  final candidates = <String, List<({String path, bool exact})>>{};

  for (final path in assetPaths) {
    if (!path.startsWith(_seasonTwoModelsRoot) ||
        !_isRenderableModelFallback(path)) {
      continue;
    }

    // Legacy Season 2 assets are kept as one renderable file per species.
    // Ignore nested Model/Textures assets here; those are handled by the OBJ
    // discovery above.
    final relativePath = path.substring(_seasonTwoModelsRoot.length).split('/');
    if (relativePath.length != 2) continue;

    final speciesSlug = _assetSlug(relativePath.first);
    final normalizedStem = _assetSlug(
      relativePath.last.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    for (final attribute in _normalBakuganAttributes) {
      final matches = _attributeAliases(
        attribute,
      ).map((alias) => '${speciesSlug}_$alias');
      final matchingStem = matches.firstWhere(
        (expectedStem) =>
            normalizedStem == expectedStem ||
            normalizedStem.startsWith('${expectedStem}_'),
        orElse: () => '',
      );
      if (matchingStem.isEmpty) continue;

      final speciesName = _speciesNameFromImageSlug(speciesSlug);
      final key = '$speciesName|$attribute';
      candidates.putIfAbsent(key, () => []).add((
        path: path,
        exact: normalizedStem == matchingStem,
      ));
    }
  }

  final fallbacks = <String, Map<String, String>>{};
  for (final entry in candidates.entries) {
    final separator = entry.key.lastIndexOf('|');
    final speciesName = entry.key.substring(0, separator);
    final attribute = entry.key.substring(separator + 1);
    final ranked = entry.value
      ..sort((a, b) {
        final formatCompare = _modelFallbackPriority(
          a.path,
        ).compareTo(_modelFallbackPriority(b.path));
        if (formatCompare != 0) return formatCompare;
        final exactCompare = (b.exact ? 1 : 0).compareTo(a.exact ? 1 : 0);
        if (exactCompare != 0) return exactCompare;
        return a.path.length.compareTo(b.path.length);
      });
    fallbacks.putIfAbsent(speciesName, () => {})[attribute] = ranked.first.path;
  }
  return fallbacks;
}

Map<String, Map<String, String>> _findImageFallbacks(List<String> assetPaths) {
  const imageRoot = 'assets/images/bakugan/';
  final candidates = <String, List<({String path, bool exact})>>{};

  for (final path in assetPaths) {
    if (!path.startsWith(imageRoot) ||
        (!path.toLowerCase().endsWith('.png') &&
            !path.toLowerCase().endsWith('.jpg') &&
            !path.toLowerCase().endsWith('.jpeg'))) {
      continue;
    }

    final relativePath = path.substring(imageRoot.length).split('/');
    if (relativePath.length != 2) continue;

    final speciesSlug = relativePath.first.toLowerCase();
    final fileName = relativePath.last.toLowerCase();
    final stem = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final normalizedStem = stem
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    for (final attribute in _normalBakuganAttributes) {
      final expectedStem = '${speciesSlug}_$attribute';
      if (normalizedStem != expectedStem &&
          !normalizedStem.startsWith('${expectedStem}_')) {
        continue;
      }

      final speciesName = _speciesNameFromImageSlug(speciesSlug);
      final key = '$speciesName|$attribute';
      candidates.putIfAbsent(key, () => []).add((
        path: path,
        exact: normalizedStem == expectedStem,
      ));
    }
  }

  final fallbacks = <String, Map<String, String>>{};
  for (final entry in candidates.entries) {
    final separator = entry.key.lastIndexOf('|');
    final speciesName = entry.key.substring(0, separator);
    final attribute = entry.key.substring(separator + 1);
    final ranked = entry.value
      ..sort((a, b) {
        final exactCompare = (b.exact ? 1 : 0).compareTo(a.exact ? 1 : 0);
        if (exactCompare != 0) return exactCompare;
        return a.path.length.compareTo(b.path.length);
      });
    fallbacks.putIfAbsent(speciesName, () => {})[attribute] = ranked.first.path;
  }
  return fallbacks;
}

String? _findNormalTexture(
  String speciesRoot,
  String attribute,
  List<String> assetPaths,
) {
  final aliases = _attributeAliases(attribute);
  final candidates = assetPaths.where((path) {
    if (!_isNormalTexture(path) ||
        !_modelSpeciesRoot(path).startsWith(speciesRoot)) {
      return false;
    }
    final fileName = path.split('/').last.toLowerCase().replaceAll(' ', '');
    return aliases.any(fileName.contains);
  }).toList()..sort();

  return candidates.isEmpty ? null : candidates.first;
}

Color _colorForBakuganAttribute(String attribute) {
  return switch (attribute) {
    'pyrus' => Colors.red,
    'aquos' => Colors.blue,
    'subterra' => Colors.brown,
    'haos' => Colors.limeAccent,
    'darkus' => Colors.deepPurple,
    'ventus' => Colors.teal,
    _ => Colors.red,
  };
}

int _gPowerFor(String speciesName, String attribute) => 0;

bool isBannedBakuganVariant(BakuganVariant variant) {
  return _legacyBannedSpeciesAndAttributes.contains(
    '${variant.speciesName.toLowerCase()}|${variant.attribute.toLowerCase()}',
  );
}

Future<void> loadAvailableBakugans() async {
  if (availableBakugans.isNotEmpty) return;
  try {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
      rootBundle,
    );
    final allAssetPaths = manifest.listAssets().toList();
    final assetPaths = allAssetPaths.where((String key) {
      return key.startsWith(_seasonOneModelsRoot) ||
          key.startsWith(_seasonTwoModelsRoot);
    }).toList();
    final modelPaths = assetPaths.where(_isVisualObj).toList();
    final modelPathsBySpeciesRoot = <String, List<String>>{};
    for (final modelPath in modelPaths) {
      modelPathsBySpeciesRoot
          .putIfAbsent(_modelSpeciesRoot(modelPath), () => [])
          .add(modelPath);
    }

    _normalTexturePathsByModelAndAttribute.clear();
    final grouped = <String, List<BakuganVariant>>{};
    final sortedSpeciesRoots = modelPathsBySpeciesRoot.keys.toList()..sort();
    for (final speciesRoot in sortedSpeciesRoots) {
      final modelCandidates = modelPathsBySpeciesRoot[speciesRoot]!
        ..sort((a, b) {
          final priority = _visualModelPriority(
            a,
          ).compareTo(_visualModelPriority(b));
          if (priority != 0) return priority;
          return a.length.compareTo(b.length);
        });
      final modelPath = modelCandidates.first;
      String? closedModelPath;
      for (final candidate in modelCandidates) {
        if (candidate.split('/').last.toLowerCase().contains('closed')) {
          closedModelPath = candidate;
          break;
        }
      }
      final speciesName = _speciesNameFromRoot(speciesRoot);
      final variants = <BakuganVariant>[];

      for (final attribute in _normalBakuganAttributes) {
        final texturePath = _findNormalTexture(
          speciesRoot,
          attribute,
          assetPaths,
        );
        if (texturePath == null) {
          variants.clear();
          break;
        }
        _normalTexturePathsByModelAndAttribute['$modelPath|$attribute'] =
            texturePath;
        variants.add(
          BakuganVariant(
            attribute: attribute,
            modelPath: modelPath,
            closedModelPath: closedModelPath,
            texturePath: texturePath,
            color: _colorForBakuganAttribute(attribute),
            gPower: _gPowerFor(speciesName, attribute),
            speciesName: speciesName,
          ),
        );
      }

      if (variants.isNotEmpty) {
        grouped[speciesName] = variants;
      }
    }

    // Some legacy Bakugan have a dedicated GLB or ball image in the model
    // library but no OBJ/textures. Prefer those assets over old illustrations.
    final modelFallbacks = _findModelFallbacks(allAssetPaths);
    for (final entry in modelFallbacks.entries) {
      if (grouped.containsKey(entry.key)) continue;

      final variants = <BakuganVariant>[];
      for (final attribute in _normalBakuganAttributes) {
        final modelPath = entry.value[attribute];
        if (modelPath == null) continue;
        variants.add(
          BakuganVariant(
            attribute: attribute,
            modelPath: modelPath,
            color: _colorForBakuganAttribute(attribute),
            gPower: _gPowerFor(entry.key, attribute),
            speciesName: entry.key,
          ),
        );
      }
      if (variants.isNotEmpty) grouped[entry.key] = variants;
    }

    // Keep the old illustration fallback only for Bakugan without a dedicated
    // model-library asset.
    final imageFallbacks = _findImageFallbacks(allAssetPaths);
    for (final entry in imageFallbacks.entries) {
      if (grouped.containsKey(entry.key)) continue;

      final variants = <BakuganVariant>[];
      for (final attribute in _normalBakuganAttributes) {
        final imagePath = entry.value[attribute];
        if (imagePath == null) continue;
        variants.add(
          BakuganVariant(
            attribute: attribute,
            modelPath: imagePath,
            color: _colorForBakuganAttribute(attribute),
            gPower: _gPowerFor(entry.key, attribute),
            speciesName: entry.key,
          ),
        );
      }
      if (variants.isNotEmpty) grouped[entry.key] = variants;
    }

    availableBakugans =
        grouped.entries
            .map((entry) => Bakugan(name: entry.key, variants: entry.value))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

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
          modelPath:
              'assets/models/Season 1 - Battle Brawlers/Dragonoid/Dragonoid Stand.obj',
          texturePath:
              'assets/models/Season 1 - Battle Brawlers/Dragonoid/Textures/Core/Pyrus Dragonoid.png',
          color: Colors.red,
          gPower: _gPowerFor('Dragonoid', 'pyrus'),
          speciesName: 'Dragonoid',
        ),
      ],
    ),
  ];
}
