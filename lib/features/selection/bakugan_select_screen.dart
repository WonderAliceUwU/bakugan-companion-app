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

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer();
  }

  void _playClick() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sound/select_2.wav'));
  }

  bool _isVariantBanned(BakuganVariant variant) {
    final speciesName = variant.speciesName.toLowerCase();
    final modelPath = variant.modelPath.toLowerCase();
    return speciesName.contains('banned') || modelPath.contains('banned');
  }

  bool _isPreyasDiablo(BakuganVariant variant) =>
      variant.speciesName.trim().toLowerCase() == 'preyas diablo';

  bool _showsPreyasDualAttributeIcon(BakuganVariant variant) =>
      _isPreyasDiablo(variant) && variant.attribute.toLowerCase() != 'pyrus';

  bool _isVariantTaken(BakuganVariant variant) {
    if (_isVariantBanned(variant)) return true;
    for (var p in widget.players) {
      if (p.deck.any((v) => v.modelPath == variant.modelPath)) return true;
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
    final species = _selectedAttribute == null
        ? [...availableBakugans]
        : availableBakugans
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
          return _primaryVariantForSpecies(a).gPower.compareTo(
            _primaryVariantForSpecies(b).gPower,
          );
        case _BakuganSortMode.gPowerDesc:
          return _primaryVariantForSpecies(b).gPower.compareTo(
            _primaryVariantForSpecies(a).gPower,
          );
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
    final currentSpeciesName = _visibleBakugans()[selectedBakuganIndex].name;
    setState(() {
      _sortMode = mode;
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
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleBakugans = _visibleBakugans();

    if (availableBakugans.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (visibleBakugans.isEmpty) {
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
              Positioned.fill(
                left: 600,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      widget.players[currentPlayerIndex].name.toUpperCase(),
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
                    ),
                    const SizedBox(height: 24),
                    _SelectionInfoPanel(
                      text:
                          'No hay Bakugan para este atributo. Cambia el filtro para seguir seleccionando.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSelectedBakugan(visibleBakugans)) {
      selectedBakuganIndex = 0;
    }

    final currentPlayer = widget.players[currentPlayerIndex];
    final currentSpecies = visibleBakugans[selectedBakuganIndex];
    final preferredVariantIndex = _preferredVariantIndex(currentSpecies);
    if (_selectedAttribute != null && selectedVariantIndex != preferredVariantIndex) {
      selectedVariantIndex = preferredVariantIndex;
    }
    final currentVariant = currentSpecies.variants[selectedVariantIndex];
    final bool currentIsBanned = _isVariantBanned(currentVariant);
    final bool currentIsTaken = _isVariantTaken(currentVariant);
    final String? currentStatusLabel = currentIsBanned
        ? 'BANNED'
        : (currentIsTaken ? 'PICKED' : null);

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
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -40),
                      child: Center(
                      child: SizedBox(
                        width: 900, // Fixed container for both elements
                        height: 500,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // 1. LARGE PREVIEW (Placed first so it's \"behind\" the tabs if needed)
                            Positioned(
                              left: 100,
                              // Gives space for the tabs to sit on the edge
                              child: SizedBox(
                                width: 800,
                                height: 500,
                                child: BakuganPreview(
                                  key: ValueKey(
                                    'large_${currentVariant.modelPath}',
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
                                height: 500,
                                width: 140,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final variants = currentSpecies.variants;
                                    const double fixedItemHeight = 90;
                                    final isFullSet = variants.length == 6;

                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: variants.asMap().entries.map((
                                        vEntry,
                                      ) {
                                        final index = vEntry.key;
                                        final variant = vEntry.value;
                                        bool isSel =
                                            index == selectedVariantIndex;
                                        bool isTaken = _isVariantTaken(variant);

                                        double top = isFullSet
                                            ? index *
                                                  (500 - fixedItemHeight) /
                                                  5
                                            : index * 90;

                                        // The horizontal \"staircase\" offset
                                        final double baseLeft =
                                            index * -13.5 + 35;
                                        // How much the tab should \"pop out\" to the left
                                        const double popOutDistance = 30;

                                        return AnimatedPositioned(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          top: top,
                                          // SUBTRACT to move it left (outwards)
                                          left: isSel
                                              ? baseLeft - popOutDistance
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
                                              alignment: Alignment.center,
                                              transform: Matrix4.skewX(-0.15),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 250,
                                                ),
                                                curve: Curves.easeOutCubic,
                                                // We increase width by the same distance so the right side
                                                // stays flush against the Preview
                                                width: isSel
                                                    ? (100 + popOutDistance)
                                                    : 100,
                                                height: fixedItemHeight,
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isTaken
                                                      ? Colors.grey.withValues(
                                                          alpha: 0.1,
                                                        )
                                                      : (isSel
                                                            ? variant.color
                                                                  .withValues(
                                                                    alpha: 0.4,
                                                                  )
                                                            : Colors.black45),
                                                  border: Border(
                                                    top: BorderSide(
                                                      color: isTaken
                                                          ? Colors.grey
                                                          : (isSel
                                                                ? variant.color
                                                                : Colors
                                                                      .white24),
                                                      width: isSel ? 2 : 1,
                                                    ),
                                                    left: BorderSide(
                                                      color: isTaken
                                                          ? Colors.grey
                                                          : (isSel
                                                                ? variant.color
                                                                : Colors
                                                                      .white24),
                                                      width: isSel ? 2 : 1,
                                                    ),
                                                    bottom: BorderSide(
                                                      color: isTaken
                                                          ? Colors.grey
                                                          : (isSel
                                                                ? variant.color
                                                                : Colors
                                                                      .white24),
                                                      width: isSel ? 2 : 1,
                                                    ),
                                                  ),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(15),
                                                        bottomLeft:
                                                            Radius.circular(15),
                                                      ),
                                                  boxShadow: isSel
                                                      ? [
                                                          BoxShadow(
                                                            color: variant.color
                                                                .withValues(
                                                                  alpha: 0.4,
                                                                ),
                                                            blurRadius: 15,
                                                            spreadRadius: 2,
                                                          ),
                                                        ]
                                                      : [],
                                                ),
                                                child: Transform(
                                                  alignment: Alignment.center,
                                                  transform: Matrix4.skewX(
                                                    0.15,
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Expanded(
                                                        child: Opacity(
                                                          opacity: isTaken
                                                              ? 0.3
                                                              : 1.0,
                                                          child:
                                                              _showsPreyasDualAttributeIcon(
                                                                variant,
                                                              )
                                                              ? ClipRect(
                                                                  child: FittedBox(
                                                                    fit: BoxFit
                                                                        .scaleDown,
                                                                    child: Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Image.asset(
                                                                          'assets/images/attributes/${variant.attribute}_game.png',
                                                                          fit: BoxFit
                                                                              .contain,
                                                                        ),
                                                                        const Padding(
                                                                          padding: EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                10,
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
                                                                          fit: BoxFit
                                                                              .contain,
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
                                                              FontWeight.w900,
                                                          color: isSel
                                                              ? Colors.white
                                                              : Colors.white70,
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 40),
                            onPressed: () {
                              _playClick();
                              _carouselController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                          SizedBox(
                            width: 1200,
                            child: PageView.builder(
                              controller: _carouselController,
                              itemCount: visibleBakugans.length,
                              onPageChanged: (idx) => setState(() {
                                selectedBakuganIndex = idx;
                                selectedVariantIndex = _preferredVariantIndex(
                                  visibleBakugans[idx],
                                );
                              }),
                              itemBuilder: (context, idx) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                child: BakuganPreview(
                                  key: ValueKey(
                                    'preview_${_primaryVariantForSpecies(visibleBakugans[idx]).modelPath}',
                                  ),
                                  variant: _primaryVariantForSpecies(
                                    visibleBakugans[idx],
                                  ),
                                  isSelected: selectedBakuganIndex == idx,
                                  speciesName: visibleBakugans[idx].name,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 40),
                            onPressed: () {
                              _playClick();
                              _carouselController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Row(
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
                    ),
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
  final String? selectedAttribute;
  final _BakuganSortMode sortMode;
  final String sortLabel;
  final IconData sortIcon;
  final Color Function(String attribute) colorForAttribute;
  final VoidCallback onAttributeTap;
  final VoidCallback onSortTap;

  const _BakuganCompactToolbar({
    required this.selectedAttribute,
    required this.sortMode,
    required this.sortLabel,
    required this.sortIcon,
    required this.colorForAttribute,
    required this.onAttributeTap,
    required this.onSortTap,
  });

  @override
  Widget build(BuildContext context) {
    final canSort = selectedAttribute != null;
    return SizedBox(
      width: 900,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(width: 16),
          _ToolbarTriggerButton(
            label: 'ORDER: $sortLabel',
            icon: sortIcon,
            accentColor: canSort ? Colors.blueAccent : Colors.white38,
            isEnabled: canSort,
            onTap: onSortTap,
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

    if (_buildInnerHexagonPath(Size.square(size), innerRadiusFraction).contains(
      localPosition,
    )) {
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

class _HexagonClipper extends CustomClipper<Path> {
  final double radiusFraction;

  const _HexagonClipper({required this.radiusFraction});

  @override
  Path getClip(Size size) => _buildInnerHexagonPath(size, radiusFraction);

  @override
  bool shouldReclip(covariant _HexagonClipper oldClipper) {
    return oldClipper.radiusFraction != radiusFraction;
  }
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
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
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
              color: Colors.black.withValues(alpha: 0.62),
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
