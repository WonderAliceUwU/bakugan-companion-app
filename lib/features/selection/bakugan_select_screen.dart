part of '../../main.dart';

enum _BakuganSortMode { alphabetical, gPowerAsc, gPowerDesc }

class BakuganSelectScreen extends StatefulWidget {
  final List<PlayerData> players;
  final bool isTeamBattle;

  const BakuganSelectScreen({
    super.key,
    required this.players,
    required this.isTeamBattle,
  });

  @override
  State<BakuganSelectScreen> createState() => _BakuganSelectScreenState();
}

class _BakuganSelectScreenState extends State<BakuganSelectScreen> {
  static const List<String> _attributeWheelOrder = [
    'pyrus',
    'subterra',
    'haos',
    'darkus',
    'aquos',
    'ventus',
  ];

  int currentPlayerIndex = 0;
  int selectedBakuganIndex = 0;
  int selectedVariantIndex = 0;
  String? _selectedAttribute;
  _BakuganSortMode _sortMode = _BakuganSortMode.alphabetical;
  final PageController _carouselController = PageController(
    viewportFraction: 0.2,
  );
  late AudioPlayer _sfxPlayer;
  bool _inventoryLoaded = false;
  bool _inventoryConfigured = false;
  bool _collectionMode = true;
  Set<String> _includedInventoryKeys = <String>{};
  Map<String, int> _savedGPowerByInventoryKey = <String, int>{};

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer();
    AppVolumeController.instance.register(_sfxPlayer);
    unawaited(_loadInventoryConfiguration());
  }

  Future<void> _loadInventoryConfiguration() async {
    await loadAvailableBakugans();
    final store = await LeaderboardRepository.instance.loadStore();
    if (!mounted) return;
    setState(() {
      _inventoryConfigured = store.bakuganInventory.isConfigured;
      _includedInventoryKeys = store.bakuganInventory.bakugans
          .where((entry) => entry.gPower > 0)
          .map((entry) => entry.inventoryKey)
          .toSet();
      _savedGPowerByInventoryKey = {
        for (final entry in store.bakuganInventory.bakugans)
          if (entry.gPower > 0) entry.inventoryKey: entry.gPower,
      };
      _inventoryLoaded = true;
    });
  }

  void _playClick() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sound/select_2.wav'));
  }

  void _moveCarousel(int delta, int itemCount) {
    if (itemCount <= 1) return;
    final visibleBakugans = _visibleBakugans();
    final nextIndex = (selectedBakuganIndex + delta + itemCount) % itemCount;
    _playClick();
    setState(() {
      selectedBakuganIndex = nextIndex;
      selectedVariantIndex = _preferredVariantIndex(visibleBakugans[nextIndex]);
    });
    _keepSelectedBakuganVisible(
      nextIndex,
      itemCount: itemCount,
      viewportFraction: 0.2,
    );
  }

  void _selectBakugan(int index) {
    final visibleBakugans = _visibleBakugans();
    if (index < 0 || index >= visibleBakugans.length) return;
    _playClick();
    setState(() {
      selectedBakuganIndex = index;
      selectedVariantIndex = _preferredVariantIndex(visibleBakugans[index]);
    });
  }

  void _keepSelectedBakuganVisible(
    int index, {
    required int itemCount,
    required double viewportFraction,
  }) {
    if (!_carouselController.hasClients) return;
    final firstVisibleIndex = (_carouselController.page ?? 0).floor();
    final visiblePageCount = max(1, (1 / viewportFraction).floor());
    final lastVisibleIndex = firstVisibleIndex + visiblePageCount - 1;
    final targetPage = index < firstVisibleIndex
        ? index
        : index > lastVisibleIndex
        ? index - visiblePageCount + 1
        : firstVisibleIndex;
    final boundedTargetPage = targetPage.clamp(0, itemCount - 1);
    if (boundedTargetPage == firstVisibleIndex) return;
    unawaited(
      _carouselController.animateToPage(
        boundedTargetPage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      ),
    );
  }

  bool _isVariantBanned(BakuganVariant variant) {
    final speciesName = variant.speciesName.toLowerCase();
    final modelPath = variant.modelPath.toLowerCase();
    return speciesName.contains('banned') ||
        modelPath.contains('banned') ||
        isBannedBakuganVariant(variant);
  }

  bool _isPreyasDiablo(BakuganVariant variant) =>
      variant.speciesName.trim().toLowerCase() == 'preyas diablo';

  bool _showsPreyasDualAttributeIcon(BakuganVariant variant) =>
      _isPreyasDiablo(variant) && variant.attribute.toLowerCase() != 'pyrus';

  bool _isVariantTaken(BakuganVariant variant) {
    if (_isVariantBanned(variant)) return true;
    for (var p in widget.players) {
      if (p.deck.any(
        (v) =>
            v.modelPath == variant.modelPath &&
            v.attribute == variant.attribute,
      )) {
        return true;
      }
    }
    return false;
  }

  Color _colorForAttribute(String attribute) {
    switch (attribute.trim().toLowerCase()) {
      case 'pyrus':
        return const Color(0xFFFF6B3D);
      case 'aquos':
        return const Color(0xFF3DA5FF);
      case 'subterra':
        return const Color(0xFFD4A037);
      case 'haos':
        return const Color(0xFFF1E68A);
      case 'darkus':
        return const Color(0xFF9B59FF);
      case 'ventus':
        return const Color(0xFF45D483);
      default:
        return Colors.blueAccent;
    }
  }

  List<Bakugan> _visibleBakugans() {
    BakuganVariant withSavedGPower(BakuganVariant variant) {
      final savedGPower =
          _savedGPowerByInventoryKey[bakuganVariantKey(variant)];
      return savedGPower == null
          ? variant
          : variant.copyWith(gPower: savedGPower);
    }

    final allCatalogBakugans = availableBakugans
        .map(
          (bakugan) => Bakugan(
            name: bakugan.name,
            variants: bakugan.variants.map(withSavedGPower).toList(),
          ),
        )
        .toList();
    final inventoryFiltered = _inventoryConfigured
        ? allCatalogBakugans
              .map(
                (bakugan) => Bakugan(
                  name: bakugan.name,
                  variants: bakugan.variants
                      .where(
                        (variant) => _includedInventoryKeys.contains(
                          bakuganVariantKey(variant),
                        ),
                      )
                      .toList(),
                ),
              )
              .where((bakugan) => bakugan.variants.isNotEmpty)
              .toList()
        : <Bakugan>[];
    final sourceBakugans = _collectionMode
        ? inventoryFiltered
        : allCatalogBakugans;

    final species = _selectedAttribute == null
        ? sourceBakugans
        : sourceBakugans
              .where(
                (bakugan) => bakugan.variants.any(
                  (variant) =>
                      variant.attribute.toLowerCase() == _selectedAttribute,
                ),
              )
              .toList();

    species.sort((a, b) {
      switch (_sortMode) {
        case _BakuganSortMode.alphabetical:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _BakuganSortMode.gPowerAsc:
          return _primaryVariantForSpecies(
            a,
          ).gPower.compareTo(_primaryVariantForSpecies(b).gPower);
        case _BakuganSortMode.gPowerDesc:
          return _primaryVariantForSpecies(
            b,
          ).gPower.compareTo(_primaryVariantForSpecies(a).gPower);
      }
    });

    return species;
  }

  int _preferredVariantIndex(Bakugan species) {
    if (_selectedAttribute == null) return 0;
    final index = species.variants.indexWhere(
      (variant) => variant.attribute.toLowerCase() == _selectedAttribute,
    );
    return index >= 0 ? index : 0;
  }

  BakuganVariant _primaryVariantForSpecies(Bakugan species) {
    return species.variants[_preferredVariantIndex(species)];
  }

  void _syncSelectionWithVisibleBakugans({String? preferredSpeciesName}) {
    final visibleBakugans = _visibleBakugans();
    if (visibleBakugans.isEmpty) {
      selectedBakuganIndex = 0;
      selectedVariantIndex = 0;
      return;
    }

    final currentSpeciesName =
        preferredSpeciesName ??
        ((_hasSelectedBakugan(visibleBakugans))
            ? visibleBakugans[selectedBakuganIndex].name
            : null);

    var nextIndex = 0;
    if (currentSpeciesName != null) {
      final matchedIndex = visibleBakugans.indexWhere(
        (bakugan) => bakugan.name == currentSpeciesName,
      );
      if (matchedIndex >= 0) {
        nextIndex = matchedIndex;
      }
    }

    selectedBakuganIndex = nextIndex;
    selectedVariantIndex = _preferredVariantIndex(visibleBakugans[nextIndex]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_carouselController.hasClients) return;
      _carouselController.jumpToPage(selectedBakuganIndex);
    });
  }

  bool _hasSelectedBakugan(List<Bakugan> bakugans) {
    return bakugans.isNotEmpty &&
        selectedBakuganIndex >= 0 &&
        selectedBakuganIndex < bakugans.length;
  }

  void _setAttributeFilter(String? attribute) {
    _playClick();
    final preferredSpeciesName =
        availableBakugans.isNotEmpty &&
            selectedBakuganIndex >= 0 &&
            selectedBakuganIndex < availableBakugans.length
        ? availableBakugans[selectedBakuganIndex].name
        : null;

    setState(() {
      _selectedAttribute = attribute;
      if (_selectedAttribute == null) {
        _sortMode = _BakuganSortMode.alphabetical;
      }
      _syncSelectionWithVisibleBakugans(
        preferredSpeciesName: preferredSpeciesName,
      );
    });
  }

  void _setSortMode(_BakuganSortMode mode) {
    if (_selectedAttribute == null || _sortMode == mode) return;
    _playClick();
    final visibleBakugans = _visibleBakugans();
    final currentSpeciesName = _hasSelectedBakugan(visibleBakugans)
        ? visibleBakugans[selectedBakuganIndex].name
        : null;
    setState(() {
      _sortMode = mode;
      _syncSelectionWithVisibleBakugans(
        preferredSpeciesName: currentSpeciesName,
      );
    });
  }

  void _setCollectionMode(bool enabled) {
    if (_collectionMode == enabled) return;
    _playClick();
    final currentBakugans = _visibleBakugans();
    final currentSpeciesName = _hasSelectedBakugan(currentBakugans)
        ? currentBakugans[selectedBakuganIndex].name
        : null;
    setState(() {
      _collectionMode = enabled;
      _syncSelectionWithVisibleBakugans(
        preferredSpeciesName: currentSpeciesName,
      );
    });
  }

  String _sortModeLabel(_BakuganSortMode mode) {
    switch (mode) {
      case _BakuganSortMode.alphabetical:
        return 'A-Z';
      case _BakuganSortMode.gPowerAsc:
        return 'LOW G';
      case _BakuganSortMode.gPowerDesc:
        return 'HIGH G';
    }
  }

  IconData _sortModeIcon(_BakuganSortMode mode) {
    switch (mode) {
      case _BakuganSortMode.alphabetical:
        return Icons.sort_by_alpha_rounded;
      case _BakuganSortMode.gPowerAsc:
        return Icons.arrow_upward_rounded;
      case _BakuganSortMode.gPowerDesc:
        return Icons.arrow_downward_rounded;
    }
  }

  Future<void> _openAttributePicker() async {
    _playClick();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 180,
            vertical: 110,
          ),
          child: _SelectionOverlayShell(
            title: 'FILTER BY ATTRIBUTE',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AttributeWheelPicker(
                  selectedAttribute: _selectedAttribute,
                  orderedAttributes: _attributeWheelOrder,
                  colorForAttribute: _colorForAttribute,
                  onSelectAttribute: (attribute) {
                    Navigator.of(context).pop();
                    _setAttributeFilter(attribute);
                  },
                  onClear: () {
                    Navigator.of(context).pop();
                    _setAttributeFilter(null);
                  },
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 500,
                  child: Text(
                    'Tap a sector to filter by attribute.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'button_font',
                      fontSize: 12,
                      color: Colors.white54,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSortPicker() async {
    if (_selectedAttribute == null) return;
    _playClick();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 220,
            vertical: 120,
          ),
          child: _SelectionOverlayShell(
            title: 'ORDER BY',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SortChip(
                  label: 'A-Z',
                  icon: Icons.sort_by_alpha_rounded,
                  isSelected: _sortMode == _BakuganSortMode.alphabetical,
                  isEnabled: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    _setSortMode(_BakuganSortMode.alphabetical);
                  },
                ),
                const SizedBox(width: 12),
                _SortChip(
                  label: 'LOW G',
                  icon: Icons.arrow_upward_rounded,
                  isSelected: _sortMode == _BakuganSortMode.gPowerAsc,
                  isEnabled: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    _setSortMode(_BakuganSortMode.gPowerAsc);
                  },
                ),
                const SizedBox(width: 12),
                _SortChip(
                  label: 'HIGH G',
                  icon: Icons.arrow_downward_rounded,
                  isSelected: _sortMode == _BakuganSortMode.gPowerDesc,
                  isEnabled: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    _setSortMode(_BakuganSortMode.gPowerDesc);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addBakugan() {
    final visibleBakugans = _visibleBakugans();
    if (!_hasSelectedBakugan(visibleBakugans)) return;
    final species = visibleBakugans[selectedBakuganIndex];
    final variant = species.variants[selectedVariantIndex];

    if (_isVariantTaken(variant)) return;

    final p = widget.players[currentPlayerIndex];
    if (p.deck.length < 3) {
      setState(() => p.deck.add(variant));
    }
  }

  void _removeBakugan(int playerIdx, int bakuganIdx) {
    _playClick();
    setState(() {
      widget.players[playerIdx].deck.removeAt(bakuganIdx);
      currentPlayerIndex = playerIdx; // Set as current when modifying
    });
  }

  void _nextPlayer() {
    if (currentPlayerIndex < widget.players.length - 1) {
      setState(() {
        currentPlayerIndex++;
        selectedBakuganIndex = 0;
        selectedVariantIndex = 0;
        _carouselController.jumpToPage(0);
      });
    } else {
      Navigator.push(
        context,
        _zoomRoute(
          ScoreboardScreen(
            players: widget.players,
            isTeamBattle: widget.isTeamBattle,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    AppVolumeController.instance.unregister(_sfxPlayer);
    _sfxPlayer.dispose();
    super.dispose();
  }

  Widget _buildCompactSelectionScreen({
    required List<Bakugan> visibleBakugans,
    required PlayerData currentPlayer,
    required Bakugan currentSpecies,
    required BakuganVariant currentVariant,
    required bool hasVisibleBakugans,
    required bool currentIsTaken,
    required String? currentStatusLabel,
  }) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/selection-bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final playerRailWidth = min(
                340.0,
                max(260.0, constraints.maxWidth * 0.29),
              );
              return Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: Colors.white,
                          onPressed: () {
                            unawaited(_playUiCancelSound());
                            Navigator.of(context).pop();
                          },
                        ),
                        Expanded(
                          child: Text(
                            AppLocalizations.current.selectBakugan,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'title_font',
                              fontSize: constraints.maxWidth < 1250 ? 28 : 36,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: const [
                                Shadow(color: Colors.blue, blurRadius: 18),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: playerRailWidth,
                          child: _buildCompactPlayerRail(),
                        ),
                        Expanded(
                          child: _buildCompactSelectionStage(
                            visibleBakugans: visibleBakugans,
                            currentPlayer: currentPlayer,
                            currentSpecies: currentSpecies,
                            currentVariant: currentVariant,
                            hasVisibleBakugans: hasVisibleBakugans,
                            currentIsTaken: currentIsTaken,
                            currentStatusLabel: currentStatusLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompactPlayerRail() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 12),
      child: Column(
        children: widget.players.asMap().entries.map((entry) {
          final playerIndex = entry.key;
          final player = entry.value;
          final isCurrent = playerIndex == currentPlayerIndex;
          final accent = playerIndex.isEven
              ? Colors.blueAccent
              : Colors.redAccent;
          return GestureDetector(
            onTap: () => setState(() => currentPlayerIndex = playerIndex),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent ? accent : Colors.white12,
                  width: isCurrent ? 2 : 1,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.2),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 142,
                    child: CharacterMiniature(
                      char: player.character,
                      label: player.name,
                      isSelected: isCurrent,
                      showName: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (slotIndex) {
                      final hasBakugan = slotIndex < player.deck.length;
                      final variant = hasBakugan
                          ? player.deck[slotIndex]
                          : null;
                      return GestureDetector(
                        onTap: hasBakugan
                            ? () => _removeBakugan(playerIndex, slotIndex)
                            : null,
                        child: Container(
                          width: 68,
                          height: 68,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasBakugan
                                  ? variant!.color
                                  : Colors.white12,
                            ),
                          ),
                          child: hasBakugan
                              ? BakuganPreview(
                                  variant: variant!,
                                  isDeck: true,
                                  autoRotate: false,
                                )
                              : const Icon(Icons.add, color: Colors.white24),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${player.totalGPower} G',
                    style: TextStyle(
                      color: accent,
                      fontFamily: 'button_font',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompactSelectionStage({
    required List<Bakugan> visibleBakugans,
    required PlayerData currentPlayer,
    required Bakugan currentSpecies,
    required BakuganVariant currentVariant,
    required bool hasVisibleBakugans,
    required bool currentIsTaken,
    required String? currentStatusLabel,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final carouselHeight = constraints.maxHeight < 760 ? 104.0 : 124.0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 14, 8),
          child: Column(
            children: [
              Text(
                currentPlayer.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 15,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              _BakuganCompactToolbar(
                width: constraints.maxWidth,
                selectedAttribute: _selectedAttribute,
                sortMode: _sortMode,
                sortLabel: _sortModeLabel(_sortMode),
                sortIcon: _sortModeIcon(_sortMode),
                colorForAttribute: _colorForAttribute,
                onAttributeTap: _openAttributePicker,
                onSortTap: _openSortPicker,
                collectionMode: _collectionMode,
                onCollectionModeToggle: () =>
                    _setCollectionMode(!_collectionMode),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: hasVisibleBakugans
                    ? Row(
                        children: [
                          SizedBox(
                            width: constraints.maxWidth < 880 ? 82 : 104,
                            child: _buildCompactAttributeRail(currentSpecies),
                          ),
                          Expanded(
                            child: BakuganPreview(
                              key: ValueKey(
                                'compact_large_${currentVariant.modelPath}_${currentVariant.attribute}_${currentVariant.texturePath}',
                              ),
                              variant: currentVariant,
                              isLarge: true,
                              speciesName: currentSpecies.name,
                              isTaken: currentIsTaken,
                              statusLabel: currentStatusLabel,
                              centerLargeFooter: true,
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: _SelectionInfoPanel(
                          text: _emptySelectionMessage,
                        ),
                      ),
              ),
              if (hasVisibleBakugans)
                SizedBox(
                  height: carouselHeight,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 24),
                        color: Colors.white70,
                        onPressed: () =>
                            _moveCarousel(-1, visibleBakugans.length),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _carouselController,
                          padEnds: false,
                          clipBehavior: Clip.none,
                          itemCount: visibleBakugans.length,
                          itemBuilder: (context, index) {
                            final item = visibleBakugans[index];
                            final variant = _primaryVariantForSpecies(item);
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _selectBakugan(index),
                              child: AnimatedPadding(
                                padding: selectedBakuganIndex == index
                                    ? const EdgeInsets.symmetric(horizontal: 2)
                                    : const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 4,
                                      ),
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                child: BakuganPreview(
                                  key: ValueKey(
                                    'compact_preview_${variant.modelPath}_${variant.attribute}_${variant.texturePath}',
                                  ),
                                  variant: variant,
                                  isSelected: selectedBakuganIndex == index,
                                  speciesName: item.name,
                                  autoRotate: false,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 24),
                        color: Colors.white70,
                        onPressed: () =>
                            _moveCarousel(1, visibleBakugans.length),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(height: carouselHeight),
              if (hasVisibleBakugans)
                Row(
                  children: [
                    Expanded(
                      child: BakuganButton(
                        text: currentIsTaken ? 'PICKED' : 'ADD',
                        onPressed: _addBakugan,
                        width: double.infinity,
                        height: 62,
                        color: currentIsTaken ? Colors.grey : Colors.blueAccent,
                        textFontSize: 21,
                      ),
                    ),
                    if (widget.players.every(
                      (player) => player.deck.length == 3,
                    )) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: BakuganButton(
                          text: 'READY',
                          onPressed: _nextPlayer,
                          width: double.infinity,
                          height: 62,
                          textFontSize: 21,
                        ),
                      ),
                    ],
                  ],
                )
              else
                const SizedBox(height: 62),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactAttributeRail(Bakugan species) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: species.variants.asMap().entries.map((entry) {
          final index = entry.key;
          final variant = entry.value;
          final isSelected = index == selectedVariantIndex;
          final isTaken = _isVariantTaken(variant);
          return GestureDetector(
            onTap: isTaken
                ? null
                : () {
                    _playClick();
                    setState(() => selectedVariantIndex = index);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              height: 48,
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? variant.color.withValues(alpha: 0.32)
                    : Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isSelected ? variant.color : Colors.white12,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/attributes/${variant.attribute}_game.png',
                    width: 28,
                    height: 28,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.circle, size: 17, color: variant.color),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${variant.gPower}G',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String get _emptySelectionMessage => _collectionMode
      ? 'Tu colección está vacía. Desactiva COLLECTION MODE o habilita Bakugan desde INVENTORY.'
      : 'No hay Bakugan para este atributo. Cambia el filtro para seguir seleccionando.';

  @override
  Widget build(BuildContext context) {
    final visibleBakugans = _visibleBakugans();

    if (availableBakugans.isEmpty || !_inventoryLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasVisibleBakugans = visibleBakugans.isNotEmpty;
    if (hasVisibleBakugans && !_hasSelectedBakugan(visibleBakugans)) {
      selectedBakuganIndex = 0;
    }

    final currentPlayer = widget.players[currentPlayerIndex];
    final currentSpecies = hasVisibleBakugans
        ? visibleBakugans[selectedBakuganIndex]
        : availableBakugans.first;
    final preferredVariantIndex = _preferredVariantIndex(currentSpecies);
    if (hasVisibleBakugans &&
        _selectedAttribute != null &&
        selectedVariantIndex != preferredVariantIndex) {
      selectedVariantIndex = preferredVariantIndex;
    }
    final safeVariantIndex = selectedVariantIndex
        .clamp(0, currentSpecies.variants.length - 1)
        .toInt();
    final currentVariant = currentSpecies.variants[safeVariantIndex];
    final bool currentIsBanned = _isVariantBanned(currentVariant);
    final bool currentIsTaken = _isVariantTaken(currentVariant);
    final String? currentStatusLabel = currentIsBanned
        ? 'BANNED'
        : (currentIsTaken ? 'PICKED' : null);

    if (MediaQuery.sizeOf(context).width < 1800) {
      return _buildCompactSelectionScreen(
        visibleBakugans: visibleBakugans,
        currentPlayer: currentPlayer,
        currentSpecies: currentSpecies,
        currentVariant: currentVariant,
        hasVisibleBakugans: hasVisibleBakugans,
        currentIsTaken: currentIsTaken,
        currentStatusLabel: currentStatusLabel,
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/selection-bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
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
                  unawaited(_playUiCancelSound());
                  Navigator.of(context).pop();
                },
              ),
            ),

            // HORIZONTAL PLAYER LIST ON LEFT
            Positioned(
              left: 60,
              top: 100,
              bottom: 40,
              child: SizedBox(
                width: 600, // Wide enough for portrait + name + 3 slots
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.players.asMap().entries.map((entry) {
                      bool isCurrent = entry.key == currentPlayerIndex;
                      final themeColor = entry.key % 2 == 0
                          ? Colors.blueAccent
                          : Colors.redAccent;

                      return GestureDetector(
                        onTap: () =>
                            setState(() => currentPlayerIndex = entry.key),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: 60.0,
                          ), // Large gap between players
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- CHARACTER PORTRAIT (Large) ---
                              SizedBox(
                                width: 180,
                                height: 213,
                                child: CharacterMiniature(
                                  // 1. This points to the image file (dan, runo, etc.)
                                  char: entry.value.character,

                                  // 2. This tells the widget to use the Player's name for the text label
                                  label: entry.value.name,

                                  isSelected: isCurrent,
                                  showName: true,
                                ),
                              ),
                              const SizedBox(width: 45),

                              // --- INFO & DECK ---
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // --- BAKUGAN SLOTS ---
                                    Row(
                                      children: List.generate(3, (i) {
                                        final hasBakugan =
                                            i < entry.value.deck.length;
                                        final variant = hasBakugan
                                            ? entry.value.deck[i]
                                            : null;

                                        return GestureDetector(
                                          onTap: hasBakugan
                                              ? () =>
                                                    _removeBakugan(entry.key, i)
                                              : null,
                                          child: Container(
                                            width: 100,
                                            height: 100,
                                            // Restored to original large size
                                            margin: const EdgeInsets.only(
                                              right: 15,
                                            ),
                                            transform: Matrix4.skewX(-0.15),
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: hasBakugan
                                                    ? variant!.color
                                                    : Colors.white12,
                                                width: hasBakugan ? 3 : 1.5,
                                              ),
                                              boxShadow: hasBakugan
                                                  ? [
                                                      BoxShadow(
                                                        color: variant!.color
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                        blurRadius: 12,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: hasBakugan
                                                  ? Stack(
                                                      children: [
                                                        // COUNTER-SKEW to fix deformation
                                                        Transform(
                                                          alignment:
                                                              Alignment.center,
                                                          transform:
                                                              Matrix4.skewX(
                                                                0.15,
                                                              ),
                                                          child: BakuganPreview(
                                                            variant: variant!,
                                                            isDeck: true,
                                                          ),
                                                        ),
                                                        Positioned(
                                                          top: 4,
                                                          right: 4,
                                                          child: Icon(
                                                            Icons.cancel,
                                                            size: 18,
                                                            color: Colors
                                                                .redAccent
                                                                .withValues(
                                                                  alpha: 0.8,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : const Center(
                                                      child: Icon(
                                                        Icons.add,
                                                        color: Colors.white10,
                                                        size: 30,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 15),

                                    // TOTAL G POWER DISPLAY
                                    Align(
                                      alignment: const Alignment(-1.7, 0),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 0),
                                        // Adjust this if you need a specific margin from the edge
                                        child: Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.skewX(-0.15),
                                          child: Container(
                                            width: 320,
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  themeColor,
                                                  themeColor.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  Colors.black,
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: themeColor.withValues(
                                                    alpha: 0.4,
                                                  ),
                                                  blurRadius: 15,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Container(
                                              clipBehavior: Clip.antiAlias,
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  // Grid Background
                                                  Positioned.fill(
                                                    child: CustomPaint(
                                                      painter: GridPainter(
                                                        color: themeColor
                                                            .withValues(
                                                              alpha: 0.15,
                                                            ),
                                                      ),
                                                    ),
                                                  ),

                                                  // Text Content
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 12,
                                                        ),
                                                    child: Transform(
                                                      alignment:
                                                          Alignment.center,
                                                      transform: Matrix4.skewX(
                                                        0.15,
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'TOTAL G POWER',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'button_font',
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .white60,
                                                              letterSpacing: 2,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                          ),
                                                          Text(
                                                            '${entry.value.totalGPower} G',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'button_font',
                                                              fontSize: 34,
                                                              color: themeColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                              shadows: [
                                                                Shadow(
                                                                  color: themeColor
                                                                      .withValues(
                                                                        alpha:
                                                                            0.8,
                                                                      ),
                                                                  blurRadius:
                                                                      12,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            Positioned.fill(
              left: 600,
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Text(
                    currentPlayer.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 5,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const Text(
                    'SELECT YOUR DECK',
                    style: TextStyle(
                      fontFamily: 'title_font',
                      fontSize: 50,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          blurRadius: 30.0,
                          color: Colors.blue,
                          offset: Offset.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _BakuganCompactToolbar(
                    selectedAttribute: _selectedAttribute,
                    sortMode: _sortMode,
                    sortLabel: _sortModeLabel(_sortMode),
                    sortIcon: _sortModeIcon(_sortMode),
                    colorForAttribute: _colorForAttribute,
                    onAttributeTap: _openAttributePicker,
                    onSortTap: _openSortPicker,
                    collectionMode: _collectionMode,
                    onCollectionModeToggle: () =>
                        _setCollectionMode(!_collectionMode),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -40),
                      child: Center(
                        child: SizedBox(
                          width: 900, // Fixed container for both elements
                          height: 540,
                          child: hasVisibleBakugans
                              ? Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    // 1. LARGE PREVIEW (Placed first so it's \"behind\" the tabs if needed)
                                    Positioned(
                                      left: 100,
                                      // Gives space for the tabs to sit on the edge
                                      child: SizedBox(
                                        width: 800,
                                        height: 540,
                                        child: BakuganPreview(
                                          key: ValueKey(
                                            'large_${currentVariant.modelPath}_${currentVariant.attribute}_${currentVariant.texturePath}',
                                          ),
                                          variant: currentVariant,
                                          isLarge: true,
                                          speciesName: currentSpecies.name,
                                          isTaken: currentIsTaken,
                                          statusLabel: currentStatusLabel,
                                        ),
                                      ),
                                    ),

                                    // 2. ATTRIBUTE SELECTOR (Placed on top, overlapping the edge)
                                    Positioned(
                                      left: 0,
                                      child: SizedBox(
                                        height: 540,
                                        width: 140,
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final variants =
                                                currentSpecies.variants;
                                            const double fixedItemHeight = 90;
                                            final isFullSet =
                                                variants.length == 6;

                                            return Stack(
                                              clipBehavior: Clip.none,
                                              children: variants.asMap().entries.map((
                                                vEntry,
                                              ) {
                                                final index = vEntry.key;
                                                final variant = vEntry.value;
                                                bool isSel =
                                                    index ==
                                                    selectedVariantIndex;
                                                bool isTaken = _isVariantTaken(
                                                  variant,
                                                );

                                                double top = isFullSet
                                                    ? index *
                                                          (540 -
                                                              fixedItemHeight) /
                                                          5
                                                    : index * 90;

                                                // The horizontal \"staircase\" offset
                                                final double baseLeft =
                                                    index * -13.5 + 35;
                                                // How much the tab should \"pop out\" to the left
                                                const double popOutDistance =
                                                    30;

                                                return AnimatedPositioned(
                                                  duration: const Duration(
                                                    milliseconds: 250,
                                                  ),
                                                  curve: Curves.easeOutCubic,
                                                  top: top,
                                                  // SUBTRACT to move it left (outwards)
                                                  left: isSel
                                                      ? baseLeft -
                                                            popOutDistance
                                                      : baseLeft,
                                                  child: GestureDetector(
                                                    onTap: isTaken
                                                        ? null
                                                        : () {
                                                            _playClick();
                                                            setState(
                                                              () =>
                                                                  selectedVariantIndex =
                                                                      index,
                                                            );
                                                          },
                                                    child: Transform(
                                                      alignment:
                                                          Alignment.center,
                                                      transform: Matrix4.skewX(
                                                        -0.15,
                                                      ),
                                                      child: AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 250,
                                                            ),
                                                        curve:
                                                            Curves.easeOutCubic,
                                                        // We increase width by the same distance so the right side
                                                        // stays flush against the Preview
                                                        width: isSel
                                                            ? (100 +
                                                                  popOutDistance)
                                                            : 100,
                                                        height: fixedItemHeight,
                                                        padding:
                                                            const EdgeInsets.all(
                                                              10,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isTaken
                                                              ? Colors.grey
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    )
                                                              : (isSel
                                                                    ? variant
                                                                          .color
                                                                          .withValues(
                                                                            alpha:
                                                                                0.4,
                                                                          )
                                                                    : Colors
                                                                          .black45),
                                                          border: Border(
                                                            top: BorderSide(
                                                              color: isTaken
                                                                  ? Colors.grey
                                                                  : (isSel
                                                                        ? variant
                                                                              .color
                                                                        : Colors
                                                                              .white24),
                                                              width: isSel
                                                                  ? 2
                                                                  : 1,
                                                            ),
                                                            left: BorderSide(
                                                              color: isTaken
                                                                  ? Colors.grey
                                                                  : (isSel
                                                                        ? variant
                                                                              .color
                                                                        : Colors
                                                                              .white24),
                                                              width: isSel
                                                                  ? 2
                                                                  : 1,
                                                            ),
                                                            bottom: BorderSide(
                                                              color: isTaken
                                                                  ? Colors.grey
                                                                  : (isSel
                                                                        ? variant
                                                                              .color
                                                                        : Colors
                                                                              .white24),
                                                              width: isSel
                                                                  ? 2
                                                                  : 1,
                                                            ),
                                                          ),
                                                          borderRadius:
                                                              const BorderRadius.only(
                                                                topLeft:
                                                                    Radius.circular(
                                                                      15,
                                                                    ),
                                                                bottomLeft:
                                                                    Radius.circular(
                                                                      15,
                                                                    ),
                                                              ),
                                                          boxShadow: isSel
                                                              ? [
                                                                  BoxShadow(
                                                                    color: variant
                                                                        .color
                                                                        .withValues(
                                                                          alpha:
                                                                              0.4,
                                                                        ),
                                                                    blurRadius:
                                                                        15,
                                                                    spreadRadius:
                                                                        2,
                                                                  ),
                                                                ]
                                                              : [],
                                                        ),
                                                        child: Transform(
                                                          alignment:
                                                              Alignment.center,
                                                          transform:
                                                              Matrix4.skewX(
                                                                0.15,
                                                              ),
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Expanded(
                                                                child: Opacity(
                                                                  opacity:
                                                                      isTaken
                                                                      ? 0.3
                                                                      : 1.0,
                                                                  child:
                                                                      _showsPreyasDualAttributeIcon(
                                                                        variant,
                                                                      )
                                                                      ? ClipRect(
                                                                          child: FittedBox(
                                                                            fit:
                                                                                BoxFit.scaleDown,
                                                                            child: Row(
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Image.asset(
                                                                                  'assets/images/attributes/${variant.attribute}_game.png',
                                                                                  fit: BoxFit.contain,
                                                                                ),
                                                                                const Padding(
                                                                                  padding: EdgeInsets.symmetric(
                                                                                    horizontal: 10,
                                                                                  ),
                                                                                  child: Text(
                                                                                    '|',
                                                                                    style: TextStyle(
                                                                                      color: Colors.white,
                                                                                      fontSize: 18,
                                                                                      fontWeight: FontWeight.w900,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                Image.asset(
                                                                                  'assets/images/attributes/pyrus_game.png',
                                                                                  fit: BoxFit.contain,
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        )
                                                                      : Image.asset(
                                                                          'assets/images/attributes/${variant.attribute}_game.png',
                                                                          fit: BoxFit
                                                                              .contain,
                                                                        ),
                                                                ),
                                                              ),
                                                              Text(
                                                                '${variant.gPower}G',
                                                                style: TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color: isSel
                                                                      ? Colors
                                                                            .white
                                                                      : Colors
                                                                            .white70,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Center(
                                  child: _SelectionInfoPanel(
                                    text: _emptySelectionMessage,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  // CAROUSEL
                  Transform.translate(
                    offset: const Offset(0, -80),
                    child: SizedBox(
                      height: 180,
                      child: hasVisibleBakugans
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios,
                                    size: 40,
                                  ),
                                  onPressed: () =>
                                      _moveCarousel(-1, visibleBakugans.length),
                                ),
                                SizedBox(
                                  width: 1200,
                                  child: PageView.builder(
                                    controller: _carouselController,
                                    padEnds: false,
                                    clipBehavior: Clip.none,
                                    itemCount: visibleBakugans.length,
                                    itemBuilder: (context, idx) => GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _selectBakugan(idx),
                                      child: AnimatedPadding(
                                        padding: selectedBakuganIndex == idx
                                            ? const EdgeInsets.symmetric(
                                                horizontal: 5,
                                              )
                                            : const EdgeInsets.symmetric(
                                                horizontal: 15,
                                                vertical: 5,
                                              ),
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        curve: Curves.easeOut,
                                        child: BakuganPreview(
                                          key: ValueKey(
                                            'preview_${_primaryVariantForSpecies(visibleBakugans[idx]).modelPath}_${_primaryVariantForSpecies(visibleBakugans[idx]).attribute}_${_primaryVariantForSpecies(visibleBakugans[idx]).texturePath}',
                                          ),
                                          variant: _primaryVariantForSpecies(
                                            visibleBakugans[idx],
                                          ),
                                          isSelected:
                                              selectedBakuganIndex == idx,
                                          speciesName:
                                              visibleBakugans[idx].name,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 40,
                                  ),
                                  onPressed: () =>
                                      _moveCarousel(1, visibleBakugans.length),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: hasVisibleBakugans
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              BakuganButton(
                                text: currentIsTaken ? 'ALREADY PICKED' : 'ADD',
                                onPressed: _addBakugan,
                                width: 320,
                                height: 90,
                                color: currentIsTaken
                                    ? Colors.grey
                                    : Colors.blueAccent,
                              ),
                              if (widget.players.every(
                                (p) => p.deck.length == 3,
                              )) ...[
                                const SizedBox(width: 25),
                                BakuganButton(
                                  text: 'READY',
                                  onPressed: _nextPlayer,
                                  width: 240,
                                  height: 90,
                                ),
                              ],
                            ],
                          )
                        : const SizedBox(height: 90),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BakuganCompactToolbar extends StatelessWidget {
  final double? width;
  final String? selectedAttribute;
  final _BakuganSortMode sortMode;
  final String sortLabel;
  final IconData sortIcon;
  final Color Function(String attribute) colorForAttribute;
  final VoidCallback onAttributeTap;
  final VoidCallback onSortTap;
  final bool? collectionMode;
  final VoidCallback? onCollectionModeToggle;

  const _BakuganCompactToolbar({
    this.width,
    required this.selectedAttribute,
    required this.sortMode,
    required this.sortLabel,
    required this.sortIcon,
    required this.colorForAttribute,
    required this.onAttributeTap,
    required this.onSortTap,
    this.collectionMode,
    this.onCollectionModeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final canSort = selectedAttribute != null;
    return SizedBox(
      width: width ?? 900,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          _ToolbarTriggerButton(
            label: selectedAttribute == null
                ? 'ATTRIBUTE: ALL'
                : 'ATTRIBUTE: ${selectedAttribute!.toUpperCase()}',
            icon: Icons.filter_alt_rounded,
            accentColor: selectedAttribute == null
                ? Colors.blueAccent
                : colorForAttribute(selectedAttribute!),
            leadingAsset: selectedAttribute == null
                ? null
                : 'assets/images/attributes/${selectedAttribute!}_game.png',
            onTap: onAttributeTap,
          ),
          _ToolbarTriggerButton(
            label: 'ORDER: $sortLabel',
            icon: sortIcon,
            accentColor: canSort ? Colors.blueAccent : Colors.white38,
            isEnabled: canSort,
            onTap: onSortTap,
          ),
          if (collectionMode != null && onCollectionModeToggle != null)
            _ToolbarTriggerButton(
              label: collectionMode!
                  ? 'COLLECTION MODE: OWNED'
                  : 'COLLECTION MODE: ALL',
              icon: collectionMode!
                  ? Icons.inventory_2_rounded
                  : Icons.grid_view_rounded,
              accentColor: collectionMode! ? Colors.cyanAccent : Colors.white38,
              onTap: onCollectionModeToggle!,
            ),
        ],
      ),
    );
  }
}

class _SelectionOverlayShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _SelectionOverlayShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-0.15),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.fromLTRB(32, 30, 32, 30),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.22),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(0.15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'button_font',
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AttributeWheelPicker extends StatelessWidget {
  final String? selectedAttribute;
  final List<String> orderedAttributes;
  final Color Function(String attribute) colorForAttribute;
  final ValueChanged<String> onSelectAttribute;
  final VoidCallback onClear;

  const _AttributeWheelPicker({
    required this.selectedAttribute,
    required this.orderedAttributes,
    required this.colorForAttribute,
    required this.onSelectAttribute,
    required this.onClear,
  });

  void _handleTapAt(Offset localPosition) {
    const double size = 500;
    const double innerRadiusFraction = 0.32;
    final center = const Offset(size / 2, size / 2);
    final delta = localPosition - center;
    final radius = delta.distance;
    final outerRadius = size / 2;

    if (_buildInnerHexagonPath(
      Size.square(size),
      innerRadiusFraction,
    ).contains(localPosition)) {
      onClear();
      return;
    }
    if (radius > outerRadius) return;

    final sweepAngle = (2 * pi) / orderedAttributes.length;
    const centerStartAngle = -pi / 2;
    final angle = atan2(delta.dy, delta.dx);
    final normalized =
        (angle - centerStartAngle + (sweepAngle / 2) + (2 * pi)) % (2 * pi);
    final index = normalized ~/ sweepAngle;
    if (index >= 0 && index < orderedAttributes.length) {
      onSelectAttribute(orderedAttributes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double size = 500;
    const double innerRadiusFraction = 0.32;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTapAt(details.localPosition),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: Colors.white70, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withValues(alpha: 0.16),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AttributeWheelFramePainter(
                    segmentCount: orderedAttributes.length,
                    innerRadiusFraction: innerRadiusFraction,
                  ),
                ),
              ),
            ),
            ...orderedAttributes.asMap().entries.map((entry) {
              final index = entry.key;
              final attribute = entry.value;
              final isSelected = selectedAttribute == attribute;
              return Positioned.fill(
                child: _AttributeWheelSector(
                  size: size,
                  index: index,
                  total: orderedAttributes.length,
                  attribute: attribute,
                  color: colorForAttribute(attribute),
                  isSelected: isSelected,
                  innerRadiusFraction: innerRadiusFraction,
                  onTap: () => onSelectAttribute(attribute),
                ),
              );
            }),
            SizedBox.square(
              dimension: 185,
              child: CustomPaint(
                painter: _HexagonButtonPainter(
                  isAllSelected: selectedAttribute == null,
                  selectedIndex: selectedAttribute == null
                      ? -1
                      : orderedAttributes.indexOf(selectedAttribute!),
                  colors: orderedAttributes
                      .map((a) => colorForAttribute(a))
                      .toList(),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'ALL',
                      style: TextStyle(
                        fontFamily: 'button_font',
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Path _buildInnerHexagonPathFromRadius(Offset center, double radius) {
  final points = _buildInnerHexagonPoints(center, radius);
  return Path()
    ..moveTo(points.first.dx, points.first.dy)
    ..addPolygon(points, true);
}

Path _buildInnerHexagonPath(Size size, double radiusFraction) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = (size.width / 2) * radiusFraction;
  return _buildInnerHexagonPathFromRadius(center, radius);
}

List<Offset> _buildInnerHexagonPoints(Offset center, double radius) {
  const double boundaryStartAngle = -pi / 2 - pi / 6;
  return List<Offset>.generate(6, (index) {
    final angle = boundaryStartAngle + (index * pi / 3);
    return Offset(
      center.dx + cos(angle) * radius,
      center.dy + sin(angle) * radius,
    );
  });
}

class _AttributeWheelSector extends StatelessWidget {
  final double size;
  final int index;
  final int total;
  final String attribute;
  final Color color;
  final bool isSelected;
  final double innerRadiusFraction;
  final VoidCallback onTap;

  const _AttributeWheelSector({
    required this.size,
    required this.index,
    required this.total,
    required this.attribute,
    required this.color,
    required this.isSelected,
    required this.innerRadiusFraction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double startAngle = -pi / 2;
    final sweepAngle = (2 * pi) / total;
    final sectorStartAngle =
        startAngle + (index * sweepAngle) - (sweepAngle / 2);
    final sectorMidAngle = sectorStartAngle + (sweepAngle / 2);
    final outerRadius = size / 2;
    final innerRadius = outerRadius * innerRadiusFraction;
    final iconDistance = innerRadius + ((outerRadius - innerRadius) * 0.5147);
    final iconDx = cos(sectorMidAngle) * iconDistance;
    final iconDy = sin(sectorMidAngle) * iconDistance;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _WheelSectorPainter(
              sectorIndex: index,
              segmentCount: total,
              innerRadiusFraction: innerRadiusFraction,
              color: color,
              isSelected: isSelected,
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(iconDx, iconDy),
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(0, 0),
                  colors: [Colors.white, Colors.grey, Color(0xFF1A1A1A)],
                  stops: [0.0, 0.4, 1.0],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? color : Colors.black).withValues(
                      alpha: isSelected ? 0.38 : 0.42,
                    ),
                    blurRadius: isSelected ? 14 : 10,
                    offset: const Offset(3, 3),
                  ),
                ],
              ),
              child: Transform.translate(
                offset: const Offset(-0.75, -0.80),
                child: Image.asset(
                  'assets/images/attributes/${attribute}_game.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WheelSectorPainter extends CustomPainter {
  final int sectorIndex;
  final int segmentCount;
  final double innerRadiusFraction;
  final Color color;
  final bool isSelected;

  const _WheelSectorPainter({
    required this.sectorIndex,
    required this.segmentCount,
    required this.innerRadiusFraction,
    required this.color,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _sectorPath(size);
    if (isSelected) {
      // Glow/Beam effect from center
      final center = Offset(size.width / 2, size.height / 2);
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            color.withValues(alpha: 0.75),
            color.withValues(alpha: 0.3),
            Colors.transparent,
          ],
          stops: const [0.1, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));
      canvas.drawPath(path, fillPaint);

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawPath(path, glowPaint);
    }

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = isSelected ? color : Colors.white.withValues(alpha: 0.08);
    canvas.drawPath(path, strokePaint);
  }

  Path _sectorPath(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerPoints = _buildInnerHexagonPoints(
      center,
      outerRadius * innerRadiusFraction,
    );
    const double boundaryStartAngle = -pi / 2 - pi / 6;
    final sweepAngle = (2 * pi) / segmentCount;
    final startAngle = boundaryStartAngle + (sectorIndex * sweepAngle);
    final nextIndex = (sectorIndex + 1) % segmentCount;

    return Path()
      ..moveTo(
        center.dx + cos(startAngle) * outerRadius,
        center.dy + sin(startAngle) * outerRadius,
      )
      ..arcTo(outerRect, startAngle, sweepAngle, false)
      ..lineTo(innerPoints[nextIndex].dx, innerPoints[nextIndex].dy)
      ..lineTo(innerPoints[sectorIndex].dx, innerPoints[sectorIndex].dy)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _WheelSectorPainter oldDelegate) => true;
}

class _HexagonButtonPainter extends CustomPainter {
  final bool isAllSelected;
  final int selectedIndex;
  final List<Color> colors;

  const _HexagonButtonPainter({
    required this.isAllSelected,
    required this.selectedIndex,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Offset.zero & size;
    // Perfect sync with wheel dividers: 500 / 2 * 0.32 = 80.0
    const double hexRadius = 80.0;
    final path = _buildInnerHexagonPathFromRadius(center, hexRadius);

    if (isAllSelected) {
      // Strong color sits at the center of each side:
      // top Pyrus, upper-right Subterra, lower-right Haos,
      // bottom Darkus, lower-left Aquos, upper-left Ventus.
      final gradientColors = [...colors, colors.first];
      final gradientStops = List<double>.generate(
        gradientColors.length,
        (index) => index / colors.length,
      );
      const double startAngle = -pi / 2;

      final basePaint = Paint()..color = const Color(0xFF05080D);
      canvas.drawPath(path, basePaint);

      final innerShadePaint = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x3326313D), Color(0xFF05080D)],
          stops: [0.0, 0.78],
        ).createShader(rect);
      canvas.drawPath(path, innerShadePaint);

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: startAngle,
          endAngle: 2 * pi + startAngle,
          colors: gradientColors,
          stops: gradientStops,
        ).createShader(rect);
      canvas.drawPath(path, strokePaint);

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: startAngle,
          endAngle: 2 * pi + startAngle,
          colors: gradientColors
              .map((color) => color.withValues(alpha: 0.28))
              .toList(),
          stops: gradientStops,
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawPath(path, glowPaint);
    } else {
      // Standard dark look with no side-specific illumination while filtered.
      final fillPaint = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF060B14), Color(0xFF02050A)],
        ).createShader(rect);
      canvas.drawPath(path, fillPaint);

      // Full subtle border
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white70;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HexagonButtonPainter oldDelegate) => true;
}

class _AttributeWheelFramePainter extends CustomPainter {
  final int segmentCount;
  final double innerRadiusFraction;

  const _AttributeWheelFramePainter({
    required this.segmentCount,
    required this.innerRadiusFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * innerRadiusFraction;
    const startAngle = -pi / 2;
    final sweepAngle = (2 * pi) / segmentCount;

    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final dividerPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(center, outerRadius, outerPaint);
    final hexPoints = _buildInnerHexagonPoints(center, innerRadius);

    for (int i = 0; i < segmentCount; i++) {
      final angle = startAngle + (i * sweepAngle) - (sweepAngle / 2);
      final outerPoint = Offset(
        center.dx + cos(angle) * outerRadius,
        center.dy + sin(angle) * outerRadius,
      );
      final innerPoint = hexPoints[i];
      canvas.drawLine(innerPoint, outerPoint, dividerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AttributeWheelFramePainter oldDelegate) {
    return oldDelegate.segmentCount != segmentCount ||
        oldDelegate.innerRadiusFraction != innerRadiusFraction;
  }
}

class _SelectionInfoPanel extends StatelessWidget {
  final String text;

  const _SelectionInfoPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-0.15),
      child: Container(
        width: 700,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(0.15),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'button_font',
              fontSize: 16,
              color: Colors.white70,
              height: 1.4,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarTriggerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final String? leadingAsset;
  final bool isEnabled;
  final VoidCallback onTap;

  const _ToolbarTriggerButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.leadingAsset,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.15),
        child: GestureDetector(
          onTap: isEnabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.9),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(0.15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingAsset != null) ...[
                    Image.asset(
                      leadingAsset!,
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'button_font',
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.35,
      child: _ControlChipShell(
        isSelected: isSelected,
        color: Colors.blueAccent,
        onTap: isEnabled ? onTap : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'button_font',
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlChipShell extends StatelessWidget {
  final bool isSelected;
  final Color color;
  final VoidCallback? onTap;
  final Widget child;

  const _ControlChipShell({
    required this.isSelected,
    required this.color,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-0.15),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.white24,
              width: isSelected ? 2 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(0.15),
            child: child,
          ),
        ),
      ),
    );
  }
}
