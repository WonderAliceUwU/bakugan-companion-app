part of '../../main.dart';

class BattleArenaScreen extends StatefulWidget {
  final PlayerData leftPlayer;
  final PlayerData rightPlayer;
  final List<PlayerData> matchPlayers;
  final int leftPlayerIndex;
  final int rightPlayerIndex;
  final int leftBakuganDeckIndex;
  final int rightBakuganDeckIndex;
  final BakuganVariant leftBakugan;
  final BakuganVariant rightBakugan;
  final int usedGateCardsInAllPiles;
  final int leftUsedGateCards;
  final int rightUsedGateCards;
  final List<List<MatchPresentedAbility?>> presentedMatchAbilities;
  final List<int> leftUnusedBakuganIndices;
  final List<int> rightUnusedBakuganIndices;
  final List<int> leftUsedBakuganIndices;
  final List<int> rightUsedBakuganIndices;
  final Map<int, List<int>> usedBakuganIndicesByPlayer;

  const BattleArenaScreen({
    super.key,
    required this.leftPlayer,
    required this.rightPlayer,
    required this.matchPlayers,
    required this.leftPlayerIndex,
    required this.rightPlayerIndex,
    required this.leftBakuganDeckIndex,
    required this.rightBakuganDeckIndex,
    required this.leftBakugan,
    required this.rightBakugan,
    required this.presentedMatchAbilities,
    this.leftUnusedBakuganIndices = const [],
    this.rightUnusedBakuganIndices = const [],
    this.leftUsedBakuganIndices = const [],
    this.rightUsedBakuganIndices = const [],
    this.usedBakuganIndicesByPlayer = const {},
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
  bool _showBattleBackground = false;
  late BakuganVariant _leftBattleBakugan;
  late BakuganVariant _rightBattleBakugan;
  late int _leftBattleBakuganIndex;
  late int _rightBattleBakuganIndex;
  String? _leftPendingPreyasPrimaryAttribute;
  String? _rightPendingPreyasPrimaryAttribute;
  Completer<void>? _leftPreyasChoiceCompleter;
  Completer<void>? _rightPreyasChoiceCompleter;
  List<int> _leftReplacementOptions = const [];
  List<int> _rightReplacementOptions = const [];
  bool _showLeftReplacementChooser = false;
  bool _showRightReplacementChooser = false;
  bool _showLeftNoUnusedNotice = false;
  bool _showRightNoUnusedNotice = false;
  bool _showLeftGateBonusSuppressedFeedback = false;
  bool _showRightGateBonusSuppressedFeedback = false;
  int? _gateOwnerMatchPlayerIndex;
  Completer<int?>? _leftReplacementCompleter;
  Completer<int?>? _rightReplacementCompleter;
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

  BakuganVariant get _leftBakuganVariant => _leftBattleBakugan;
  BakuganVariant get _rightBakuganVariant => _rightBattleBakugan;
  bool get _isAwaitingAnyPreyasChoice =>
      _leftPendingPreyasPrimaryAttribute != null ||
      _rightPendingPreyasPrimaryAttribute != null;

  @override
  void initState() {
    super.initState();
    _leftBattleBakugan = widget.leftBakugan;
    _rightBattleBakugan = widget.rightBakugan;
    _leftBattleBakuganIndex = widget.leftBakuganDeckIndex;
    _rightBattleBakuganIndex = widget.rightBakuganDeckIndex;
    _leftCurrentGPower = _leftBattleBakugan.gPower;
    _rightCurrentGPower = _rightBattleBakugan.gPower;
    _leftTargetGPower = _leftCurrentGPower;
    _rightTargetGPower = _rightCurrentGPower;
    _leftBattlePrintedGPower = _leftBattleBakugan.gPower;
    _rightBattlePrintedGPower = _rightBattleBakugan.gPower;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showBattleBackground = true;
      });
      unawaited(_resolveInitialPreyasChoices());
    });
    _startBattleMusic();
    _loadBattleCards();
  }

  bool _isPreyasDiablo(BakuganVariant variant) =>
      variant.speciesName.trim().toLowerCase() == 'preyas diablo';

  String? _preyasDiabloPrimaryAttribute(BakuganVariant variant) {
    if (!_isPreyasDiablo(variant)) return null;
    final attribute = variant.attribute.trim().toLowerCase();
    if (attribute.isEmpty || attribute == 'pyrus') return null;
    return attribute;
  }

  Color _colorForAttribute(String attribute) {
    switch (attribute.toLowerCase()) {
      case 'pyrus':
        return Colors.red;
      case 'aquos':
        return Colors.blue;
      case 'subterra':
        return Colors.brown;
      case 'haos':
        return Colors.limeAccent;
      case 'darkus':
        return Colors.deepPurple;
      case 'ventus':
        return Colors.teal;
      default:
        return Colors.white70;
    }
  }

  BakuganVariant _variantWithBattleAttribute(
    BakuganVariant variant,
    String attribute,
  ) {
    return BakuganVariant(
      attribute: attribute.toLowerCase(),
      modelPath: variant.modelPath,
      color: _colorForAttribute(attribute),
      gPower: variant.gPower,
      speciesName: variant.speciesName,
    );
  }

  Future<void> _resolveInitialPreyasChoices() async {
    await Future.wait<void>([
      _queuePreyasDiabloChoiceIfNeeded(
        isLeft: true,
        variant: widget.leftBakugan,
      ),
      _queuePreyasDiabloChoiceIfNeeded(
        isLeft: false,
        variant: widget.rightBakugan,
      ),
    ]);
  }

  Future<void> _queuePreyasDiabloChoiceIfNeeded({
    required bool isLeft,
    required BakuganVariant variant,
  }) async {
    final primaryAttribute = _preyasDiabloPrimaryAttribute(variant);
    if (primaryAttribute == null) {
      if (!mounted) return;
      setState(() {
        if (isLeft) {
          _leftBattleBakugan = variant;
          _leftBattlePrintedGPower = variant.gPower;
          _leftPendingPreyasPrimaryAttribute = null;
        } else {
          _rightBattleBakugan = variant;
          _rightBattlePrintedGPower = variant.gPower;
          _rightPendingPreyasPrimaryAttribute = null;
        }
      });
      return;
    }

    final completer = Completer<void>();
    if (!mounted) return;
    setState(() {
      if (isLeft) {
        _leftBattleBakugan = variant;
        _leftBattlePrintedGPower = variant.gPower;
        _leftPendingPreyasPrimaryAttribute = primaryAttribute;
        _leftPreyasChoiceCompleter = completer;
      } else {
        _rightBattleBakugan = variant;
        _rightBattlePrintedGPower = variant.gPower;
        _rightPendingPreyasPrimaryAttribute = primaryAttribute;
        _rightPreyasChoiceCompleter = completer;
      }
    });

    await completer.future;
  }

  Future<void> _selectPreyasDiabloAttribute({
    required bool isLeft,
    required String attribute,
  }) async {
    await _playBattleRevealSfx('select_2.wav');
    if (!mounted) return;

    setState(() {
      if (isLeft) {
        _leftBattleBakugan = _variantWithBattleAttribute(
          _leftBattleBakugan,
          attribute,
        );
        _leftBattlePrintedGPower = _leftBattleBakugan.gPower;
        _leftCurrentGPower = _leftBattleBakugan.gPower;
        _leftTargetGPower = _leftCurrentGPower;
        _leftAnimationStartGPower = _leftCurrentGPower;
        _leftPendingPreyasPrimaryAttribute = null;
        _leftPreyasChoiceCompleter?.complete();
        _leftPreyasChoiceCompleter = null;
      } else {
        _rightBattleBakugan = _variantWithBattleAttribute(
          _rightBattleBakugan,
          attribute,
        );
        _rightBattlePrintedGPower = _rightBattleBakugan.gPower;
        _rightCurrentGPower = _rightBattleBakugan.gPower;
        _rightTargetGPower = _rightCurrentGPower;
        _rightAnimationStartGPower = _rightCurrentGPower;
        _rightPendingPreyasPrimaryAttribute = null;
        _rightPreyasChoiceCompleter?.complete();
        _rightPreyasChoiceCompleter = null;
      }
    });
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

  Future<int?> _promptGateOwnerSelection(GateCard card) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 24,
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(-0.10),
            child: Container(
              width: 560,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.34),
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.26),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Container(
                  color: const Color(0xFF05080D),
                  padding: const EdgeInsets.all(24),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.skewX(0.10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WHO OWNS THIS GATE CARD?',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          card.name.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: widget.matchPlayers.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final player = widget.matchPlayers[index];
                              final isBattlingPlayer =
                                  index == widget.leftPlayerIndex ||
                                  index == widget.rightPlayerIndex;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Navigator.of(context).pop(index),
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.skewX(-0.10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isBattlingPlayer
                                            ? Colors.white70
                                            : Colors.white24,
                                        width: 1.6,
                                      ),
                                    ),
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.skewX(0.10),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 54,
                                            height: 54,
                                            child: CharacterMiniature(
                                              char: player.character,
                                              isSelected: isBattlingPlayer,
                                              showName: false,
                                              glowAlpha: 0.45,
                                              thickness: 4,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              player.name.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
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
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  GateCardBonusBreakdown _gateBreakdownFor(bool isLeft) {
    final card = _revealedCard;
    if (card == null) {
      return GateCardBonusBreakdown(baseBonus: 0);
    }

    final variant = isLeft ? _leftBakuganVariant : _rightBakuganVariant;
    final slots = isLeft ? _leftAbilitySlots : _rightAbilitySlots;
    final ownerUsedAbilityCards = slots
        .whereType<MatchPresentedAbility>()
        .where((slot) => !slot.isActive)
        .length;
    final hasResolvedAttributeBonus = _hasResolvedAttributeBonusContext(
      isLeft,
      variant,
    );

    final breakdown = card.bonusBreakdownFor(
      variant,
      usedGateCardsInAllPiles: widget.usedGateCardsInAllPiles,
      ownerUsedAbilityCards: ownerUsedAbilityCards,
      ownerUsedGateCards: isLeft
          ? widget.leftUsedGateCards
          : widget.rightUsedGateCards,
      opponentUsedGateCards: isLeft
          ? widget.rightUsedGateCards
          : widget.leftUsedGateCards,
      ownerHasAttributeBonusContext: hasResolvedAttributeBonus,
      teamBakugans: isLeft ? widget.leftPlayer.deck : widget.rightPlayer.deck,
    );

    if (_shouldSuppressLowestPrintedGateBonus(isLeft, card, variant)) {
      return GateCardBonusBreakdown(
        baseBonus: 0,
        effectBonusSegments: breakdown.effectBonusSegments,
      );
    }

    return breakdown;
  }

  bool _shouldSuppressLowestPrintedGateBonus(
    bool isLeft,
    GateCard card,
    BakuganVariant variant,
  ) {
    final hasEffect = card.effects.any(
      (effect) =>
          effect is Map &&
          effect['type'] == 'lowest_lose_bonus_if_owner_has_attribute',
    );
    if (!hasEffect) return false;

    final ownerIndex = _gateOwnerMatchPlayerIndex;
    if (ownerIndex == null) return false;

    final ownPrinted = isLeft
        ? _leftBattlePrintedGPower
        : _rightBattlePrintedGPower;
    final opponentPrinted = isLeft
        ? _rightBattlePrintedGPower
        : _leftBattlePrintedGPower;
    if (ownPrinted >= opponentPrinted) {
      return false;
    }

    if (ownerIndex < 0 || ownerIndex >= widget.matchPlayers.length) {
      return false;
    }

    final deck = widget.matchPlayers[ownerIndex].deck;
    final attribute = variant.attribute.toLowerCase();

    return deck.any((bakugan) => bakugan.attribute.toLowerCase() == attribute);
  }

  Future<void> _showSuppressedGateBonusFeedback({
    required bool leftSuppressed,
    required bool rightSuppressed,
  }) async {
    if (!leftSuppressed && !rightSuppressed) return;

    await _playGPowerSwapSound();
    if (!mounted) return;
    setState(() {
      _showLeftGateBonusSuppressedFeedback = leftSuppressed;
      _showRightGateBonusSuppressedFeedback = rightSuppressed;
    });
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() {
      _showLeftGateBonusSuppressedFeedback = false;
      _showRightGateBonusSuppressedFeedback = false;
    });
  }

  int _abilityBonusFor(bool isLeft, BakuganVariant variant) {
    if (_areAbilityCardsForbidden) return 0;
    final slots = isLeft ? _leftAbilitySlots : _rightAbilitySlots;
    return slots.whereType<MatchPresentedAbility>().fold<int>(
      0,
      (sum, slot) => sum + slot.card.calculateBonus(variant),
    );
  }

  int _appliedAbilityBonusFor(bool isLeft, BakuganVariant variant) {
    if (_areAbilityCardsForbidden) return 0;
    final slots = isLeft ? _leftAbilitySlots : _rightAbilitySlots;
    final appliedSlots = isLeft
        ? _leftAppliedAbilitySlots
        : _rightAppliedAbilitySlots;
    return appliedSlots.fold<int>(0, (sum, index) {
      if (index < 0 || index >= slots.length) return sum;
      final slot = slots[index];
      if (slot == null) return sum;
      return sum + slot.card.calculateBonus(variant);
    });
  }

  bool _hasResolvedAttributeBonusContext(bool isLeft, BakuganVariant variant) {
    final card = _revealedCard;
    if (card == null) return false;

    final baseBonus = card.bonusFor(variant.attribute);
    if (baseBonus > 0) return true;

    if (_appliedAbilityBonusFor(isLeft, variant) > 0) {
      return true;
    }

    final currentGPower = isLeft ? _leftCurrentGPower : _rightCurrentGPower;
    final printedGPower = isLeft
        ? _leftBattlePrintedGPower
        : _rightBattlePrintedGPower;
    return currentGPower > printedGPower + baseBonus;
  }

  Future<void> _recalculateBattleTotals({
    bool includeGateBonuses = true,
  }) async {
    final leftTarget =
        _leftBattlePrintedGPower +
        (includeGateBonuses ? _gateBreakdownFor(true).totalBonus : 0) +
        _abilityBonusFor(true, _leftBakuganVariant);
    final rightTarget =
        _rightBattlePrintedGPower +
        (includeGateBonuses ? _gateBreakdownFor(false).totalBonus : 0) +
        _abilityBonusFor(false, _rightBakuganVariant);

    await _animatePowerChange(leftTarget: leftTarget, rightTarget: rightTarget);
  }

  Future<void> _applyDeferredGateEffectBonusesIfNeeded() async {
    final leftTarget =
        _leftBattlePrintedGPower +
        _gateBreakdownFor(true).totalBonus +
        _abilityBonusFor(true, _leftBakuganVariant);
    final rightTarget =
        _rightBattlePrintedGPower +
        _gateBreakdownFor(false).totalBonus +
        _abilityBonusFor(false, _rightBakuganVariant);

    if (leftTarget == _leftCurrentGPower &&
        rightTarget == _rightCurrentGPower) {
      return;
    }

    final leftBonus = leftTarget - _leftCurrentGPower;
    final rightBonus = rightTarget - _rightCurrentGPower;
    await _animatePowerChange(
      leftTarget: leftTarget,
      rightTarget: rightTarget,
      leftBonus: leftBonus > 0 ? leftBonus : null,
      rightBonus: rightBonus > 0 ? rightBonus : null,
    );
  }

  Future<void> _flashNoUnusedNotice(bool isLeft) async {
    setState(() {
      if (isLeft) {
        _showLeftNoUnusedNotice = true;
      } else {
        _showRightNoUnusedNotice = true;
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      if (isLeft) {
        _showLeftNoUnusedNotice = false;
      } else {
        _showRightNoUnusedNotice = false;
      }
    });
  }

  Future<void> _handleGateReplacementEffect() async {
    final leftOptions = widget.leftUnusedBakuganIndices
        .where((index) => index != _leftBattleBakuganIndex)
        .toList();
    final rightOptions = widget.rightUnusedBakuganIndices
        .where((index) => index != _rightBattleBakuganIndex)
        .toList();

    if (leftOptions.isEmpty) {
      unawaited(_flashNoUnusedNotice(true));
    }
    if (rightOptions.isEmpty) {
      unawaited(_flashNoUnusedNotice(false));
    }
    if (leftOptions.isEmpty && rightOptions.isEmpty) {
      return;
    }

    _leftReplacementCompleter = leftOptions.isNotEmpty
        ? Completer<int?>()
        : null;
    _rightReplacementCompleter = rightOptions.isNotEmpty
        ? Completer<int?>()
        : null;

    setState(() {
      _leftReplacementOptions = leftOptions;
      _rightReplacementOptions = rightOptions;
      _showLeftReplacementChooser = leftOptions.isNotEmpty;
      _showRightReplacementChooser = rightOptions.isNotEmpty;
      _showLeftAbilityPresentation = false;
      _showRightAbilityPresentation = false;
    });

    _leftReplacementCompleter?.future.then((chosenIndex) {
      if (!mounted || chosenIndex == null) return;
      setState(() {
        _leftBattleBakuganIndex = chosenIndex;
        _leftBattleBakugan = widget.leftPlayer.deck[chosenIndex];
        _leftBattlePrintedGPower = _leftBattleBakugan.gPower;
        _showLeftReplacementChooser = false;
        _leftReplacementOptions = const [];
        _leftReplacementCompleter = null;
      });
    });
    _rightReplacementCompleter?.future.then((chosenIndex) {
      if (!mounted || chosenIndex == null) return;
      setState(() {
        _rightBattleBakuganIndex = chosenIndex;
        _rightBattleBakugan = widget.rightPlayer.deck[chosenIndex];
        _rightBattlePrintedGPower = _rightBattleBakugan.gPower;
        _showRightReplacementChooser = false;
        _rightReplacementOptions = const [];
        _rightReplacementCompleter = null;
      });
    });

    final results = await Future.wait<int?>([
      _leftReplacementCompleter?.future ?? Future<int?>.value(null),
      _rightReplacementCompleter?.future ?? Future<int?>.value(null),
    ]);
    if (!mounted) return;
    final leftChosenIndex = results[0];
    final rightChosenIndex = results[1];
    if (leftChosenIndex == null && rightChosenIndex == null) {
      setState(() {
        _showLeftReplacementChooser = false;
        _showRightReplacementChooser = false;
        _leftReplacementOptions = const [];
        _rightReplacementOptions = const [];
        _leftReplacementCompleter = null;
        _rightReplacementCompleter = null;
      });
    }

    if (leftChosenIndex != null) {
      await _queuePreyasDiabloChoiceIfNeeded(
        isLeft: true,
        variant: widget.leftPlayer.deck[leftChosenIndex],
      );
    }
    if (rightChosenIndex != null) {
      await _queuePreyasDiabloChoiceIfNeeded(
        isLeft: false,
        variant: widget.rightPlayer.deck[rightChosenIndex],
      );
    }

    await _recalculateBattleTotals(includeGateBonuses: false);
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
    if (_isAwaitingAnyPreyasChoice ||
        _isLoadingGateCards ||
        _isResolvingCard ||
        _revealedCard != null) {
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
    if (_isAwaitingAnyPreyasChoice ||
        _isLoadingAbilityCards ||
        _isResolvingCard) {
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
                                        ? _leftBakuganVariant
                                        : _rightBakuganVariant,
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

    try {
      await precacheImage(AssetImage(card.imagePath), context);
    } catch (_) {}
    _playBattleRevealSfx('gate_reveal.wav');
    _stopPowerTickLoop();
    _powerAnimationController.stop();

    setState(() {
      _winnerText = null;
      _revealedCard = card;
      _gateOwnerMatchPlayerIndex = null;
      _showRevealFlash = true;
      _leftCurrentGPower = _leftBakuganVariant.gPower;
      _rightCurrentGPower = _rightBakuganVariant.gPower;
      _leftTargetGPower = _leftCurrentGPower;
      _rightTargetGPower = _rightCurrentGPower;
      _leftBattlePrintedGPower = _leftBakuganVariant.gPower;
      _rightBattlePrintedGPower = _rightBakuganVariant.gPower;
      _areAbilityCardsForbidden = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    setState(() {
      _showRevealFlash = false;
    });

    if (card.requiresOwnerSelection) {
      final ownerIndex = await _promptGateOwnerSelection(card);
      if (!mounted || ownerIndex == null) return;
      setState(() {
        _gateOwnerMatchPlayerIndex = ownerIndex;
      });
    }

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

    if (card.effects.any(
      (effect) =>
          effect is Map &&
          effect['type'] == 'replace_battling_bakugan_with_unused',
    )) {
      await _handleGateReplacementEffect();
      if (!mounted) return;
    }

    final leftBreakdown = _gateBreakdownFor(true);
    final rightBreakdown = _gateBreakdownFor(false);
    final leftSuppressedGateBonus =
        card.bonusFor(_leftBakuganVariant.attribute) > 0 &&
        leftBreakdown.baseBonus == 0 &&
        _shouldSuppressLowestPrintedGateBonus(true, card, _leftBakuganVariant);
    final rightSuppressedGateBonus =
        card.bonusFor(_rightBakuganVariant.attribute) > 0 &&
        rightBreakdown.baseBonus == 0 &&
        _shouldSuppressLowestPrintedGateBonus(
          false,
          card,
          _rightBakuganVariant,
        );

    await _showSuppressedGateBonusFeedback(
      leftSuppressed: leftSuppressedGateBonus,
      rightSuppressed: rightSuppressedGateBonus,
    );
    if (!mounted) return;

    final leftBaseBonus = leftBreakdown.baseBonus;
    final rightBaseBonus = rightBreakdown.baseBonus;
    if (leftBaseBonus > 0 || rightBaseBonus > 0) {
      await _animatePowerChange(
        leftTarget: _leftCurrentGPower + leftBaseBonus,
        rightTarget: _rightCurrentGPower + rightBaseBonus,
        leftBonus: leftBaseBonus > 0 ? leftBaseBonus : null,
        rightBonus: rightBaseBonus > 0 ? rightBaseBonus : null,
      );
    }

    final leftEffectSegments = leftBreakdown.effectBonusSegments;
    final rightEffectSegments = rightBreakdown.effectBonusSegments;
    final maxEffectSegments = max(
      leftEffectSegments.length,
      rightEffectSegments.length,
    );

    for (int i = 0; i < maxEffectSegments; i++) {
      final leftSegment = i < leftEffectSegments.length
          ? leftEffectSegments[i]
          : 0;
      final rightSegment = i < rightEffectSegments.length
          ? rightEffectSegments[i]
          : 0;

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
      isLeft ? _leftBakuganVariant : _rightBakuganVariant,
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
    if (_isResolvingCard ||
        _revealedCard == null ||
        _areAbilityCardsForbidden) {
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
        leftBonus += slot.card.calculateBonus(_leftBakuganVariant);
        newlyAppliedLeft.add(i);
      }
    }

    for (int i = 0; i < _rightAbilitySlots.length; i++) {
      final slot = _rightAbilitySlots[i];
      if (slot != null &&
          slot.isActive &&
          !_rightAppliedAbilitySlots.contains(i)) {
        rightBonus += slot.card.calculateBonus(_rightBakuganVariant);
        newlyAppliedRight.add(i);
      }
    }

    if (newlyAppliedLeft.isEmpty && newlyAppliedRight.isEmpty) {
      return;
    }

    if (leftBonus <= 0 && rightBonus <= 0) {
      setState(() {
        _leftAppliedAbilitySlots.addAll(newlyAppliedLeft);
        _rightAppliedAbilitySlots.addAll(newlyAppliedRight);
      });

      await _applyDeferredGateEffectBonusesIfNeeded();
      return;
    }

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
    });

    await _applyDeferredGateEffectBonusesIfNeeded();
  }

  void _markResolvedBattleAbilitiesAsUsed() {
    for (final i in _leftAppliedAbilitySlots) {
      if (i < 0 || i >= _leftAbilitySlots.length) continue;
      final slot = _leftAbilitySlots[i];
      if (slot != null && slot.isActive) {
        _leftAbilitySlots[i] = slot.copyWith(isActive: false);
      }
    }

    for (final i in _rightAppliedAbilitySlots) {
      if (i < 0 || i >= _rightAbilitySlots.length) continue;
      final slot = _rightAbilitySlots[i];
      if (slot != null && slot.isActive) {
        _rightAbilitySlots[i] = slot.copyWith(isActive: false);
      }
    }
  }

  void _returnBattlingPlayersAbilityCardsToUnused() {
    for (int i = 0; i < _leftAbilitySlots.length; i++) {
      _leftAbilitySlots[i] = null;
    }
    for (int i = 0; i < _rightAbilitySlots.length; i++) {
      _rightAbilitySlots[i] = null;
    }
    _leftAppliedAbilitySlots.clear();
    _rightAppliedAbilitySlots.clear();
    _focusedLeftAbilitySlotIndex = null;
    _focusedRightAbilitySlotIndex = null;
    _showLeftAbilityPresentation = false;
    _showRightAbilityPresentation = false;
    _showLeftAbilityFlash = false;
    _showRightAbilityFlash = false;
  }

  void _finalizeBattleAbilitySlots() {
    if (_revealedCard?.returnsAllUsedAbilityCards ?? false) {
      _returnBattlingPlayersAbilityCardsToUnused();
      return;
    }
    _markResolvedBattleAbilitiesAsUsed();
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

  Future<void> _returnToMatch() async {
    if ((_winnerSideIndex == null && !_isTieResult) || _hasReturnedToMatch) {
      return;
    }
    _hasReturnedToMatch = true;
    if (mounted) {
      setState(() {
        _finalizeBattleAbilitySlots();
        _showBattleBackground = false;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    Navigator.of(context).pop({
      'winnerIndex': _winnerSideIndex,
      'leftBakuganIndex': _leftBattleBakuganIndex,
      'rightBakuganIndex': _rightBattleBakuganIndex,
    });
  }

  Future<void> _closeBattle() async {
    if (_hasReturnedToMatch) return;
    _hasReturnedToMatch = true;
    if (mounted) {
      setState(() {
        _finalizeBattleAbilitySlots();
        _showBattleBackground = false;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    Navigator.of(context).pop({
      'winnerIndex': null,
      'leftBakuganIndex': _leftBattleBakuganIndex,
      'rightBakuganIndex': _rightBattleBakuganIndex,
    });
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
    final hasWinner = _winnerSideIndex != null || _isTieResult;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              opacity: _showBattleBackground ? 1 : 0,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Image.asset(
                  'assets/images/menu-2.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              opacity: _showBattleBackground ? 1 : 0,
              child: Container(color: Colors.black38),
            ),
          ),
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
                    onPressed: () {
                      _playBattleRevealSfx('cancel.wav');
                      _closeBattle();
                    },
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
        ? _leftBakuganVariant
        : _rightBakuganVariant;

    return BattleResultShowcase(
      title: '${winnerPlayer.name} WINS!',
      onTap: _returnToMatch,
      previewChild: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: _abilityPresentationWidth,
            height: _abilityPresentationHeight,
            child: _buildBattlePreviewArea(
              isLeft: winnerIsLeft,
              variant: winnerBakugan,
              pendingPreyasPrimaryAttribute: null,
              focusedAbilityCard: null,
              showAbilityPresentation: false,
              showAbilityFlash: false,
            ),
          ),
        ],
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
                            onTap: !_isResolvingCard ? _endFight : null,
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
    final variant = isLeft ? _leftBakuganVariant : _rightBakuganVariant;
    final pendingPreyasPrimaryAttribute = isLeft
        ? _leftPendingPreyasPrimaryAttribute
        : _rightPendingPreyasPrimaryAttribute;
    final isAwaitingPreyasChoice = pendingPreyasPrimaryAttribute != null;
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
                isLeft ? _leftBakuganVariant : _rightBakuganVariant,
              ),
        );
    final canPresentAbility =
        !isAwaitingPreyasChoice &&
        !_areAbilityCardsForbidden &&
        !_isLoadingAbilityCards &&
        !_isResolvingCard;

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
              pendingPreyasPrimaryAttribute: pendingPreyasPrimaryAttribute,
              focusedAbilityCard: focusedAbilityCard,
              showAbilityPresentation: showAbilityPresentation,
              showAbilityFlash: showAbilityFlash,
            ),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isAwaitingPreyasChoice
                ? _buildPendingPreyasBadge(
                    isLeft: isLeft,
                    primaryAttribute: pendingPreyasPrimaryAttribute,
                  )
                : _AnimatedBattleGPowerBadge(
                    key: ValueKey(
                      'battle_g_${isLeft ? 'L' : 'R'}_${variant.attribute}',
                    ),
                    gPower: currentGPower,
                    bonusDelta: isLeft
                        ? _leftFloatingBonus
                        : _rightFloatingBonus,
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
                    rumble: isLeft
                        ? _showLeftGateBonusSuppressedFeedback
                        : _showRightGateBonusSuppressedFeedback,
                  ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBattlePreviewArea({
    required bool isLeft,
    required BakuganVariant variant,
    required String? pendingPreyasPrimaryAttribute,
    required AbilityCard? focusedAbilityCard,
    required bool showAbilityPresentation,
    required bool showAbilityFlash,
  }) {
    final replacementOptions = isLeft
        ? _leftReplacementOptions
        : _rightReplacementOptions;
    final showReplacementChooser = isLeft
        ? _showLeftReplacementChooser
        : _showRightReplacementChooser;
    final showNoUnusedNotice = isLeft
        ? _showLeftNoUnusedNotice
        : _showRightNoUnusedNotice;
    final showPreyasChooser = pendingPreyasPrimaryAttribute != null;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity:
              showAbilityPresentation ||
                  showReplacementChooser ||
                  showPreyasChooser
              ? 0
              : 1,
          duration: const Duration(milliseconds: 220),
          child: SizedBox(
            key: ValueKey(
              'battle_arena_${isLeft ? 'L' : 'R'}_${variant.modelPath}_${variant.attribute}',
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
          ignoring: !showPreyasChooser,
          child: AnimatedOpacity(
            opacity: showPreyasChooser ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: showPreyasChooser
                ? _buildPreyasDiabloAttributeChooser(
                    isLeft: isLeft,
                    variant: variant,
                    primaryAttribute: pendingPreyasPrimaryAttribute,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        IgnorePointer(
          ignoring: !showReplacementChooser,
          child: AnimatedOpacity(
            opacity: showReplacementChooser ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: showReplacementChooser
                ? _buildReplacementChooser(
                    isLeft: isLeft,
                    replacementOptions: replacementOptions,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        IgnorePointer(
          ignoring: true,
          child: AnimatedOpacity(
            opacity: showNoUnusedNotice ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white38),
              ),
              child: const Text(
                'NO UNUSED BAKUGAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
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

  Widget _buildReplacementChooser({
    required bool isLeft,
    required List<int> replacementOptions,
  }) {
    final player = isLeft ? widget.leftPlayer : widget.rightPlayer;
    final List<Color> idleGradient = [
      Colors.blueAccent,
      Colors.cyan,
      Colors.blue.shade900,
    ];
    return Container(
      width: _abilityPresentationWidth,
      height: _abilityPresentationHeight,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'CHOOSE UNUSED BAKUGAN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
              shrinkWrap: true,
              itemCount: replacementOptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final deckIndex = replacementOptions[index];
                final variant = player.deck[deckIndex];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final completer = isLeft
                        ? _leftReplacementCompleter
                        : _rightReplacementCompleter;
                    if (completer != null && !completer.isCompleted) {
                      completer.complete(deckIndex);
                    }
                  },
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.skewX(-0.12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.44),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.skewX(0.12),
                        child: Row(
                          children: [
                            Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.skewX(-0.15),
                              child: Container(
                                width: 116,
                                height: 116,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: idleGradient,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: idleGradient.first.withValues(
                                        alpha: 0.34,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.skewX(0.15),
                                    child: IgnorePointer(
                                      child: BakuganPreview(
                                        variant: variant,
                                        isDeck: true,
                                        disableInteraction: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Text(
                                variant.speciesName.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreyasDiabloAttributeChooser({
    required bool isLeft,
    required BakuganVariant variant,
    required String? primaryAttribute,
  }) {
    if (primaryAttribute == null) return const SizedBox.shrink();

    final choices = <String>[primaryAttribute, 'pyrus'];
    final accent = variant.color;

    return Container(
      width: _abilityPresentationWidth,
      height: _abilityPresentationHeight,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'PREYAS DIABLO',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontStyle: FontStyle.italic,
                shadows: [Shadow(color: accent, blurRadius: 20)],
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: choices
                  .map(
                    (attribute) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: attribute == choices.first ? 10 : 0,
                          left: attribute == choices.last ? 10 : 0,
                        ),
                        child: _buildPreyasChoiceCard(
                          attribute: attribute,
                          isPrimary: attribute == primaryAttribute,
                          onTap: () => _selectPreyasDiabloAttribute(
                            isLeft: isLeft,
                            attribute: attribute,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreyasChoiceCard({
    required String attribute,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final attributeColor = _colorForAttribute(attribute);
    final label = attribute.toUpperCase();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.12),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                attributeColor.withValues(alpha: 0.95),
                attributeColor.withValues(alpha: 0.45),
                Colors.black,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: attributeColor.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF050505),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(0.12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GridPainter(
                          color: attributeColor.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth,
                                  maxHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 96,
                                      height: 96,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.white,
                                            attributeColor.withValues(
                                              alpha: 0.88,
                                            ),
                                            Colors.black,
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: Image.asset(
                                        'assets/images/attributes/${attribute}_game.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        fontStyle: FontStyle.italic,
                                        letterSpacing: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isPrimary ? 'PRIMARY FORM' : 'PYRUS FORM',
                                      style: TextStyle(
                                        color: attributeColor.withValues(
                                          alpha: 0.95,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPreyasBadge({
    required bool isLeft,
    required String? primaryAttribute,
  }) {
    final accent = _colorForAttribute(primaryAttribute ?? 'pyrus');
    return SizedBox(
      key: ValueKey('preyas_pending_${isLeft ? 'L' : 'R'}_$primaryAttribute'),
      width: 360,
      height: 150,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.72), width: 2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.28),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            'SELECT FORM',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              fontStyle: FontStyle.italic,
              shadows: [Shadow(color: accent, blurRadius: 18)],
            ),
          ),
        ),
      ),
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

  Widget _buildAbilityOverlayDescription(
    AbilityCard card, {
    required bool isLeft,
  }) {
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
  final bool rumble;

  const _AnimatedBattleGPowerBadge({
    super.key,
    required this.gPower,
    required this.bonusDelta,
    required this.pendingBonusDelta,
    required this.attribute,
    required this.themeColor,
    required this.alignLeft,
    required this.animationValue,
    required this.rumble,
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

    final badge = SizedBox(
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

    if (!rumble) {
      return badge;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (context, value, child) {
        final wobble = sin(value * pi * 10) * 8 * (1 - value);
        return Transform.translate(offset: Offset(wobble, 0), child: child);
      },
      child: badge,
    );
  }
}
