part of '../../main.dart';

enum MatchBakuganPileState { unused, standing, used }

class ScoreboardScreen extends StatefulWidget {
  final List<PlayerData> players;
  final bool isTeamBattle;

  const ScoreboardScreen({
    super.key,
    required this.players,
    required this.isTeamBattle,
  });

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  late List<int> scores;
  late AudioPlayer _sfxPlayer;
  final AudioPlayer _arenaPlayerA = AudioPlayer();
  final AudioPlayer _arenaPlayerB = AudioPlayer();
  final TextEditingController _matchCardNameController =
      TextEditingController();
  final FocusNode _matchCardNameFocusNode = FocusNode();
  Map<String, AbilityCard> _matchAbilityCards = {};
  bool _isLoadingMatchAbilityCards = true;
  List<String> _arenaPlaylist = const [];
  int _currentArenaTrackIndex = 0;
  int _currentArenaTrackLoopCount = 0;
  bool _isArenaMuted = false;
  bool _useArenaPlayerA = true;
  bool _isArenaCrossfading = false;
  AbilityCard? _focusedMatchAbilityCard;
  int? _focusedMatchAbilityPlayerIndex;
  int? _focusedMatchAbilityIndex;
  late List<List<MatchPresentedAbility?>> _presentedMatchAbilities;
  late List<List<MatchBakuganPileState>> _bakuganPileStates;
  late List<List<int?>> _bakuganStandOrder;
  int _nextStandOrder = 1;
  bool _isPauseMenuOpen = false;
  int? _matchWinnerIndex;
  String? _bakuganStayBannerText;
  int? _bakuganStayPlayerIndex;
  int? _bakuganStayBakuganIndex;
  bool _isResolvingBakuganStay = false;

  bool selectionMode = false;
  BakuganVariant? leftBakugan;
  BakuganVariant? rightBakugan;
  PlayerData? leftPlayer;
  PlayerData? rightPlayer;
  int? leftBakuganIdx;
  int? rightBakuganIdx;

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer();
    scores = widget.isTeamBattle
        ? [0, 0]
        : List.filled(widget.players.length, 0);
    _presentedMatchAbilities = List.generate(
      widget.players.length,
      (_) => List<MatchPresentedAbility?>.filled(3, null),
    );
    _bakuganPileStates = List.generate(
      widget.players.length,
      (playerIndex) => List<MatchBakuganPileState>.generate(
        3,
        (slotIndex) => slotIndex < widget.players[playerIndex].deck.length
            ? MatchBakuganPileState.unused
            : MatchBakuganPileState.used,
      ),
    );
    _bakuganStandOrder = List.generate(
      widget.players.length,
      (_) => List<int?>.filled(3, null),
    );
    _loadMatchAbilityCards();
    _loadArenaPlaylistAndStart();
  }

  AudioPlayer get _activeArenaPlayer =>
      _useArenaPlayerA ? _arenaPlayerA : _arenaPlayerB;

  AudioPlayer get _inactiveArenaPlayer =>
      _useArenaPlayerA ? _arenaPlayerB : _arenaPlayerA;

  Future<void> _loadArenaPlaylistAndStart() async {
    try {
      await _bgMusicPlayer.stop();
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );
      final tracks =
          manifest
              .listAssets()
              .where(
                (asset) =>
                    asset.startsWith('assets/music/arena/') &&
                    asset.endsWith('.flac') &&
                    !asset.endsWith('.DS_Store'),
              )
              .toList()
            ..sort();
      _arenaPlaylist = tracks.isNotEmpty
          ? tracks
          : const ['assets/music/arena/arena-1.flac'];
      _arenaPlayerA.onPlayerComplete.listen((_) {
        if (_useArenaPlayerA) {
          _handleArenaTrackComplete();
        }
      });
      _arenaPlayerB.onPlayerComplete.listen((_) {
        if (!_useArenaPlayerA) {
          _handleArenaTrackComplete();
        }
      });
      await _playArenaTrack(0, immediate: true);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _setArenaPlayerVolume(AudioPlayer player, double volume) async {
    try {
      await player.setVolume(_isArenaMuted ? 0 : volume);
    } catch (_) {}
  }

  Future<void> _playArenaTrack(int index, {bool immediate = false}) async {
    if (_arenaPlaylist.isEmpty || _isArenaCrossfading) return;
    final normalizedIndex =
        (index % _arenaPlaylist.length + _arenaPlaylist.length) %
        _arenaPlaylist.length;
    final nextTrack = _arenaPlaylist[normalizedIndex];
    final nextPlayer = immediate ? _activeArenaPlayer : _inactiveArenaPlayer;
    final currentPlayer = _activeArenaPlayer;

    try {
      _isArenaCrossfading = true;
      await nextPlayer.stop();
      await nextPlayer.setReleaseMode(ReleaseMode.stop);
      await _setArenaPlayerVolume(nextPlayer, 0);
      await nextPlayer.play(AssetSource(nextTrack.replaceFirst('assets/', '')));

      if (immediate) {
        _currentArenaTrackIndex = normalizedIndex;
        _currentArenaTrackLoopCount = 0;
        await _setArenaPlayerVolume(nextPlayer, 0.4);
        _isArenaCrossfading = false;
        if (mounted) setState(() {});
        return;
      }

      const steps = 12;
      for (int step = 1; step <= steps; step++) {
        final t = step / steps;
        await _setArenaPlayerVolume(nextPlayer, 0.4 * t);
        await _setArenaPlayerVolume(currentPlayer, 0.4 * (1 - t));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      await currentPlayer.stop();
      _useArenaPlayerA = !_useArenaPlayerA;
      _currentArenaTrackIndex = normalizedIndex;
      _currentArenaTrackLoopCount = 0;
      _isArenaCrossfading = false;
      if (mounted) setState(() {});
    } catch (_) {
      _isArenaCrossfading = false;
    }
  }

  Future<void> _handleArenaTrackComplete() async {
    if (_currentArenaTrackLoopCount == 0) {
      _currentArenaTrackLoopCount = 1;
      final activeTrack = _arenaPlaylist[_currentArenaTrackIndex];
      try {
        await _activeArenaPlayer.stop();
        await _activeArenaPlayer.play(
          AssetSource(activeTrack.replaceFirst('assets/', '')),
        );
        await _setArenaPlayerVolume(_activeArenaPlayer, 0.4);
      } catch (_) {}
      if (mounted) setState(() {});
      return;
    }
    await _playArenaTrack(_currentArenaTrackIndex + 1);
  }

  Future<void> _pauseArenaPlaylist() async {
    try {
      await _arenaPlayerA.pause();
      await _arenaPlayerB.pause();
    } catch (_) {}
  }

  Future<void> _resumeArenaPlaylist() async {
    try {
      await _activeArenaPlayer.resume();
      await _setArenaPlayerVolume(_activeArenaPlayer, 0.4);
    } catch (_) {}
  }

  Future<void> _toggleArenaMute() async {
    setState(() => _isArenaMuted = !_isArenaMuted);
    await _setArenaPlayerVolume(_arenaPlayerA, _useArenaPlayerA ? 0.4 : 0);
    await _setArenaPlayerVolume(_arenaPlayerB, _useArenaPlayerA ? 0 : 0.4);
  }

  Future<void> _playMatchWinSound() async {
    try {
      await _arenaPlayerA.stop();
      await _arenaPlayerB.stop();
      await _bgMusicPlayer.stop();
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sound/win_match.flac'));
    } catch (_) {}
  }

  Future<void> _playRevealSfx(String assetName) async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sound/$assetName'));
    } catch (_) {}
  }

  Future<void> _loadMatchAbilityCards() async {
    try {
      final String rawJson = await rootBundle.loadString(
        'assets/images/cards/cards.json',
      );
      final decodedJson = jsonDecode(rawJson);
      if (decodedJson is! Map) return;
      final decoded = Map<String, dynamic>.from(decodedJson);
      final cardsNode = decoded['cards'];
      if (cardsNode is! Map) return;

      final cards = Map<String, dynamic>.from(cardsNode);
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest
          .listAssets()
          .where(
            (asset) =>
                asset.startsWith('assets/images/cards/') &&
                asset != 'assets/images/cards/anverse.png' &&
                asset.endsWith('.png'),
          )
          .toList();

      final Map<String, AbilityCard> loadedAbilityCards = {};
      for (final entry in cards.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is! Map) continue;
        final data = Map<String, dynamic>.from(value);
        if ((data['type'] ?? '').toString().trim().toLowerCase() != 'ability') {
          continue;
        }

        final String name = (data['name'] ?? '').toString().trim();
        final String? fileName = data['file']?.toString();
        final String cardClass = (data['card_class'] ?? 'blue')
            .toString()
            .toLowerCase();
        final descriptionsRaw = data['descriptions'];
        final Map<String, dynamic> descriptions =
            descriptionsRaw is Map<String, dynamic>
            ? descriptionsRaw
            : descriptionsRaw is Map
            ? Map<String, dynamic>.from(descriptionsRaw)
            : const {};
        final String? descriptionEn = descriptions['en']?.toString();
        final String? descriptionEs = descriptions['es']?.toString();
        final attributesRaw = data['attributes'];
        final Map<String, int> attributes = <String, int>{};
        if (attributesRaw is Map) {
          for (final attrEntry in attributesRaw.entries) {
            final attrKey = attrEntry.key.toString().toLowerCase();
            final attrValue = attrEntry.value;
            if (attrValue is num) {
              attributes[attrKey] = attrValue.toInt();
            }
          }
        }
        final effectsRaw = data['effects'];
        final List<dynamic> effects = effectsRaw is List
            ? List<dynamic>.from(effectsRaw)
            : const [];
        final rulesRaw = data['rules'];
        final List<dynamic> rules = rulesRaw is List
            ? List<dynamic>.from(rulesRaw)
            : const [];
        final Set<String> timings = <String>{};
        final timingsRaw = data['timings'];
        if (timingsRaw is List) {
          for (final timing in timingsRaw) {
            timings.add(timing.toString().toLowerCase());
          }
        }
        for (final rule in rules) {
          if (rule is Map && rule['timing'] != null) {
            timings.add(rule['timing'].toString().toLowerCase());
          }
        }
        for (final effect in effects) {
          if (effect is Map && effect['timing'] != null) {
            timings.add(effect['timing'].toString().toLowerCase());
          }
        }

        final imagePath = _matchCardImagePath(
          cardKey: key,
          cardName: name,
          assetPaths: assets,
          fileName: fileName,
        );
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
      }

      if (!mounted) return;
      setState(() {
        _matchAbilityCards = loadedAbilityCards;
        _isLoadingMatchAbilityCards = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMatchAbilityCards = false;
      });
    }
  }

  bool _isMatchStageAbilityCard(AbilityCard card) {
    return card.isMatchStageCard;
  }

  List<AbilityCard> _rankMatchAbilityCardMatches(String input) {
    final query = _normalizeCardLookup(input);
    if (query.isEmpty) {
      return _matchAbilityCards.values
          .where(_isMatchStageAbilityCard)
          .take(8)
          .toList();
    }

    final ranked =
        _matchAbilityCards.values
            .where(_isMatchStageAbilityCard)
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
          ..sort((a, b) => b.score.compareTo(a.score));
    return ranked.map((entry) => entry.card).toList();
  }

  AbilityCard? _findMatchAbilityCard(String input) {
    final query = _normalizeCardLookup(input);
    if (query.isEmpty) return null;
    final matches = _rankMatchAbilityCardMatches(input);
    if (matches.isEmpty) return null;
    final topMatch = matches.first;
    final topName = _normalizeCardLookup(topMatch.name);
    final topKey = _normalizeCardLookup(topMatch.key);
    if (topName == query || topKey == query) {
      return topMatch;
    }
    return null;
  }

  Future<void> _openMatchAbilityPrompt(int playerIndex, int slotIndex) async {
    if (_isLoadingMatchAbilityCards || selectionMode) return;
    if (_presentedMatchAbilities[playerIndex][slotIndex] != null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    _matchCardNameController.clear();

    final selectedCard = await showDialog<AbilityCard>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final match = _findMatchAbilityCard(
                _matchCardNameController.text,
              );
              if (match == null) {
                setDialogState(() {
                  errorText =
                      'Ability card not found or not available outside battle.';
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
                width: 540,
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
                      'Present Match Ability',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose an ability card with no battle timing to stage it on the match screen.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 20),
                    RawAutocomplete<AbilityCard>(
                      textEditingController: _matchCardNameController,
                      focusNode: _matchCardNameFocusNode,
                      displayStringForOption: (option) => option.name,
                      optionsBuilder: (textEditingValue) {
                        return _rankMatchAbilityCardMatches(
                          textEditingValue.text,
                        );
                      },
                      onSelected: (option) => Navigator.of(context).pop(option),
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              autofocus: true,
                              onChanged: (_) {
                                if (errorText != null) {
                                  setDialogState(() => errorText = null);
                                }
                              },
                              onSubmitted: (_) => submit(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Example: Marucho\'s Throw',
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
                        if (matches.isEmpty) return const SizedBox.shrink();
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            color: const Color(0xFF171B22),
                            elevation: 12,
                            borderRadius: BorderRadius.circular(16),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 540,
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
                                                alpha: 0.55,
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
      _presentMatchAbility(playerIndex, slotIndex, selectedCard);
    }
  }

  void _presentMatchAbility(int playerIndex, int slotIndex, AbilityCard card) {
    if (_presentedMatchAbilities[playerIndex][slotIndex] != null) return;

    _playRevealSfx('ability_reveal.wav');

    setState(() {
      _presentedMatchAbilities[playerIndex][slotIndex] = MatchPresentedAbility(
        card: card,
      );
      _focusedMatchAbilityCard = card;
      _focusedMatchAbilityPlayerIndex = playerIndex;
      _focusedMatchAbilityIndex = slotIndex;
    });
  }

  void _focusPresentedAbility(int playerIndex, int abilityIndex) {
    final presented = _presentedMatchAbilities[playerIndex][abilityIndex];
    if (presented == null) return;

    setState(() {
      _focusedMatchAbilityCard = presented.card;
      _focusedMatchAbilityPlayerIndex = playerIndex;
      _focusedMatchAbilityIndex = abilityIndex;
    });
  }

  void _togglePresentedAbility(int playerIndex, int abilityIndex) {
    final current = _presentedMatchAbilities[playerIndex][abilityIndex];
    if (current == null) return;

    setState(() {
      _presentedMatchAbilities[playerIndex][abilityIndex] = current.copyWith(
        isActive: !current.isActive,
      );
    });
  }

  void _returnFocusedMatchAbilityToUnusedPile() {
    final playerIndex = _focusedMatchAbilityPlayerIndex;
    final abilityIndex = _focusedMatchAbilityIndex;
    if (playerIndex == null || abilityIndex == null) return;

    setState(() {
      _presentedMatchAbilities[playerIndex][abilityIndex] = null;
      _focusedMatchAbilityCard = null;
      _focusedMatchAbilityPlayerIndex = null;
      _focusedMatchAbilityIndex = null;
    });
  }

  Widget _buildArenaPlaylistBar() {
    final trackLabel = _arenaPlaylist.isEmpty
        ? 'LOADING...'
        : _arenaPlaylist[_currentArenaTrackIndex]
              .split('/')
              .last
              .replaceAll('.flac', '')
              .replaceAll('-', ' ')
              .toUpperCase();

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(-0.12),
          child: Container(
            width: 600,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(0.12),
              child: Row(
                children: [
                  _buildPlaylistIconButton(
                    icon: Icons.skip_previous,
                    onTap: () => _playArenaTrack(_currentArenaTrackIndex - 1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ARENA PLAYLIST',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          trackLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildPlaylistIconButton(
                    icon: _isArenaMuted ? Icons.volume_off : Icons.volume_up,
                    onTap: _toggleArenaMute,
                  ),
                  const SizedBox(width: 10),
                  _buildPlaylistIconButton(
                    icon: Icons.skip_next,
                    onTap: () => _playArenaTrack(_currentArenaTrackIndex + 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildMatchAbilityOverlay() {
    final card = _focusedMatchAbilityCard;
    if (card == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InteractiveCard(
                  imagePath: card.imagePath,
                  width: 380,
                  onTap: () {
                    setState(() {
                      _focusedMatchAbilityCard = null;
                      _focusedMatchAbilityPlayerIndex = null;
                      _focusedMatchAbilityIndex = null;
                    });
                  },
                ),
                const SizedBox(height: 46),
                _buildMatchAbilityDescriptionPanel(card),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchAbilityDescriptionPanel(AbilityCard card) {
    final hasDescription =
        (card.descriptionEn?.trim().isNotEmpty ?? false) ||
        (card.descriptionEs?.trim().isNotEmpty ?? false);
    if (!hasDescription) return const SizedBox.shrink();

    final accentColor =
        _abilityDescriptionAccentColors[card.cardClass] ??
        _abilityDescriptionAccentColors['blue']!;

    return FramedDescriptionPanel(
      width: 620,
      title: card.name,
      esText: card.descriptionEs ?? card.descriptionEn ?? '',
      maxHeight: 300,
      frameGradient:
          _abilityDescriptionBorderGradients[card.cardClass] ??
          _abilityDescriptionBorderGradients['blue']!,
      accentColor: accentColor,
      headerAction: DescriptionHeaderActionButton(
        accentColor: accentColor,
        onTap: _returnFocusedMatchAbilityToUnusedPile,
      ),
    );
  }

  Widget _buildProfileAbilityRail(int playerIndex, {required bool alignRight}) {
    final abilities = _presentedMatchAbilities[playerIndex];
    const int maxSlots = 3;

    return SizedBox(
      width: 530,
      height: 104,
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
          children: List.generate(maxSlots, (index) {
            final presented = abilities[index];
            final hasCard = presented != null;

            final isHidden =
                hasCard &&
                _focusedMatchAbilityCard != null &&
                _focusedMatchAbilityPlayerIndex == playerIndex &&
                _focusedMatchAbilityIndex == index;

            final isDisabled = _isLoadingMatchAbilityCards || selectionMode;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              width: isHidden ? 0 : 90,
              height: 90,
              margin: EdgeInsets.symmetric(
                horizontal: isHidden ? 0 : _matchAbilityRailSpacing / 2,
              ),
              child: IgnorePointer(
                ignoring: isHidden,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  opacity: isHidden ? 0 : 1,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    scale: isHidden ? 0.86 : 1,
                    child: hasCard
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () =>
                                _togglePresentedAbility(playerIndex, index),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: presented.isActive ? 1.0 : 0.48,
                              child: Align(
                                alignment: Alignment.center,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 320),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    final rotate = Tween<double>(
                                      begin: pi / 2,
                                      end: 0,
                                    ).animate(animation);

                                    return AnimatedBuilder(
                                      animation: rotate,
                                      child: child,
                                      builder: (context, child) {
                                        return Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.identity()
                                            ..setEntry(3, 2, 0.0015)
                                            ..rotateY(rotate.value),
                                          child: child,
                                        );
                                      },
                                    );
                                  },
                                  child: InteractiveCard(
                                    key: ValueKey(
                                      'ability_${playerIndex}_${index}_${presented.card.key}',
                                    ),
                                    imagePath: presented.card.imagePath,
                                    width: 90,
                                    onTap: () => _focusPresentedAbility(
                                      playerIndex,
                                      index,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Opacity(
                            opacity: isDisabled ? 0.4 : 1.0,
                            child: IgnorePointer(
                              ignoring: isDisabled,
                              child: InteractiveCard(
                                key: ValueKey('anverse_${playerIndex}_$index'),
                                imagePath: 'assets/images/cards/anverse.png',
                                width: 90,
                                onTap: () =>
                                    _openMatchAbilityPrompt(playerIndex, index),
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

  Widget? _buildProfileAbilityOverlay(int playerIndex, {required bool above}) {
    if (selectionMode) {
      return null;
    }
    final alignRight = playerIndex.isOdd;
    final showStayButton = _canUseBakuganStay(playerIndex);

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProfileAbilityRail(playerIndex, alignRight: alignRight),
          if (showStayButton) ...[
            const SizedBox(width: 14),
            SizedBox(
              width: 150,
              height: 74,
              child: BakuganButton(
                text: 'STAY',
                onPressed: () => _triggerBakuganStay(playerIndex),
                color: const Color(0xFFF2DDAF),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBakuganStayOverlay() {
    final text = _bakuganStayBannerText;
    final playerIndex = _bakuganStayPlayerIndex;
    final bakuganIndex = _bakuganStayBakuganIndex;
    if (text == null || playerIndex == null || bakuganIndex == null) {
      return const SizedBox.shrink();
    }

    final player = widget.players[playerIndex];
    if (bakuganIndex >= player.deck.length) {
      return const SizedBox.shrink();
    }
    final variant = player.deck[bakuganIndex];
    final isMirrored = playerIndex.isOdd;
    final title = "${player.name.toUpperCase()} STAYS!";

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          child: BattleResultShowcase(
            title: title,
            previewChild: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: _abilityPresentationWidth,
                  height: _abilityPresentationHeight,
                  child: Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 500,
                      height: 500,
                      child: BakuganPreview(
                        variant: variant,
                        isLarge: true,
                        autoRotate: false,
                        theta: isMirrored ? 40 : -40,
                        phi: 75,
                        disableInteraction: true,
                        speciesName: variant.speciesName,
                        showGPower: false,
                        mirrorImage: isMirrored,
                      ),
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

  Future<void> _playCharacterSelectMusic() async {
    try {
      await _arenaPlayerA.stop();
      await _arenaPlayerB.stop();
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.play(AssetSource('music/menu/Menu.flac'));
    } catch (_) {}
  }

  Future<void> _openPauseMenu() async {
    if (_isPauseMenuOpen) return;
    _isPauseMenuOpen = true;
    await _pauseArenaPlaylist();
    if (!mounted) return;

    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Pause Menu',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Center(
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.skewX(-0.12),
                    child: SizedBox(
                      width: 520,
                      height: 720,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF7B6330),
                              Color(0xFFE5D2A6),
                              Color(0xFF394352),
                              Color(0xFF151A22),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.65),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.12),
                              blurRadius: 34,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFF090D13),
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: GridPainter(
                                    color: Colors.cyanAccent.withValues(
                                      alpha: 0.06,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.05),
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.15),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 22,
                                  ),
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.skewX(0.12),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 360,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 84,
                                              height: 84,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Colors.blueAccent.withValues(
                                                      alpha: 0.9,
                                                    ),
                                                    Colors.cyanAccent.withValues(
                                                      alpha: 0.7,
                                                    ),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.cyanAccent
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 20,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                                border: Border.all(
                                                  color: Colors.white.withValues(
                                                    alpha: 0.75,
                                                  ),
                                                  width: 2.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.pause_rounded,
                                                color: Colors.white,
                                                size: 42,
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            const Text(
                                              'PAUSED',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 40,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 5,
                                                fontStyle: FontStyle.italic,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.blueAccent,
                                                    blurRadius: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Choose your next move',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.68,
                                                ),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.04,
                                                ),
                                                borderRadius:
                                                BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.white.withValues(
                                                    alpha: 0.09,
                                                  ),
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  BakuganButton(
                                                    text: 'Resume',
                                                    icon:
                                                    Icons.play_arrow_rounded,
                                                    iconOnly: false,
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop('resume'),
                                                    width: 340,
                                                    height: 68,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  BakuganButton(
                                                    text: 'Restart',
                                                    icon:
                                                    Icons.restart_alt_rounded,
                                                    iconOnly: false,
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop('selection'),
                                                    width: 340,
                                                    height: 68,
                                                    color: Colors.orangeAccent,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  BakuganButton(
                                                    text: 'Exit to menu',
                                                    icon: Icons.home_rounded,
                                                    iconOnly: false,
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop('main_menu'),
                                                    width: 340,
                                                    height: 68,
                                                    color: Colors.redAccent,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'ESC to resume',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.4,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.4,
                                              ),
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
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    _isPauseMenuOpen = false;
    if (!mounted) return;

    if (action == 'main_menu') {
      Navigator.of(context).pushAndRemoveUntil(
        _fadeRoute(const MainMenuScreen()),
            (route) => false,
      );
      return;
    }

    if (action == 'selection') {
      await _playCharacterSelectMusic();
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    await _resumeArenaPlaylist();
  }

  void _addPoint(int index, {bool playPointSound = true}) async {
    if (playPointSound) {
      try {
        await _sfxPlayer.stop();
        await _sfxPlayer.play(AssetSource('sound/select.wav'));
      } catch (_) {}
    }
    bool didWinMatch = false;
    setState(() {
      if (scores[index] < 3) {
        scores[index]++;
        if (scores[index] >= 3) {
          didWinMatch = true;
          _matchWinnerIndex = index;
          selectionMode = false;
          leftBakugan = null;
          rightBakugan = null;
          leftPlayer = null;
          rightPlayer = null;
          leftBakuganIdx = null;
          rightBakuganIdx = null;
        }
      }
    });
    if (didWinMatch) {
      unawaited(_recordLeaderboardMatch(index));
      await _playMatchWinSound();
    }
  }

  int _scoreIndexForPlayer(PlayerData player) {
    final playerIndex = widget.players.indexOf(player);
    if (playerIndex < 0) return 0;
    if (!widget.isTeamBattle) return playerIndex;
    return playerIndex.isEven ? 0 : 1;
  }

  Future<void> _recordLeaderboardMatch(int winningScoreIndex) async {
    if (widget.isTeamBattle) {
      final winners = winningScoreIndex == 0
          ? [widget.players[0], widget.players[2]]
          : [widget.players[1], widget.players[3]];
      final losers = winningScoreIndex == 0
          ? [widget.players[1], widget.players[3]]
          : [widget.players[0], widget.players[2]];
      await LeaderboardRepository.instance.recordMatch(
        winners: winners
            .where((player) => player.isSavedProfile)
            .map((player) => player.name)
            .toList(),
        losers: losers
            .where((player) => player.isSavedProfile)
            .map((player) => player.name)
            .toList(),
      );
      return;
    }

    final winner = widget.players[winningScoreIndex];
    final losers = [
      for (int i = 0; i < widget.players.length; i++)
        if (i != winningScoreIndex) widget.players[i],
    ];
    await LeaderboardRepository.instance.recordMatch(
      winners: winner.isSavedProfile ? [winner.name] : const [],
      losers: losers
          .where((player) => player.isSavedProfile)
          .map((player) => player.name)
          .toList(),
    );
  }

  void _playClick() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sound/select_2.wav'));
  }

  Future<void> _playBakuganStaySound() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sound/win_battle.flac'));
    } catch (_) {}
  }

  void _clearBattleSelectionForSlot(int playerIndex, int bakuganIndex) {
    final player = widget.players[playerIndex];
    if (leftPlayer == player && leftBakuganIdx == bakuganIndex) {
      leftPlayer = null;
      leftBakugan = null;
      leftBakuganIdx = null;
    }
    if (rightPlayer == player && rightBakuganIdx == bakuganIndex) {
      rightPlayer = null;
      rightBakugan = null;
      rightBakuganIdx = null;
    }
  }

  void _refreshUnusedPileIfNeeded(int playerIndex) {
    final deckLength = widget.players[playerIndex].deck.length;
    final states = _bakuganPileStates[playerIndex];
    final hasUnused = List.generate(
      deckLength,
      (index) => states[index],
    ).any((state) => state == MatchBakuganPileState.unused);
    final usedIndices = List.generate(
      deckLength,
      (index) => index,
    ).where((index) => states[index] == MatchBakuganPileState.used);

    if (hasUnused || usedIndices.isEmpty) return;

    for (final index in usedIndices) {
      states[index] = MatchBakuganPileState.unused;
      _bakuganStandOrder[playerIndex][index] = null;
    }
  }

  bool _canUseBakuganStay(int playerIndex) {
    final deckLength = widget.players[playerIndex].deck.length;
    if (deckLength < 3) return false;
    return List.generate(
      3,
      (index) => _bakuganPileStates[playerIndex][index],
    ).every((state) => state == MatchBakuganPileState.standing);
  }

  int? _oldestStandingBakuganIndex(int playerIndex) {
    int? oldestIndex;
    int? oldestOrder;
    for (int i = 0; i < min(3, widget.players[playerIndex].deck.length); i++) {
      if (_bakuganPileStates[playerIndex][i] != MatchBakuganPileState.standing) {
        continue;
      }
      final order = _bakuganStandOrder[playerIndex][i];
      if (order == null) continue;
      if (oldestOrder == null || order < oldestOrder) {
        oldestOrder = order;
        oldestIndex = i;
      }
    }
    return oldestIndex;
  }

  void _handleBakuganTap(
    PlayerData player,
    int playerIndex,
    int bakuganIndex,
    bool isMirrored,
  ) {
    if (bakuganIndex >= player.deck.length) return;
    final currentState = _bakuganPileStates[playerIndex][bakuganIndex];
    if (selectionMode) {
      if (currentState != MatchBakuganPileState.standing) return;

      _playClick();
      setState(() {
        final isLeftSelected =
            leftPlayer == player && leftBakuganIdx == bakuganIndex;
        final isRightSelected =
            rightPlayer == player && rightBakuganIdx == bakuganIndex;

        if (isLeftSelected) {
          leftPlayer = null;
          leftBakugan = null;
          leftBakuganIdx = null;
          return;
        }
        if (isRightSelected) {
          rightPlayer = null;
          rightBakugan = null;
          rightBakuganIdx = null;
          return;
        }

        if (leftPlayer == null) {
          leftPlayer = player;
          leftBakugan = player.deck[bakuganIndex];
          leftBakuganIdx = bakuganIndex;
          return;
        }
        if (rightPlayer == null) {
          rightPlayer = player;
          rightBakugan = player.deck[bakuganIndex];
          rightBakuganIdx = bakuganIndex;
          return;
        }

        leftPlayer = player;
        leftBakugan = player.deck[bakuganIndex];
        leftBakuganIdx = bakuganIndex;
      });
      return;
    }

    if (currentState != MatchBakuganPileState.unused) return;

    _playClick();
    setState(() {
      _bakuganPileStates[playerIndex][bakuganIndex] =
          MatchBakuganPileState.standing;
      _bakuganStandOrder[playerIndex][bakuganIndex] = _nextStandOrder++;
      _refreshUnusedPileIfNeeded(playerIndex);
    });
  }

  void _handleBakuganLongPress(int playerIndex, int bakuganIndex) {
    if (selectionMode) return;
    final player = widget.players[playerIndex];
    if (bakuganIndex >= player.deck.length) return;
    final currentState = _bakuganPileStates[playerIndex][bakuganIndex];

    _playClick();
    setState(() {
      _bakuganPileStates[playerIndex][bakuganIndex] =
          currentState == MatchBakuganPileState.used
          ? MatchBakuganPileState.unused
          : MatchBakuganPileState.used;
      _bakuganStandOrder[playerIndex][bakuganIndex] = null;
      _clearBattleSelectionForSlot(playerIndex, bakuganIndex);
      _refreshUnusedPileIfNeeded(playerIndex);
    });
  }

  Future<void> _triggerBakuganStay(int playerIndex) async {
    if (_isResolvingBakuganStay || _matchWinnerIndex != null) return;
    final oldestStandingIndex = _oldestStandingBakuganIndex(playerIndex);
    if (oldestStandingIndex == null) return;

    _isResolvingBakuganStay = true;
    setState(() {
      _bakuganStayBannerText = 'STAY!';
      _bakuganStayPlayerIndex = playerIndex;
      _bakuganStayBakuganIndex = oldestStandingIndex;
    });

    final soundFinished = Future.any<void>([
      _sfxPlayer.onPlayerComplete.first.then((_) {}),
      Future<void>.delayed(const Duration(seconds: 4)),
    ]);
    await _playBakuganStaySound();
    if (!mounted) return;

    await soundFinished;
    if (!mounted) return;

    setState(() {
      _bakuganPileStates[playerIndex][oldestStandingIndex] =
          MatchBakuganPileState.unused;
      _bakuganStandOrder[playerIndex][oldestStandingIndex] = null;
      _clearBattleSelectionForSlot(playerIndex, oldestStandingIndex);
    });
    _addPoint(_scoreIndexForPlayer(widget.players[playerIndex]), playPointSound: false);

    setState(() {
      _bakuganStayBannerText = null;
      _bakuganStayPlayerIndex = null;
      _bakuganStayBakuganIndex = null;
    });
    _isResolvingBakuganStay = false;
  }

  void _markBattlingBakuganUsedAndClearSelection({
    required int leftBakuganIndex,
    required int rightBakuganIndex,
  }) {
    final leftPlayerLocal = leftPlayer;
    final rightPlayerLocal = rightPlayer;
    final leftIdxLocal = leftBakuganIdx;
    final rightIdxLocal = rightBakuganIdx;

    setState(() {
      if (leftPlayerLocal != null && leftIdxLocal != null) {
        final playerIndex = widget.players.indexOf(leftPlayerLocal);
        if (playerIndex >= 0 &&
            leftIdxLocal < _bakuganPileStates[playerIndex].length) {
          _bakuganPileStates[playerIndex][leftIdxLocal] =
              MatchBakuganPileState.used;
          _bakuganStandOrder[playerIndex][leftIdxLocal] = null;
          _refreshUnusedPileIfNeeded(playerIndex);
        }
      }
      if (leftPlayerLocal != null) {
        final playerIndex = widget.players.indexOf(leftPlayerLocal);
        if (playerIndex >= 0 &&
            leftBakuganIndex < _bakuganPileStates[playerIndex].length) {
          _bakuganPileStates[playerIndex][leftBakuganIndex] =
              MatchBakuganPileState.used;
          _bakuganStandOrder[playerIndex][leftBakuganIndex] = null;
          _refreshUnusedPileIfNeeded(playerIndex);
        }
      }

      if (rightPlayerLocal != null && rightIdxLocal != null) {
        final playerIndex = widget.players.indexOf(rightPlayerLocal);
        if (playerIndex >= 0 &&
            rightIdxLocal < _bakuganPileStates[playerIndex].length) {
          _bakuganPileStates[playerIndex][rightIdxLocal] =
              MatchBakuganPileState.used;
          _bakuganStandOrder[playerIndex][rightIdxLocal] = null;
          _refreshUnusedPileIfNeeded(playerIndex);
        }
      }
      if (rightPlayerLocal != null) {
        final playerIndex = widget.players.indexOf(rightPlayerLocal);
        if (playerIndex >= 0 &&
            rightBakuganIndex < _bakuganPileStates[playerIndex].length) {
          _bakuganPileStates[playerIndex][rightBakuganIndex] =
              MatchBakuganPileState.used;
          _bakuganStandOrder[playerIndex][rightBakuganIndex] = null;
          _refreshUnusedPileIfNeeded(playerIndex);
        }
      }

      selectionMode = false;
      leftBakugan = null;
      rightBakugan = null;
      leftPlayer = null;
      rightPlayer = null;
      leftBakuganIdx = null;
      rightBakuganIdx = null;
    });
  }

  @override
  void dispose() {
    _matchCardNameController.dispose();
    _matchCardNameFocusNode.dispose();
    _arenaPlayerA.dispose();
    _arenaPlayerB.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMatchWinner = _matchWinnerIndex != null;
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.escape):
            const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<Intent>(
            onInvoke: (_) {
              _openPauseMenu();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/match-bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  _buildArenaPlaylistBar(),
                  IgnorePointer(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 600,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  blurRadius: 100,
                                  spreadRadius: 120,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (!widget.isTeamBattle) ...[
                    _buildCornerPlayer(0, Alignment.topLeft),
                    _buildCornerPlayer(1, Alignment.topRight),
                    if (widget.players.length > 2)
                      _buildCornerPlayer(2, Alignment.bottomLeft),
                    if (widget.players.length > 3)
                      _buildCornerPlayer(3, Alignment.bottomRight),
                  ] else ...[
                    // Team 1 (Left Staircase)
                    _buildTeamStaircase(0, 2, false),
                    // Team 2 (Right Staircase)
                    _buildTeamStaircase(1, 3, true),
                  ],

                  // Battle button
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selectionMode) ...[
                            BakuganButton(
                              text: 'BACK',
                              onPressed: () {
                                setState(() {
                                  selectionMode = false;
                                  leftBakugan = null;
                                  rightBakugan = null;
                                  leftPlayer = null;
                                  rightPlayer = null;
                                  leftBakuganIdx = null;
                                  rightBakuganIdx = null;
                                });
                              },
                              useCancelSound: true,
                              width: 180,
                              height: 85,
                            ),
                            const SizedBox(width: 14),
                          ],
                          BakuganButton(
                            text: !selectionMode
                                ? 'BATTLE'
                                : (leftBakugan != null && rightBakugan != null
                                      ? 'FIGHT!'
                                      : 'CHOOSE...'),
                            onPressed: () {
                              if (!selectionMode) {
                                setState(() {
                                  selectionMode = true;
                                  leftBakugan = null;
                                  rightBakugan = null;
                                  leftPlayer = null;
                                  rightPlayer = null;
                                });
                              } else if (leftBakugan != null &&
                                  rightBakugan != null) {
                                final leftPlayerIndex = widget.players.indexOf(
                                  leftPlayer!,
                                );
                                final rightPlayerIndex = widget.players.indexOf(
                                  rightPlayer!,
                                );
                                final leftScoreIndex = _scoreIndexForPlayer(
                                  leftPlayer!,
                                );
                                final rightScoreIndex = _scoreIndexForPlayer(
                                  rightPlayer!,
                                );
                                final leftUnusedBakuganIndices = List.generate(
                                  _bakuganPileStates[leftPlayerIndex].length,
                                  (index) => index,
                                ).where(
                                  (index) =>
                                      _bakuganPileStates[leftPlayerIndex][index] ==
                                          MatchBakuganPileState.unused &&
                                      index != leftBakuganIdx,
                                ).toList();
                                final rightUnusedBakuganIndices = List.generate(
                                  _bakuganPileStates[rightPlayerIndex].length,
                                  (index) => index,
                                ).where(
                                  (index) =>
                                      _bakuganPileStates[rightPlayerIndex][index] ==
                                          MatchBakuganPileState.unused &&
                                      index != rightBakuganIdx,
                                ).toList();
                                final leftUsedBakuganIndices = List.generate(
                                  _bakuganPileStates[leftPlayerIndex].length,
                                  (index) => index,
                                ).where(
                                  (index) =>
                                      _bakuganPileStates[leftPlayerIndex][index] ==
                                          MatchBakuganPileState.used &&
                                      index != leftBakuganIdx,
                                ).toList();
                                final rightUsedBakuganIndices = List.generate(
                                  _bakuganPileStates[rightPlayerIndex].length,
                                  (index) => index,
                                ).where(
                                  (index) =>
                                      _bakuganPileStates[rightPlayerIndex][index] ==
                                          MatchBakuganPileState.used &&
                                      index != rightBakuganIdx,
                                ).toList();
                                final usedBakuganIndicesByPlayer = {
                                  for (int playerIndex = 0;
                                      playerIndex < _bakuganPileStates.length;
                                      playerIndex++)
                                    playerIndex: List.generate(
                                      _bakuganPileStates[playerIndex].length,
                                      (index) => index,
                                    ).where(
                                      (index) =>
                                          _bakuganPileStates[playerIndex][index] ==
                                          MatchBakuganPileState.used,
                                    ).toList(),
                                };

                                _pauseArenaPlaylist();
                                Navigator.push(
                                  context,
                                  _fadeRoute(
                                    BattleArenaScreen(
                                      leftPlayer: leftPlayer!,
                                      rightPlayer: rightPlayer!,
                                      matchPlayers: widget.players,
                                      leftPlayerIndex: leftPlayerIndex,
                                      rightPlayerIndex: rightPlayerIndex,
                                      leftBakuganDeckIndex: leftBakuganIdx!,
                                      rightBakuganDeckIndex: rightBakuganIdx!,
                                      leftBakugan: leftBakugan!,
                                      rightBakugan: rightBakugan!,
                                      leftUnusedBakuganIndices:
                                          leftUnusedBakuganIndices,
                                      rightUnusedBakuganIndices:
                                          rightUnusedBakuganIndices,
                                      leftUsedBakuganIndices:
                                          leftUsedBakuganIndices,
                                      rightUsedBakuganIndices:
                                          rightUsedBakuganIndices,
                                      usedBakuganIndicesByPlayer:
                                          usedBakuganIndicesByPlayer,
                                      usedGateCardsInAllPiles: scores.fold(
                                        0,
                                        (sum, score) => sum + score,
                                      ),
                                      leftUsedGateCards: scores[leftScoreIndex],
                                      rightUsedGateCards:
                                          scores[rightScoreIndex],
                                      presentedMatchAbilities:
                                          _presentedMatchAbilities,
                                    ),
                                  ),
                                ).then((result) {
                                  _resumeArenaPlaylist();
                                  if (!mounted) return;
                                  final resultMap =
                                      result is Map
                                          ? Map<String, dynamic>.from(result)
                                          : const <String, dynamic>{};
                                  final int? winnerIndex =
                                      resultMap['winnerIndex'] as int?;
                                  final int leftReturnedBakuganIndex =
                                      resultMap['leftBakuganIndex'] is int
                                      ? resultMap['leftBakuganIndex'] as int
                                      : leftBakuganIdx!;
                                  final int rightReturnedBakuganIndex =
                                      resultMap['rightBakuganIndex'] is int
                                      ? resultMap['rightBakuganIndex'] as int
                                      : rightBakuganIdx!;
                                  final previousLeftPlayer = leftPlayer;
                                  final previousRightPlayer = rightPlayer;
                                  _markBattlingBakuganUsedAndClearSelection(
                                    leftBakuganIndex: leftReturnedBakuganIndex,
                                    rightBakuganIndex: rightReturnedBakuganIndex,
                                  );
                                  if (winnerIndex == null) return;
                                  final sideWinner = winnerIndex;
                                  final winningPlayer = sideWinner == 0
                                      ? previousLeftPlayer
                                      : previousRightPlayer;
                                  if (winningPlayer == null) {
                                    return;
                                  }
                                  _addPoint(
                                    _scoreIndexForPlayer(winningPlayer),
                                  );
                                });
                              }
                            },
                            color:
                                (selectionMode &&
                                    (leftBakugan == null ||
                                        rightBakugan == null))
                                ? Colors.grey
                                : null,
                            width: 300,
                            height: 85,
                          ),
                          if (!selectionMode) ...[
                            const SizedBox(width: 14),
                            BakuganButton(
                              text: '',
                              icon: Icons.pause_rounded,
                              iconOnly: true,
                              onPressed: _openPauseMenu,
                              width: 120,
                              height: 85,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  _buildMatchAbilityOverlay(),
                  _buildBakuganStayOverlay(),
                  if (hasMatchWinner) _buildMatchWinnerOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamStaircase(int p1Idx, int p2Idx, bool isMirrored) {
    return Positioned(
      top: 40,
      left: isMirrored ? null : 40,
      right: isMirrored ? 40 : null,
      child: Column(
        crossAxisAlignment: isMirrored
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Player 1
          _buildPlayerForTeam(p1Idx, isMirrored),
          const SizedBox(height: 25),
          // Player 2 (Offset for staircase)
          Padding(
            padding: EdgeInsets.only(
              left: isMirrored ? 0 : 70,
              right: isMirrored ? 70 : 0,
            ),
            child: _buildPlayerForTeam(p2Idx, isMirrored),
          ),
          const SizedBox(height: 40),
          // Team Score Ticks
          Padding(
            padding: EdgeInsets.only(
              left: isMirrored ? 0 : 130,
              right: isMirrored ? 130 : 0,
            ),
            child: _buildTicks(isMirrored ? 1 : 0),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerForTeam(int index, bool isMirrored) {
    final player = widget.players[index];
    bool isRed = (index == 1 || index == 3);
    final themeColor = isRed ? Colors.redAccent : Colors.blueAccent;

    return PlayerArenaInfo(
      player: player,
      isMirrored: isMirrored,
      themeColor: themeColor,
      isSelected: isRed,
      glowAlpha: 0.6,
      thickness: 6.0,
      isSelecting: selectionMode,
      isExpanded: selectionMode,
      selectedBakuganIndex: isMirrored
          ? (rightPlayer == player ? rightBakuganIdx : null)
          : (leftPlayer == player ? leftBakuganIdx : null),
      selectedBakuganIndices: {
        if (leftPlayer == player && leftBakuganIdx != null) leftBakuganIdx!,
        if (rightPlayer == player && rightBakuganIdx != null) rightBakuganIdx!,
      },
      onPortraitTap: null,
      portraitOverlay: _buildProfileAbilityOverlay(index, above: false),
      portraitOverlayAbove: false,
      bakuganPileStates: _bakuganPileStates[index],
      onBakuganTap: (bIdx) =>
          _handleBakuganTap(player, index, bIdx, isMirrored),
      onBakuganLongPress: (bIdx) => _handleBakuganLongPress(index, bIdx),
    );
  }

  Widget _buildCornerPlayer(int index, Alignment alignment) {
    final player = widget.players[index];
    final bool isMirrored =
        alignment == Alignment.topRight || alignment == Alignment.bottomRight;
    bool isRed = index % 2 != 0;
    final themeColor = isRed ? Colors.redAccent : Colors.blueAccent;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(35.0),
        child: PlayerArenaInfo(
          player: player,
          isMirrored: isMirrored,
          themeColor: themeColor,
          extra: !widget.isTeamBattle ? _buildTicks(index) : null,
          isSelected: isRed,
          glowAlpha: 0.6,
          thickness: 6.0,
          isSelecting: selectionMode,
          isExpanded: selectionMode,
          selectedBakuganIndex: isMirrored
              ? (rightPlayer == player ? rightBakuganIdx : null)
              : (leftPlayer == player ? leftBakuganIdx : null),
          selectedBakuganIndices: {
            if (leftPlayer == player && leftBakuganIdx != null) leftBakuganIdx!,
            if (rightPlayer == player && rightBakuganIdx != null) rightBakuganIdx!,
          },
          onPortraitTap: null,
          portraitOverlay: _buildProfileAbilityOverlay(
            index,
            above:
                alignment == Alignment.bottomLeft ||
                alignment == Alignment.bottomRight,
          ),
          portraitOverlayAbove:
              alignment == Alignment.bottomLeft ||
              alignment == Alignment.bottomRight,
          bakuganPileStates: _bakuganPileStates[index],
          onBakuganTap: (bIdx) =>
              _handleBakuganTap(player, index, bIdx, isMirrored),
          onBakuganLongPress: (bIdx) => _handleBakuganLongPress(index, bIdx),
        ),
      ),
    );
  }

  Widget _buildTicks(int playerOrTeamIndex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        bool isFilled = i < scores[playerOrTeamIndex];

        return GestureDetector(
          onTap: () => _addPoint(playerOrTeamIndex),
          behavior: HitTestBehavior.opaque,
          child: Transform(
            transform: Matrix4.skewX(-0.25),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 35,
              // Increased
              height: 55,
              // Increased
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isFilled
                      ? [
                          Colors.cyanAccent,
                          Colors.purpleAccent.withValues(alpha: 0.8),
                        ]
                      : [
                          Colors.blueGrey.withValues(alpha: 0.4),
                          Colors.black87,
                        ],
                ),
                border: Border.all(
                  color: isFilled ? Colors.cyanAccent : Colors.white10,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMatchWinnerOverlay() {
    final winnerIndex = _matchWinnerIndex!;
    final title = widget.isTeamBattle
        ? 'TEAM ${winnerIndex + 1} WON!'
        : '${widget.players[winnerIndex].name.toUpperCase()} WON!';

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
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
                    offset: Offset(offset.dx * 460, 0),
                    child: child,
                  );
                },
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 62,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 3,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(4, 4),
                        blurRadius: 10,
                      ),
                      Shadow(color: Colors.white24, blurRadius: 24),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Transform.scale(
                scale: 1.1,
                child: widget.isTeamBattle
                    ? _buildTeamWinnerPanel(winnerIndex)
                    : _buildSoloWinnerPanel(winnerIndex),
              ),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      _fadeRoute(const MainMenuScreen()),
                      (route) => false,
                    );
                  },
                  iconSize: 44,
                  padding: const EdgeInsets.all(18),
                  icon: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoloWinnerPanel(int playerIndex) {
    final player = widget.players[playerIndex];
    final isRed = playerIndex.isOdd;
    final themeColor = isRed ? Colors.redAccent : Colors.blueAccent;

    return PlayerArenaInfo(
      player: player,
      isMirrored: playerIndex.isOdd,
      themeColor: themeColor,
      extra: !widget.isTeamBattle ? _buildTicks(playerIndex) : null,
      isSelected: isRed,
      glowAlpha: 0.7,
      thickness: 6.0,
      isSelecting: false,
      isExpanded: true,
    );
  }

  Widget _buildTeamWinnerPanel(int teamIndex) {
    final firstIndex = teamIndex == 0 ? 0 : 1;
    final secondIndex = teamIndex == 0 ? 2 : 3;
    final isMirrored = teamIndex == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMirrored
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        _buildWinnerTeamPlayer(firstIndex, isMirrored),
        const SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.only(
            left: isMirrored ? 0 : 90,
            right: isMirrored ? 90 : 0,
          ),
          child: _buildWinnerTeamPlayer(secondIndex, isMirrored),
        ),
        const SizedBox(height: 30),
        Align(
          alignment: isMirrored ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(
              left: isMirrored ? 0 : 120,
              right: isMirrored ? 120 : 0,
            ),
            child: _buildTicks(teamIndex),
          ),
        ),
      ],
    );
  }

  Widget _buildWinnerTeamPlayer(int playerIndex, bool isMirrored) {
    final player = widget.players[playerIndex];
    final isRed = playerIndex.isOdd;
    final themeColor = isRed ? Colors.redAccent : Colors.blueAccent;

    return PlayerArenaInfo(
      player: player,
      isMirrored: isMirrored,
      themeColor: themeColor,
      isSelected: isRed,
      glowAlpha: 0.7,
      thickness: 6.0,
      isSelecting: false,
      isExpanded: true,
    );
  }
}

class GPowerBadge extends StatelessWidget {
  final int gPower;
  final String attribute;
  final Color themeColor;

  const GPowerBadge({
    super.key,
    required this.gPower,
    required this.attribute,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    const double nudgeX = -1.0; // Positive = Right, Negative = Left
    const double nudgeY =
        -1.0; // Positive = Down, Negative = Up (Try -2.0 or -3.0)
    const double iconSize = 80.0; // Total size of the PNG icon

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // 1. THE SKEWED BAR
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(-0.15),
            child: Container(
              width: 280,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    themeColor.withValues(alpha: 0.9),
                    themeColor.withValues(alpha: 0.4),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: 25,
                    top: 8,
                    bottom: 0,
                    width: 170,
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.skewX(0.15),
                        child: AutoSizeText(
                          '$gPower',
                          maxLines: 1,
                          minFontSize: 28,
                          stepGranularity: 0.5,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            fontSize: 55,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                            letterSpacing: -2,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(3, 3),
                                blurRadius: 4,
                              ),
                              Shadow(color: Colors.white24, blurRadius: 15),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. THE UPDATED ORB CODE
          Positioned(
            left: -35,
            child: Container(
              width: 95,
              height: 95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.2, -0.3),
                  colors: [Colors.white, Colors.grey, Color(0xFF1A1A1A)],
                  stops: [0.0, 0.4, 1.0],
                ),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 15,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: Center(
                // Transform.translate is the "nuclear option" for alignment
                // It will move the PNG regardless of BoxFit or Center rules
                child: Transform.translate(
                  offset: const Offset(nudgeX, nudgeY),
                  child: SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: Image.asset(
                      'assets/images/attributes/${attribute}_game.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
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

class InteractiveCard extends StatefulWidget {
  final String imagePath;
  final VoidCallback? onTap;
  final double width;

  const InteractiveCard({
    super.key,
    required this.imagePath,
    this.onTap,
    this.width = 400,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) {
          setState(() => _isHovered = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: _isHovered ? 0.3 : 0.2),
                  blurRadius: _isHovered ? 40 : 25,
                  spreadRadius: _isHovered ? 8 : 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(widget.imagePath, width: widget.width),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchAbilityMiniCard extends StatefulWidget {
  final String imagePath;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MatchAbilityMiniCard({
    required this.imagePath,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_MatchAbilityMiniCard> createState() => _MatchAbilityMiniCardState();
}

class _MatchAbilityMiniCardState extends State<_MatchAbilityMiniCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final opacity = widget.isActive ? 1.0 : 0.48;
    final glowOpacity = _isHovered ? 0.26 : 0.16;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: glowOpacity),
                    blurRadius: _isHovered ? 24 : 18,
                    spreadRadius: _isHovered ? 2 : 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(widget.imagePath, width: 90),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
