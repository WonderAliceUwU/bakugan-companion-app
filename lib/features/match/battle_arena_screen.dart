part of '../../main.dart';

class BattleArenaScreen extends StatefulWidget {
  final PlayerData leftPlayer;
  final PlayerData rightPlayer;
  final int leftPlayerIndex;
  final int rightPlayerIndex;
  final BakuganVariant leftBakugan;
  final BakuganVariant rightBakugan;
  final int usedGateCardsInAllPiles;
  final int leftUsedGateCards;
  final int rightUsedGateCards;
  final List<List<MatchPresentedAbility?>> presentedMatchAbilities;

  const BattleArenaScreen({
    super.key,
    required this.leftPlayer,
    required this.rightPlayer,
    required this.leftPlayerIndex,
    required this.rightPlayerIndex,
    required this.leftBakugan,
    required this.rightBakugan,
    required this.presentedMatchAbilities,
    this.usedGateCardsInAllPiles = 0,
    this.leftUsedGateCards = 0,
    this.rightUsedGateCards = 0,
  });

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class BakuganNameFooter extends StatelessWidget {
  final String speciesName;
  final Color themeColor;
  final int? gPower;
  final bool center;

  const BakuganNameFooter({
    super.key,
    required this.speciesName,
    required this.themeColor,
    this.gPower,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: center ? 0 : -30,
      right: center ? 0 : 33,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: themeColor, width: 3),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(0.15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: AutoSizeText(
                    speciesName.toUpperCase(),
                    maxLines: 1,
                    minFontSize: 18,
                    stepGranularity: 0.5,
                    overflow: TextOverflow.visible,
                    textAlign: center ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      fontFamily: 'title_font',
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 10, color: themeColor)],
                    ),
                  ),
                ),
                if (gPower != null)
                  Transform.translate(
                    offset: const Offset(0, 4),
                    child: Text(
                      '${gPower}G',
                      style: TextStyle(
                        fontFamily: 'button_font',
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: themeColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BattleArenaScreenState extends State<BattleArenaScreen>
    with SingleTickerProviderStateMixin {
  List<MatchPresentedAbility?> get _leftAbilitySlots =>
      widget.presentedMatchAbilities[widget.leftPlayerIndex];

  List<MatchPresentedAbility?> get _rightAbilitySlots =>
      widget.presentedMatchAbilities[widget.rightPlayerIndex];

  final Set<int> _leftAppliedAbilitySlots = {};
  final Set<int> _rightAppliedAbilitySlots = {};

  AbilityCard? get _focusedLeftAbilityCard =>
      _focusedLeftAbilitySlotIndex == null
      ? null
      : _leftAbilitySlots[_focusedLeftAbilitySlotIndex!]?.card;

  AbilityCard? get _focusedRightAbilityCard =>
      _focusedRightAbilitySlotIndex == null
      ? null
      : _rightAbilitySlots[_focusedRightAbilitySlotIndex!]?.card;

  final TextEditingController _cardNameController = TextEditingController();
  final FocusNode _cardNameFocusNode = FocusNode();

  late final AnimationController _powerAnimationController;
  late final AudioPlayer _powerStartPlayer;
  late final AudioPlayer _countTickPlayer;
  late final AudioPlayer _revealSfxPlayer;
  StreamSubscription<void>? _battleMusicCompleteSub;
  bool _hasReturnedToMatch = false;

  Map<String, GateCard> _gateCards = {};
  Map<String, AbilityCard> _abilityCards = {};
  bool _isLoadingGateCards = true;
  bool _isLoadingAbilityCards = true;
  GateCard? _revealedCard;
  int? _focusedLeftAbilitySlotIndex;
  int? _focusedRightAbilitySlotIndex;
  bool _showLeftAbilityPresentation = false;
  bool _showRightAbilityPresentation = false;
  bool _showLeftAbilityFlash = false;
  bool _showRightAbilityFlash = false;
  bool _showRevealFlash = false;
  bool _isResolvingCard = false;
  int _leftCurrentGPower = 0;
  int _rightCurrentGPower = 0;
  int _leftTargetGPower = 0;
  int _rightTargetGPower = 0;
  int _leftBattlePrintedGPower = 0;
  int _rightBattlePrintedGPower = 0;
  int _leftAnimationStartGPower = 0;
  int _rightAnimationStartGPower = 0;
  int? _leftFloatingBonus;
  int? _rightFloatingBonus;
  bool _areAbilityCardsForbidden = false;
  String? _winnerText;
  int? _winnerSideIndex;
  bool _isTieResult = false;
  Timer? _powerTickTimer;
  String? _currentBattleMusicAsset;

  @override
  void initState() {
    super.initState();
    _leftCurrentGPower = widget.leftBakugan.gPower;
    _rightCurrentGPower = widget.rightBakugan.gPower;
    _leftTargetGPower = _leftCurrentGPower;
    _rightTargetGPower = _rightCurrentGPower;
    _leftBattlePrintedGPower = widget.leftBakugan.gPower;
    _rightBattlePrintedGPower = widget.rightBakugan.gPower;
    _leftAnimationStartGPower = _leftCurrentGPower;
    _rightAnimationStartGPower = _rightCurrentGPower;
    _powerStartPlayer = AudioPlayer();
    _countTickPlayer = AudioPlayer();
    _revealSfxPlayer = AudioPlayer();
    _powerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..addListener(_handlePowerAnimationTick);

    _battleMusicCompleteSub = _battleMusicPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_winnerSideIndex != null || _isTieResult) {
        _returnToMatch();
      }
    });

    _startBattleMusic();
    _loadBattleCards();
  }

  int _lerpGPower(int start, int end, double t) {
    return lerpDouble(start, end, t)!.round();
  }

  void _handlePowerAnimationTick() {
    if (!mounted) return;
    final t = Curves.easeOutCubic.transform(_powerAnimationController.value);
    setState(() {
      _leftCurrentGPower = _lerpGPower(
        _leftAnimationStartGPower,
        _leftTargetGPower,
        t,
      );
      _rightCurrentGPower = _lerpGPower(
        _rightAnimationStartGPower,
        _rightTargetGPower,
        t,
      );
    });
  }

  Future<void> _playPowerStart() async {
    try {
      await _powerStartPlayer.stop();
      await _powerStartPlayer.play(AssetSource('sound/g_power_up.wav'));
    } catch (_) {}
  }

  Future<void> _playCountTick() async {
    try {
      await _countTickPlayer.stop();
      await _countTickPlayer.play(AssetSource('sound/count.wav'));
    } catch (_) {}
  }

  void _stopPowerTickLoop() {
    _powerTickTimer?.cancel();
    _powerTickTimer = null;
    _powerStartPlayer.stop();
    _countTickPlayer.stop();
  }

  void _startPowerTickLoop() {
    _stopPowerTickLoop();
    _playPowerStart();
    _playCountTick();
    _powerTickTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      _playCountTick();
    });
  }

  Future<void> _playBattleMusicTrack(String assetPath) async {
    try {
      await _bgMusicPlayer.pause();
      if (_currentBattleMusicAsset == assetPath) return;
      await _battleMusicPlayer.stop();
      await _battleMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _battleMusicPlayer.play(AssetSource(assetPath));
      _currentBattleMusicAsset = assetPath;
    } catch (_) {}
  }

  Future<void> _startBattleMusic() async {
    await _playBattleMusicTrack('music/battle/before_ability.flac');
  }

  Future<void> _playAfterAbilityMusic() async {
    await _playBattleMusicTrack('music/battle/after_ability.flac');
  }

  Future<void> _playBattleRevealSfx(String assetName) async {
    try {
      await _revealSfxPlayer.stop();
      await _revealSfxPlayer.play(AssetSource('sound/$assetName'));
    } catch (_) {}
  }

  Future<void> _playGPowerSwapSound() async {
    try {
      await _revealSfxPlayer.stop();
      await _revealSfxPlayer.play(AssetSource('sound/g_power_swap.wav'));
    } catch (_) {}
  }

  Future<void> _playBattleWinSound() async {
    try {
      await _battleMusicPlayer.stop();
      await _battleMusicPlayer.setReleaseMode(ReleaseMode.stop);
      await _battleMusicPlayer.play(AssetSource('sound/win_battle.flac'));
    } catch (_) {}
  }

  Future<void> _animatePowerChange({
    required int leftTarget,
    required int rightTarget,
    int? leftBonus,
    int? rightBonus,
  }) async {
    _stopPowerTickLoop();
    _powerAnimationController.stop();

    setState(() {
      _isResolvingCard = true;
      _leftAnimationStartGPower = _leftCurrentGPower;
      _rightAnimationStartGPower = _rightCurrentGPower;
      _leftTargetGPower = leftTarget;
      _rightTargetGPower = rightTarget;
      _leftFloatingBonus = leftBonus != null && leftBonus > 0
          ? leftBonus
          : null;
      _rightFloatingBonus = rightBonus != null && rightBonus > 0
          ? rightBonus
          : null;
    });

    _startPowerTickLoop();
    await _powerAnimationController.forward(from: 0);
    _stopPowerTickLoop();
    if (!mounted) return;

    setState(() {
      _leftCurrentGPower = _leftTargetGPower;
      _rightCurrentGPower = _rightTargetGPower;
      _leftFloatingBonus = null;
      _rightFloatingBonus = null;
      _isResolvingCard = false;
    });
  }

  Future<void> _loadBattleCards() async {
    try {
      final String rawJson = await rootBundle.loadString(
        'assets/images/cards/cards.json',
      );

      final dynamic decodedJson = jsonDecode(rawJson);
      if (decodedJson is! Map) {
        throw Exception('cards.json root is not a JSON object');
      }

      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
        decodedJson,
      );

      final dynamic cardsNode = decoded['cards'];
      if (cardsNode is! Map) {
        throw Exception('cards.json does not contain a valid "cards" object');
      }

      final Map<String, dynamic> cards = Map<String, dynamic>.from(cardsNode);

      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );

      final List<String> assets = manifest
          .listAssets()
          .where(
            (asset) =>
                asset.startsWith('assets/images/cards/') &&
                asset != 'assets/images/cards/anverse.png' &&
                asset.endsWith('.png'),
          )
          .toList();

      final Map<String, GateCard> loadedCards = {};
      final Map<String, AbilityCard> loadedAbilityCards = {};

      for (final entry in cards.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value is! Map) {
          debugPrint('Skipping card "$key": value is not an object');
          continue;
        }

        final data = Map<String, dynamic>.from(value);

        final String name = (data['name'] ?? '').toString().trim();
        final String type = (data['type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final String? fileName = data['file']?.toString();
        final String cardClass = (data['card_class'] ?? 'silver')
            .toString()
            .toLowerCase();

        if (name.isEmpty || type.isEmpty) {
          debugPrint('Skipping card "$key": missing name or type');
          continue;
        }

        final descriptionsRaw = data['descriptions'];
        final Map<String, dynamic> descriptions =
            descriptionsRaw is Map<String, dynamic>
            ? descriptionsRaw
            : descriptionsRaw is Map
            ? Map<String, dynamic>.from(descriptionsRaw)
            : const {};

        final String? descriptionEn = descriptions['en']?.toString();
        final String? descriptionEs = descriptions['es']?.toString();

        final effectsRaw = data['effects'];
        final List<dynamic> effects = effectsRaw is List
            ? List<dynamic>.from(effectsRaw)
            : const [];

        final rulesRaw = data['rules'];
        final List<dynamic> rules = rulesRaw is List
            ? List<dynamic>.from(rulesRaw)
            : const [];

        final attributesRaw = data['attributes'];
        final Map<String, int> attributes = <String, int>{};

        if (attributesRaw is Map) {
          for (final attrEntry in attributesRaw.entries) {
            final attrKey = attrEntry.key.toString().toLowerCase();
            final attrValue = attrEntry.value;
            if (attrValue is num) {
              attributes[attrKey] = attrValue.toInt();
            } else {
              final parsed = int.tryParse(attrValue.toString());
              if (parsed != null) {
                attributes[attrKey] = parsed;
              }
            }
          }
        }

        final imagePath = _matchCardImagePath(
          cardKey: key,
          cardName: name,
          assetPaths: assets,
          fileName: fileName,
        );

        if (type == 'gate') {
          loadedCards[key] = GateCard(
            key: key,
            name: name,
            imagePath: imagePath ?? 'assets/images/cards/anverse.png',
            descriptionEn: descriptionEn,
            descriptionEs: descriptionEs,
            attributes: attributes,
            cardClass: cardClass,
            hasEffect: effects.isNotEmpty || rules.isNotEmpty,
            effects: effects,
          );
        } else if (type == 'ability') {
          final Set<String> timings = <String>{};

          for (final rule in rules) {
            if (rule is Map) {
              final timing = rule['timing']?.toString().toLowerCase();
              if (timing != null && timing.isNotEmpty) {
                timings.add(timing);
              }
            }
          }

          for (final effect in effects) {
            if (effect is Map) {
              final timing = effect['timing']?.toString().toLowerCase();
              if (timing != null && timing.isNotEmpty) {
                timings.add(timing);
              }
            }
          }

          loadedAbilityCards[key] = AbilityCard(
            key: key,
            name: name,
            imagePath: imagePath ?? 'assets/images/cards/anverse.png',
            descriptionEn: descriptionEn,
            descriptionEs: descriptionEs,
            attributes: attributes,
            cardClass: cardClass,
            timings: timings,
            effects: effects,
          );
        } else {
          debugPrint('Skipping card "$key": unknown type "$type"');
        }
      }

      debugPrint('Loaded gate cards: ${loadedCards.length}');
      debugPrint('Loaded ability cards: ${loadedAbilityCards.length}');

      if (!mounted) return;
      setState(() {
        _gateCards = loadedCards;
        _abilityCards = loadedAbilityCards;
        _isLoadingGateCards = false;
        _isLoadingAbilityCards = false;
      });
    } catch (e, st) {
      debugPrint('ERROR loading battle cards: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;
      setState(() {
        _isLoadingGateCards = false;
        _isLoadingAbilityCards = false;
      });
    }
  }

  List<GateCard> _rankGateCardMatches(String input, {int limit = 6}) {
    final query = _normalizeCardLookup(input);
    if (query.isEmpty) return const [];

    final ranked =
        _gateCards.values
            .map((card) {
              final normalizedName = _normalizeCardLookup(card.name);
              final normalizedKey = _normalizeCardLookup(card.key);

              int score = 0;
              if (normalizedName == query) score += 1000;
              if (normalizedKey == query) score += 900;
              if (normalizedName.startsWith(query)) score += 400;
              if (normalizedKey.startsWith(query)) score += 300;
              if (normalizedName.contains(query)) score += 150;
              if (normalizedKey.contains(query)) score += 100;

              return (card: card, score: score);
            })
            .where((entry) => entry.score > 0)
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) return scoreCompare;
            return a.card.name.compareTo(b.card.name);
          });

    return ranked.take(limit).map((entry) => entry.card).toList();
  }

  GateCard? _findGateCard(String input) {
    final query = _normalizeCardLookup(input);
    if (query.isEmpty) return null;

    final matches = _rankGateCardMatches(input, limit: 6);
    if (matches.isEmpty) return null;

    final topMatch = matches.first;
    final topName = _normalizeCardLookup(topMatch.name);
    final topKey = _normalizeCardLookup(topMatch.key);
    if (topName == query || topKey == query) {
      return topMatch;
    }
    if (matches.length == 1) {
      return topMatch;
    }
    return null;
  }

  List<AbilityCard> _rankAbilityCardMatches(
    String input, {
    int limit = 6,
    required bool beforeGateReveal,
  }) {
    final query = _normalizeCardLookup(input);
    final candidateCards = beforeGateReveal
        ? _abilityCards.values.where((card) => card.supportsBeforeBattle)
        : _abilityCards.values.where((card) => card.supportsDuringBattle);

    if (query.isEmpty) {
      return candidateCards.take(limit).toList();
    }

    final ranked =
        candidateCards
            .map((card) {
              final normalizedName = _normalizeCardLookup(card.name);
              final normalizedKey = _normalizeCardLookup(card.key);

              int score = 0;
              if (normalizedName == query) score += 1000;
              if (normalizedKey == query) score += 900;
              if (normalizedName.startsWith(query)) score += 400;
              if (normalizedKey.startsWith(query)) score += 300;
              if (normalizedName.contains(query)) score += 150;
              if (normalizedKey.contains(query)) score += 100;

              return (card: card, score: score);
            })
            .where((entry) => entry.score > 0)
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) return scoreCompare;
            return a.card.name.compareTo(b.card.name);
          });

    return ranked.take(limit).map((entry) => entry.card).toList();
  }

  AbilityCard? _findAbilityCard(
    String input, {
    required bool beforeGateReveal,
  }) {
    final query = _normalizeCardLookup(input);
    if (query.isEmpty) return null;

    final matches = _rankAbilityCardMatches(
      input,
      limit: 6,
      beforeGateReveal: beforeGateReveal,
    );
    if (matches.isEmpty) return null;

    final topMatch = matches.first;
    final topName = _normalizeCardLookup(topMatch.name);
    final topKey = _normalizeCardLookup(topMatch.key);
    if (topName == query || topKey == query) {
      return topMatch;
    }
    if (matches.length == 1) {
      return topMatch;
    }
    return null;
  }

  Future<void> _openGateCardPrompt() async {
    if (_isLoadingGateCards || _isResolvingCard || _revealedCard != null) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    _cardNameController.text = _revealedCard?.name ?? '';

    final selectedCard = await showDialog<GateCard>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final match = _findGateCard(_cardNameController.text);
              if (match == null) {
                setDialogState(() {
                  errorText =
                      'Gate card not found. Type the printed card name.';
                });
                return;
              }
              Navigator.of(context).pop(match);
            }

            return Dialog(
              backgroundColor: const Color(0xFF111318),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reveal Gate Card',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Type the printed gate card name or pick a suggestion.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 20),
                    RawAutocomplete<GateCard>(
                      textEditingController: _cardNameController,
                      focusNode: _cardNameFocusNode,
                      displayStringForOption: (option) => option.name,
                      optionsBuilder: (textEditingValue) {
                        return _rankGateCardMatches(textEditingValue.text);
                      },
                      onSelected: (option) {
                        Navigator.of(context).pop(option);
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              autofocus: true,
                              onChanged: (_) {
                                if (errorText != null) {
                                  setDialogState(() {
                                    errorText = null;
                                  });
                                }
                              },
                              onSubmitted: (_) => submit(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Example: Fire Pit',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                                errorText: errorText,
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.06),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        final matches = options.toList();
                        if (matches.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            color: const Color(0xFF171B22),
                            elevation: 12,
                            borderRadius: BorderRadius.circular(16),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 520,
                                maxHeight: 260,
                              ),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shrinkWrap: true,
                                itemCount: matches.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: Colors.white12,
                                ),
                                itemBuilder: (context, index) {
                                  final card = matches[index];
                                  return InkWell(
                                    onTap: () => onSelected(card),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              card.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            card.key,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.45,
                                              ),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          child: const Text(
                            'REVEAL',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedCard != null) {
      FocusManager.instance.primaryFocus?.unfocus();
      await _revealGateCard(selectedCard);
    }
  }

  Future<void> _openAbilityCardPrompt(bool isLeft) async {
    if (_isLoadingAbilityCards || _isResolvingCard) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _cardNameController.clear();
    final isBeforeReveal = _revealedCard == null;

    final selectedCard = await showDialog<AbilityCard>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final match = _findAbilityCard(
                _cardNameController.text,
                beforeGateReveal: isBeforeReveal,
              );
              if (match == null) {
                setDialogState(() {
                  errorText = isBeforeReveal
                      ? 'Ability card not found or not valid before the gate reveal.'
                      : 'Ability card not found or not valid after the gate reveal.';
                });
                return;
              }
              Navigator.of(context).pop(match);
            }

            return Dialog(
              backgroundColor: const Color(0xFF111318),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Present Ability Card',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Type the printed ability card name or pick a suggestion.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 20),
                    RawAutocomplete<AbilityCard>(
                      textEditingController: _cardNameController,
                      focusNode: _cardNameFocusNode,
                      displayStringForOption: (option) => option.name,
                      optionsBuilder: (textEditingValue) {
                        return _rankAbilityCardMatches(
                          textEditingValue.text,
                          beforeGateReveal: isBeforeReveal,
                        );
                      },
                      onSelected: (option) {
                        Navigator.of(context).pop(option);
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              autofocus: true,
                              onChanged: (_) {
                                if (errorText != null) {
                                  setDialogState(() {
                                    errorText = null;
                                  });
                                }
                              },
                              onSubmitted: (_) => submit(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Example: G-Power Bump',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                                errorText: errorText,
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.06),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        final matches = options.toList();
                        if (matches.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            color: const Color(0xFF171B22),
                            elevation: 12,
                            borderRadius: BorderRadius.circular(16),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 520,
                                maxHeight: 260,
                              ),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shrinkWrap: true,
                                itemCount: matches.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: Colors.white12,
                                ),
                                itemBuilder: (context, index) {
                                  final card = matches[index];
                                  final bonus = card.calculateBonus(
                                    isLeft
                                        ? widget.leftBakugan
                                        : widget.rightBakugan,
                                  );
                                  return InkWell(
                                    onTap: () => onSelected(card),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              card.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            bonus > 0 ? '+$bonus' : card.key,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          child: const Text(
                            'PRESENT',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedCard != null) {
      FocusManager.instance.primaryFocus?.unfocus();
      await _presentAbilityCard(isLeft, selectedCard);
    }
  }

  Future<void> _revealGateCard(GateCard card) async {
    if (_isResolvingCard) return;

    final leftBreakdown = card.bonusBreakdownFor(
      widget.leftBakugan,
      usedGateCardsInAllPiles: widget.usedGateCardsInAllPiles,
      ownerUsedGateCards: widget.leftUsedGateCards,
      opponentUsedGateCards: widget.rightUsedGateCards,
      teamBakugans: widget.leftPlayer.deck,
    );
    final rightBreakdown = card.bonusBreakdownFor(
      widget.rightBakugan,
      usedGateCardsInAllPiles: widget.usedGateCardsInAllPiles,
      ownerUsedGateCards: widget.rightUsedGateCards,
      opponentUsedGateCards: widget.leftUsedGateCards,
      teamBakugans: widget.rightPlayer.deck,
    );
    try {
      await precacheImage(AssetImage(card.imagePath), context);
    } catch (_) {}
    _playBattleRevealSfx('gate_reveal.wav');
    _stopPowerTickLoop();
    _powerAnimationController.stop();

    setState(() {
      _winnerText = null;
      _revealedCard = card;
      _showRevealFlash = true;
      _leftCurrentGPower = widget.leftBakugan.gPower;
      _rightCurrentGPower = widget.rightBakugan.gPower;
      _leftTargetGPower = _leftCurrentGPower;
      _rightTargetGPower = _rightCurrentGPower;
      _leftBattlePrintedGPower = widget.leftBakugan.gPower;
      _rightBattlePrintedGPower = widget.rightBakugan.gPower;
      _areAbilityCardsForbidden = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    setState(() {
      _showRevealFlash = false;
    });

    if (card.swapsPrintedGPower) {
      final swappedLeftGPower = _rightBattlePrintedGPower;
      final swappedRightGPower = _leftBattlePrintedGPower;

      await _playGPowerSwapSound();
      await _animatePowerChange(
        leftTarget: swappedLeftGPower,
        rightTarget: swappedRightGPower,
      );
      if (!mounted) return;

      setState(() {
        _leftBattlePrintedGPower = swappedLeftGPower;
        _rightBattlePrintedGPower = swappedRightGPower;
      });
    }

    if (card.forbidsAbilityCards(
      leftPrintedGPower: _leftBattlePrintedGPower,
      rightPrintedGPower: _rightBattlePrintedGPower,
    )) {
      setState(() {
        _areAbilityCardsForbidden = true;
        _showLeftAbilityPresentation = false;
        _showRightAbilityPresentation = false;
        _showLeftAbilityFlash = false;
        _showRightAbilityFlash = false;
        _focusedLeftAbilitySlotIndex = null;
        _focusedRightAbilitySlotIndex = null;
      });
    }

    final leftSegments = leftBreakdown.bonusSegments;
    final rightSegments = rightBreakdown.bonusSegments;
    final maxSegments = max(leftSegments.length, rightSegments.length);

    for (int i = 0; i < maxSegments; i++) {
      final leftSegment = i < leftSegments.length ? leftSegments[i] : 0;
      final rightSegment = i < rightSegments.length ? rightSegments[i] : 0;

      if (leftSegment <= 0 && rightSegment <= 0) continue;

      await _animatePowerChange(
        leftTarget: _leftCurrentGPower + leftSegment,
        rightTarget: _rightCurrentGPower + rightSegment,
        leftBonus: leftSegment > 0 ? leftSegment : null,
        rightBonus: rightSegment > 0 ? rightSegment : null,
      );
    }

    await _applyQueuedAbilityCards();
  }

  Future<void> _presentAbilityCard(bool isLeft, AbilityCard card) async {
    if (_areAbilityCardsForbidden) return;
    final slots = isLeft ? _leftAbilitySlots : _rightAbilitySlots;
    final int slotIndex = slots.indexWhere((slot) => slot == null);

    if (slotIndex == -1) return;

    final pendingBonus = card.calculateBonus(
      isLeft ? widget.leftBakugan : widget.rightBakugan,
    );

    try {
      await precacheImage(AssetImage(card.imagePath), context);
    } catch (_) {}

    _playBattleRevealSfx('ability_reveal.wav');

    setState(() {
      slots[slotIndex] = MatchPresentedAbility(card: card, isActive: true);

      if (isLeft) {
        _focusedLeftAbilitySlotIndex = slotIndex;
      } else {
        _focusedRightAbilitySlotIndex = slotIndex;
      }
    });

    _showAbilityPresentation(isLeft, withFlash: true, slotIndex: slotIndex);

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    setState(() {
      if (isLeft) {
        _showLeftAbilityFlash = false;
      } else {
        _showRightAbilityFlash = false;
      }
    });

    if (_revealedCard != null) {
      _playAfterAbilityMusic();
    }

    if (_revealedCard == null || pendingBonus <= 0) {
      return;
    }

    await _applyQueuedAbilityCards();
  }

  Future<void> _applyQueuedAbilityCards() async {
    if (_isResolvingCard || _revealedCard == null || _areAbilityCardsForbidden) {
      return;
    }

    int leftBonus = 0;
    int rightBonus = 0;
    final List<int> newlyAppliedLeft = [];
    final List<int> newlyAppliedRight = [];

    for (int i = 0; i < _leftAbilitySlots.length; i++) {
      final slot = _leftAbilitySlots[i];
      if (slot != null &&
          slot.isActive &&
          !_leftAppliedAbilitySlots.contains(i)) {
        leftBonus += slot.card.calculateBonus(widget.leftBakugan);
        newlyAppliedLeft.add(i);
      }
    }

    for (int i = 0; i < _rightAbilitySlots.length; i++) {
      final slot = _rightAbilitySlots[i];
      if (slot != null &&
          slot.isActive &&
          !_rightAppliedAbilitySlots.contains(i)) {
        rightBonus += slot.card.calculateBonus(widget.rightBakugan);
        newlyAppliedRight.add(i);
      }
    }

    if (leftBonus <= 0 && rightBonus <= 0) return;

    await _animatePowerChange(
      leftTarget: _leftCurrentGPower + leftBonus,
      rightTarget: _rightCurrentGPower + rightBonus,
      leftBonus: leftBonus > 0 ? leftBonus : null,
      rightBonus: rightBonus > 0 ? rightBonus : null,
    );

    if (!mounted) return;

    setState(() {
      _leftAppliedAbilitySlots.addAll(newlyAppliedLeft);
      _rightAppliedAbilitySlots.addAll(newlyAppliedRight);

      for (final i in newlyAppliedLeft) {
        final slot = _leftAbilitySlots[i];
        if (slot != null) {
          _leftAbilitySlots[i] = slot.copyWith(isActive: false);
        }
      }

      for (final i in newlyAppliedRight) {
        final slot = _rightAbilitySlots[i];
        if (slot != null) {
          _rightAbilitySlots[i] = slot.copyWith(isActive: false);
        }
      }
    });
  }

  void _showAbilityPresentation(
    bool isLeft, {
    bool withFlash = false,
    int? slotIndex,
  }) {
    setState(() {
      if (isLeft) {
        if (slotIndex != null) {
          _focusedLeftAbilitySlotIndex = slotIndex;
        }
        _showLeftAbilityPresentation = true;
        _showLeftAbilityFlash = withFlash;
      } else {
        if (slotIndex != null) {
          _focusedRightAbilitySlotIndex = slotIndex;
        }
        _showRightAbilityPresentation = true;
        _showRightAbilityFlash = withFlash;
      }
    });
  }

  void _dismissAbilityPresentation(bool isLeft) {
    setState(() {
      if (isLeft) {
        _showLeftAbilityPresentation = false;
        _showLeftAbilityFlash = false;
      } else {
        _showRightAbilityPresentation = false;
        _showRightAbilityFlash = false;
      }
    });
  }

  void _returnFocusedBattleAbilityToUnusedPile(bool isLeft) {
    setState(() {
      if (isLeft) {
        final slotIndex = _focusedLeftAbilitySlotIndex;
        if (slotIndex != null) {
          _leftAbilitySlots[slotIndex] = null;
          _leftAppliedAbilitySlots.remove(slotIndex);
        }
        _showLeftAbilityPresentation = false;
        _showLeftAbilityFlash = false;
        _focusedLeftAbilitySlotIndex = null;
      } else {
        final slotIndex = _focusedRightAbilitySlotIndex;
        if (slotIndex != null) {
          _rightAbilitySlots[slotIndex] = null;
          _rightAppliedAbilitySlots.remove(slotIndex);
        }
        _showRightAbilityPresentation = false;
        _showRightAbilityFlash = false;
        _focusedRightAbilitySlotIndex = null;
      }
    });
  }

  void _showWinnerScreen(int sideIndex) {
    setState(() {
      _isTieResult = false;
      _winnerSideIndex = sideIndex;
      _winnerText = sideIndex == 0
          ? '${widget.leftPlayer.name} WINS!'
          : '${widget.rightPlayer.name} WINS!';
      _showLeftAbilityPresentation = false;
      _showRightAbilityPresentation = false;
      _showLeftAbilityFlash = false;
      _showRightAbilityFlash = false;
      _leftFloatingBonus = null;
      _rightFloatingBonus = null;
    });
    unawaited(_playBattleWinSound());
  }

  Future<void> _showTieResult() async {
    setState(() {
      _isTieResult = true;
      _winnerSideIndex = null;
      _winnerText = 'TIE!';
      _showLeftAbilityPresentation = false;
      _showRightAbilityPresentation = false;
      _showLeftAbilityFlash = false;
      _showRightAbilityFlash = false;
      _leftFloatingBonus = null;
      _rightFloatingBonus = null;
    });
    unawaited(_playBattleWinSound());
  }

  void _returnToMatch() {
    if ((_winnerSideIndex == null && !_isTieResult) || _hasReturnedToMatch) {
      return;
    }
    _hasReturnedToMatch = true;
    Navigator.of(context).pop(_winnerSideIndex);
  }

  void _endFight() {
    bool lowestWins =
        _revealedCard?.lowestTotalGPowerWins(
          leftPrintedGPower: _leftBattlePrintedGPower,
          rightPrintedGPower: _rightBattlePrintedGPower,
        ) ??
        false;

    if (lowestWins) {
      if (_leftCurrentGPower < _rightCurrentGPower) {
        _showWinnerScreen(0);
        return;
      }
      if (_rightCurrentGPower < _leftCurrentGPower) {
        _showWinnerScreen(1);
        return;
      }
    } else {
      if (_leftCurrentGPower > _rightCurrentGPower) {
        _showWinnerScreen(0);
        return;
      }
      if (_rightCurrentGPower > _leftCurrentGPower) {
        _showWinnerScreen(1);
        return;
      }
    }

    unawaited(_showTieResult());
  }

  @override
  void dispose() {
    _stopPowerTickLoop();
    _battleMusicCompleteSub?.cancel();
    _cardNameController.dispose();
    _cardNameFocusNode.dispose();
    _powerAnimationController.dispose();
    _powerStartPlayer.dispose();
    _countTickPlayer.dispose();
    _revealSfxPlayer.dispose();
    _currentBattleMusicAsset = null;
    _battleMusicPlayer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canEndFight = _revealedCard != null && !_isResolvingCard;
    final hasWinner = _winnerSideIndex != null || _isTieResult;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Image.asset('assets/images/menu-2.png', fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black38)),
          if (hasWinner)
            _buildWinnerScreen()
          else
            Stack(
              children: [
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Center(child: _buildGateCardArea()),
                Positioned(
                  left: 50,
                  top: 0,
                  bottom: 0,
                  child: _buildSide(true),
                ),
                Positioned(
                  right: 50,
                  top: 0,
                  bottom: 0,
                  child: _buildSide(false),
                ),
                if (_revealedCard != null &&
                    ((_revealedCard!.descriptionEn?.trim().isNotEmpty ??
                            false) ||
                        (_revealedCard!.descriptionEs?.trim().isNotEmpty ??
                            false)))
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 170,
                    child: Center(
                      child: _buildGateDescriptionPanel(_revealedCard!),
                    ),
                  ),
                if (canEndFight)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 28,
                    child: Center(
                      child: BakuganButton(
                        text: 'END BRAWL',
                        onPressed: _endFight,
                        width: 300,
                        height: 70,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWinnerScreen() {
    if (_isTieResult) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _returnToMatch,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(
                  begin: const Offset(-1.2, 0),
                  end: Offset.zero,
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, offset, child) {
                  return Transform.translate(
                    offset: Offset(offset.dx * 480, 0),
                    child: child,
                  );
                },
                child: const Text(
                  'TIE!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 2,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(4, 4),
                        blurRadius: 10,
                      ),
                      Shadow(color: Colors.white24, blurRadius: 28),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: 560,
                height: 560,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, child) {
                    final flashOpacity = (1 - (progress * 2 - 1).abs()).clamp(
                      0.0,
                      1.0,
                    );
                    final showAnverse = progress >= 0.5;
                    final imagePath = showAnverse
                        ? 'assets/images/cards/anverse.png'
                        : (_revealedCard?.imagePath ??
                              'assets/images/cards/anverse.png');
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: lerpDouble(1.05, 1.0, progress) ?? 1.0,
                          child: InteractiveCard(
                            key: ValueKey('tie_gate_$imagePath'),
                            imagePath: imagePath,
                            onTap: () {},
                          ),
                        ),
                        IgnorePointer(
                          child: Opacity(
                            opacity: flashOpacity.toDouble(),
                            child: Container(
                              width: _gateCardWidth,
                              height: _gateCardHeight,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 50,
                                    spreadRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    final winnerIsLeft = _winnerSideIndex == 0;
    final winnerPlayer = winnerIsLeft ? widget.leftPlayer : widget.rightPlayer;
    final winnerBakugan = winnerIsLeft
        ? widget.leftBakugan
        : widget.rightBakugan;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _returnToMatch,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<Offset>(
              tween: Tween<Offset>(
                begin: const Offset(-1.2, 0),
                end: Offset.zero,
              ),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, offset, child) {
                return Transform.translate(
                  offset: Offset(offset.dx * 480, 0),
                  child: child,
                );
              },
              child: Text(
                '${winnerPlayer.name} WINS!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 2,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(4, 4),
                      blurRadius: 10,
                    ),
                    Shadow(color: Colors.white24, blurRadius: 28),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 560,
              height: 560,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: _abilityPresentationWidth,
                    height: _abilityPresentationHeight,
                    child: _buildBattlePreviewArea(
                      isLeft: winnerIsLeft,
                      variant: winnerBakugan,
                      focusedAbilityCard: null,
                      showAbilityPresentation: false,
                      showAbilityFlash: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGateCardArea() {
    return SizedBox(
      width: 460,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_winnerText != null)
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white54),
              ),
              child: Text(
                _winnerText!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedScale(
                scale: 1.06,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _revealedCard == null
                        ? InteractiveCard(
                            key: const ValueKey('anverse_card'),
                            imagePath: 'assets/images/cards/anverse.png',
                            onTap: _openGateCardPrompt,
                          )
                        : InteractiveCard(
                            key: ValueKey(
                              'revealed_${_revealedCard!.key}_${_revealedCard!.imagePath}',
                            ),
                            imagePath: _revealedCard!.imagePath,
                            onTap:
                                () {}, // o null si prefieres que no haga nada al click
                          ),
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _showRevealFlash ? 1 : 0,
                        duration: const Duration(milliseconds: 160),
                        child: Container(
                          width: _gateCardWidth,
                          height: _gateCardHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.white,
                                blurRadius: 50,
                                spreadRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingGateCards)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGateDescriptionPanel(GateCard card) {
    return _buildLocalizedDescriptionPanel(
      width: 700,
      title: card.name,
      esText: card.descriptionEs ?? card.descriptionEn ?? '',
      maxHeight: 132,
      frameGradient: _gateDescriptionGradient(card.cardClass),
      accentColor: _gateDescriptionAccentColor(card.cardClass),
    );
  }

  Widget _buildSide(bool isLeft) {
    final variant = isLeft ? widget.leftBakugan : widget.rightBakugan;
    final player = isLeft ? widget.leftPlayer : widget.rightPlayer;
    final currentGPower = isLeft ? _leftCurrentGPower : _rightCurrentGPower;
    final abilitySlots = isLeft ? _leftAbilitySlots : _rightAbilitySlots;
    final focusedAbilityCard = isLeft
        ? _focusedLeftAbilityCard
        : _focusedRightAbilityCard;
    final showAbilityPresentation = isLeft
        ? _showLeftAbilityPresentation
        : _showRightAbilityPresentation;
    final showAbilityFlash = isLeft
        ? _showLeftAbilityFlash
        : _showRightAbilityFlash;
    final pendingAbilityBonus = abilitySlots
        .whereType<MatchPresentedAbility>()
        .where((slot) => slot.isActive)
        .fold<int>(
          0,
          (sum, slot) =>
              sum +
              slot.card.calculateBonus(
                isLeft ? widget.leftBakugan : widget.rightBakugan,
              ),
        );
    final canPresentAbility =
        !_areAbilityCardsForbidden && !_isLoadingAbilityCards && !_isResolvingCard;

    return SizedBox(
      width: 600,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Text(
            player.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 42,
              letterSpacing: 10,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              shadows: [Shadow(blurRadius: 20, color: Colors.blueAccent)],
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _areAbilityCardsForbidden
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 98,
                    child: _buildAbilitySlot(
                      isLeft: isLeft,
                      abilitySlots: abilitySlots,
                      focusedAbilityCard: focusedAbilityCard,
                      showAbilityPresentation: showAbilityPresentation,
                      canPresent: canPresentAbility,
                    ),
                  ),
          ),
          const Spacer(),
          SizedBox(
            width: _abilityPresentationWidth,
            height: _abilityPresentationHeight,
            child: _buildBattlePreviewArea(
              isLeft: isLeft,
              variant: variant,
              focusedAbilityCard: focusedAbilityCard,
              showAbilityPresentation: showAbilityPresentation,
              showAbilityFlash: showAbilityFlash,
            ),
          ),
          const Spacer(),
          _AnimatedBattleGPowerBadge(
            gPower: currentGPower,
            bonusDelta: isLeft ? _leftFloatingBonus : _rightFloatingBonus,
            pendingBonusDelta:
                !_areAbilityCardsForbidden &&
                    _revealedCard == null &&
                    pendingAbilityBonus > 0
                ? pendingAbilityBonus
                : null,
            attribute: variant.attribute,
            themeColor: variant.color,
            alignLeft: isLeft,
            animationValue: _powerAnimationController.value,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBattlePreviewArea({
    required bool isLeft,
    required BakuganVariant variant,
    required AbilityCard? focusedAbilityCard,
    required bool showAbilityPresentation,
    required bool showAbilityFlash,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: showAbilityPresentation ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          child: SizedBox(
            key: ValueKey(
              'battle_arena_${isLeft ? 'L' : 'R'}_${variant.modelPath}',
            ),
            width: 500,
            height: 500,
            child: BakuganPreview(
              variant: variant,
              isLarge: true,
              autoRotate: false,
              theta: isLeft ? -40 : 40,
              phi: 75,
              disableInteraction: true,
              speciesName: variant.speciesName,
              showGPower: false,
              mirrorImage: isLeft,
            ),
          ),
        ),
        IgnorePointer(
          ignoring: !showAbilityPresentation || focusedAbilityCard == null,
          child: AnimatedOpacity(
            opacity: showAbilityPresentation && focusedAbilityCard != null
                ? 1
                : 0,
            duration: const Duration(milliseconds: 220),
            child: focusedAbilityCard == null
                ? const SizedBox.shrink()
                : _buildAbilityPresentationPanel(
                    key: ValueKey(
                      'ability_panel_${isLeft ? 'L' : 'R'}_${focusedAbilityCard.key}',
                    ),
                    isLeft: isLeft,
                    card: focusedAbilityCard,
                    showFlash: showAbilityFlash,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAbilityPresentationPanel({
    required Key key,
    required bool isLeft,
    required AbilityCard card,
    required bool showFlash,
  }) {
    return SizedBox(
      key: key,
      width: _abilityPresentationWidth,
      height: _abilityPresentationHeight,
      child: Center(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _abilityPresentationCardHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    InteractiveCard(
                      imagePath: card.imagePath,
                      width: _gateCardWidth * _abilityPresentationCardScale,
                      onTap: () => _dismissAbilityPresentation(isLeft),
                    ),
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: showFlash ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          width: _gateCardWidth * _abilityPresentationCardScale,
                          height:
                              _gateCardHeight * _abilityPresentationCardScale,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.white,
                                blurRadius: 34,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _abilityPresentationGap),
              _buildAbilityOverlayDescription(card, isLeft: isLeft),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbilityOverlayDescription(AbilityCard card, {required bool isLeft}) {
    final hasDescription =
        (card.descriptionEn?.trim().isNotEmpty ?? false) ||
        (card.descriptionEs?.trim().isNotEmpty ?? false);

    if (!hasDescription) return const SizedBox.shrink();

    return _buildLocalizedDescriptionPanel(
      width: 550,
      title: card.name,
      esText: card.descriptionEs ?? card.descriptionEn ?? '',
      maxHeight: 260,
      frameGradient: _abilityDescriptionGradient(card.cardClass),
      accentColor: _abilityDescriptionAccentColor(card.cardClass),
      headerAction: DescriptionHeaderActionButton(
        accentColor: _abilityDescriptionAccentColor(card.cardClass),
        onTap: () => _returnFocusedBattleAbilityToUnusedPile(isLeft),
      ),
    );
  }

  List<Color> _abilityDescriptionGradient(String cardClass) {
    return _abilityDescriptionBorderGradients[cardClass] ??
        _abilityDescriptionBorderGradients['blue']!;
  }

  List<Color> _gateDescriptionGradient(String cardClass) {
    return _gateDescriptionBorderGradients[cardClass] ??
        _gateDescriptionBorderGradients['silver']!;
  }

  Color _abilityDescriptionAccentColor(String cardClass) {
    return _abilityDescriptionAccentColors[cardClass] ??
        _abilityDescriptionAccentColors['blue']!;
  }

  Color _gateDescriptionAccentColor(String cardClass) {
    return _gateDescriptionAccentColors[cardClass] ??
        _gateDescriptionAccentColors['silver']!;
  }

  Widget _buildLocalizedDescriptionPanel({
    required double width,
    required String esText,
    required double maxHeight,
    required List<Color> frameGradient,
    required Color accentColor,
    String? title,
    Widget? headerAction,
  }) {
    return FramedDescriptionPanel(
      width: width,
      title: title,
      esText: esText,
      maxHeight: maxHeight,
      frameGradient: frameGradient,
      accentColor: accentColor,
      headerAction: headerAction,
    );
  }

  Widget _buildAbilitySlot({
    required bool isLeft,
    required List<MatchPresentedAbility?> abilitySlots,
    required AbilityCard? focusedAbilityCard,
    required bool showAbilityPresentation,
    required bool canPresent,
  }) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final presented = abilitySlots[index];
            final hasCard = presented != null;

            final isHidden =
                hasCard &&
                showAbilityPresentation &&
                focusedAbilityCard == presented.card;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: isHidden ? 0 : 102,
              margin: EdgeInsets.symmetric(horizontal: isHidden ? 0 : 6),
              child: IgnorePointer(
                ignoring: isHidden,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isHidden ? 0 : 1,
                  child: Align(
                    alignment: Alignment.center,
                    child: hasCard
                        ? AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: presented.isActive ? 1.0 : 0.45,
                            child: InteractiveCard(
                              key: ValueKey(
                                'battle_${isLeft ? 'L' : 'R'}_${index}_${presented.card.key}',
                              ),
                              imagePath: presented.card.imagePath,
                              width: 90,
                              onTap: () => _showAbilityPresentation(
                                isLeft,
                                slotIndex: index,
                              ),
                            ),
                          )
                        : Opacity(
                            opacity: canPresent ? 1.0 : 0.4,
                            child: IgnorePointer(
                              ignoring: !canPresent,
                              child: InteractiveCard(
                                key: ValueKey(
                                  'battle_anverse_${isLeft ? 'L' : 'R'}_$index',
                                ),
                                imagePath: 'assets/images/cards/anverse.png',
                                width: 90,
                                onTap: () => _openAbilityCardPrompt(isLeft),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _AnimatedBattleGPowerBadge extends StatelessWidget {
  final int gPower;
  final int? bonusDelta;
  final int? pendingBonusDelta;
  final String attribute;
  final Color themeColor;
  final bool alignLeft;
  final double animationValue;

  const _AnimatedBattleGPowerBadge({
    required this.gPower,
    required this.bonusDelta,
    required this.pendingBonusDelta,
    required this.attribute,
    required this.themeColor,
    required this.alignLeft,
    required this.animationValue,
  });

  @override
  Widget build(BuildContext context) {
    final showBonus = bonusDelta != null && bonusDelta! > 0;
    final risePhase = Curves.easeOut.transform(
      (animationValue / 0.22).clamp(0.0, 1.0),
    );
    final fallPhase = Curves.easeIn.transform(
      ((animationValue - 0.82) / 0.18).clamp(0.0, 1.0),
    );
    final verticalOffset =
        lerpDouble(_battleBonusRiseStart, 0, risePhase)! + (10 * fallPhase);
    final fadeInPhase = Curves.easeOut.transform(
      (animationValue / 0.22).clamp(0.0, 1.0),
    );
    final fadeOutPhase = Curves.easeIn.transform(
      ((animationValue - 0.78) / 0.22).clamp(0.0, 1.0),
    );
    final opacity = showBonus ? fadeInPhase * (1 - fadeOutPhase) : 0.0;
    final showPending = pendingBonusDelta != null && pendingBonusDelta! > 0;

    return SizedBox(
      width: 360,
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
        children: [
          Align(
            alignment: alignLeft ? Alignment.bottomLeft : Alignment.bottomRight,
            child: GPowerBadge(
              key: ValueKey('g_power_$attribute$gPower'),
              gPower: gPower,
              attribute: attribute,
              themeColor: themeColor,
            ),
          ),
          if (showBonus)
            IgnorePointer(
              child: Opacity(
                opacity: opacity,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Transform.translate(
                    offset: _battleBonusAnchor + Offset(0, verticalOffset),
                    child: Text(
                      '+$bonusDelta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        shadows: [
                          Shadow(
                            color: themeColor.withValues(alpha: 0.9),
                            blurRadius: 18,
                          ),
                          const Shadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (showPending)
            IgnorePointer(
              child: Align(
                alignment: Alignment.topRight,
                child: Transform.translate(
                  offset: _battleBonusAnchor + _battlePendingBonusOffset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 6,
                    ),
                    child: Text(
                      '+$pendingBonusDelta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        shadows: [
                          Shadow(
                            color: themeColor.withValues(alpha: 0.9),
                            blurRadius: 18,
                          ),
                          const Shadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
