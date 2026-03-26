part of '../../main.dart';

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
  int currentPlayerIndex = 0;
  int selectedBakuganIndex = 0;
  int selectedVariantIndex = 0;
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
    await _sfxPlayer.play(AssetSource('sound/select.wav'));
  }

  bool _isVariantTaken(BakuganVariant variant) {
    for (var p in widget.players) {
      if (p.deck.any((v) => v.modelPath == variant.modelPath)) return true;
    }
    return false;
  }

  void _addBakugan() {
    final species = availableBakugans[selectedBakuganIndex];
    final variant = species.variants[selectedVariantIndex];

    if (_isVariantTaken(variant)) return;

    _playClick();
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
    _playClick();
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
    if (availableBakugans.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final currentPlayer = widget.players[currentPlayerIndex];
    final currentSpecies = availableBakugans[selectedBakuganIndex];
    final currentVariant = currentSpecies.variants[selectedVariantIndex];
    final bool currentIsTaken = _isVariantTaken(currentVariant);

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
                  _playClick();
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
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 5),
                  Expanded(
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
                                                          // Dims it instead of greying the whole layer
                                                          child: Image.asset(
                                                            'assets/images/attributes/${variant.attribute}_game.png',
                                                            fit: BoxFit.contain,
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
                  // CAROUSEL
                  Transform.translate(
                    offset: const Offset(0, -100), // Moved MORE UP
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
                              itemCount: availableBakugans.length,
                              onPageChanged: (idx) => setState(() {
                                selectedBakuganIndex = idx;
                                selectedVariantIndex = 0;
                              }),
                              itemBuilder: (context, idx) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                child: BakuganPreview(
                                  key: ValueKey(
                                    'preview_${availableBakugans[idx].variants[0].modelPath}',
                                  ),
                                  variant: availableBakugans[idx].variants[0],
                                  isSelected: selectedBakuganIndex == idx,
                                  speciesName: availableBakugans[idx].name,
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
                    offset: const Offset(0, -50),
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
