part of '../../main.dart';

class CardCatalogEntry {
  final String key;
  final String name;
  final String type;
  final String cardClass;
  final String imagePath;
  final String descriptionEn;
  final String descriptionEs;
  final Map<String, int> attributes;

  const CardCatalogEntry({
    required this.key,
    required this.name,
    required this.type,
    required this.cardClass,
    required this.imagePath,
    required this.descriptionEn,
    required this.descriptionEs,
    required this.attributes,
  });

  String descriptionFor(AppLanguage lang) {
    if (lang == AppLanguage.es) {
      return descriptionEs.trim().isNotEmpty ? descriptionEs : descriptionEn;
    } else {
      return descriptionEn.trim().isNotEmpty ? descriptionEn : descriptionEs;
    }
  }

  String get description =>
      descriptionFor(LanguageController.instance.cardLanguage);

  String get typeLabel => type == 'gate' ? 'GATE CARD' : 'ABILITY CARD';
}

Future<List<CardCatalogEntry>> loadCardCatalog() async {
  const jsonPaths = [
    'assets/images/cards/cards.json',
    'assets/images/cards/cards_expansion.json',
  ];
  final cards = <String, dynamic>{};
  for (final jsonPath in jsonPaths) {
    final decoded = jsonDecode(await rootBundle.loadString(jsonPath));
    if (decoded is! Map || decoded['cards'] is! Map) continue;
    cards.addAll(Map<String, dynamic>.from(decoded['cards'] as Map));
  }

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

  final result = <CardCatalogEntry>[];
  for (final entry in cards.entries) {
    if (entry.value is! Map) continue;
    final data = Map<String, dynamic>.from(entry.value as Map);
    final name = (data['name'] ?? '').toString().trim();
    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    if (name.isEmpty || (type != 'gate' && type != 'ability')) continue;

    final descriptionsRaw = data['descriptions'];
    final descriptions = descriptionsRaw is Map
        ? Map<String, dynamic>.from(descriptionsRaw)
        : const <String, dynamic>{};
    final attributes = <String, int>{};
    final rawAttributes = data['attributes'];
    if (rawAttributes is Map) {
      for (final attribute in rawAttributes.entries) {
        final value = attribute.value is num
            ? (attribute.value as num).toInt()
            : int.tryParse(attribute.value.toString());
        if (value != null) {
          attributes[attribute.key.toString().toLowerCase()] = value;
        }
      }
    }

    result.add(
      CardCatalogEntry(
        key: entry.key,
        name: name,
        type: type,
        cardClass: (data['card_class'] ?? '').toString().toLowerCase(),
        imagePath:
            _matchCardImagePath(
              cardKey: entry.key,
              cardName: name,
              assetPaths: assets,
              fileName: data['file']?.toString(),
            ) ??
            'assets/images/cards/anverse.png',
        descriptionEn: descriptions['en']?.toString() ?? '',
        descriptionEs: descriptions['es']?.toString() ?? '',
        attributes: attributes,
      ),
    );
  }

  result.sort((a, b) {
    final typeCompare = a.type.compareTo(b.type);
    if (typeCompare != 0) return typeCompare;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return result;
}

Color _inventoryCardAccent(CardCatalogEntry card) {
  final palette = card.type == 'gate'
      ? _gateDescriptionAccentColors
      : _abilityDescriptionAccentColors;
  final fallback = card.type == 'gate' ? 'silver' : 'blue';
  return palette[card.cardClass] ?? palette[fallback]!;
}

List<Color> _inventoryCardGradient(CardCatalogEntry card) {
  final palette = card.type == 'gate'
      ? _gateDescriptionBorderGradients
      : _abilityDescriptionBorderGradients;
  final fallback = card.type == 'gate' ? 'silver' : 'blue';
  return palette[card.cardClass] ?? palette[fallback]!;
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  Map<String, int> _savedGPowerByInventoryKey = <String, int>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_playStoreMusic());
    unawaited(_loadInventory());
  }

  Future<void> _playStoreMusic() async {
    try {
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.setVolume(0.3);
      await _bgMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgMusicPlayer.play(AssetSource('music/menu/Store.mp3'));
    } catch (error, stackTrace) {
      debugPrint('Inventory music could not be played: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _loadInventory() async {
    await loadAvailableBakugans();
    final store = await LeaderboardRepository.instance.loadStore();
    final savedGPower = {
      for (final entry in store.bakuganInventory.bakugans)
        if (entry.gPower > 0) entry.inventoryKey: entry.gPower,
    };
    if (!mounted) return;
    setState(() {
      _savedGPowerByInventoryKey = savedGPower;
      _isLoading = false;
    });
  }

  List<BakuganVariant> get _allVariants => [
    for (final bakugan in availableBakugans) ...bakugan.variants,
  ];

  List<BakuganVariant> get _activeVariants => [
    for (final variant in _allVariants)
      if ((_savedGPowerByInventoryKey[bakuganVariantKey(variant)] ?? 0) > 0)
        variant.copyWith(
          gPower: _savedGPowerByInventoryKey[bakuganVariantKey(variant)],
        ),
  ];

  Future<void> _openBakuganCarousel() async {
    await Navigator.of(context).push(
      _zoomRoute(
        BakuganInventoryCarouselScreen(
          bakugans: availableBakugans,
          initialGPowerByInventoryKey: _savedGPowerByInventoryKey,
          onInventoryChanged: (activeVariants) {
            if (!mounted) return;
            setState(() {
              _savedGPowerByInventoryKey = {
                for (final variant in activeVariants)
                  bakuganVariantKey(variant): variant.gPower,
              };
            });
          },
        ),
      ),
    );
  }

  Future<void> _openCardsScreen() async {
    await Navigator.of(context).push(_zoomRoute(const InventoryCardsScreen()));
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _inventoryBackground(
        const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    return _inventoryBackground(
      SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildInventoryEntryPoints()),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryEntryPoints() {
    final compact = MediaQuery.sizeOf(context).width < 1200;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _InventoryEntryButton(
                      label: 'BAKUGAN',
                      subtitle: 'Manage the Bakugan available in selection',
                      color: Colors.cyanAccent,
                      emblem: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                      onTap: _openBakuganCarousel,
                    ),
                    const SizedBox(height: 22),
                    _InventoryEntryButton(
                      label: 'CARDS',
                      subtitle: 'Browse every card in the app',
                      color: Colors.amberAccent,
                      emblem: const Icon(
                        Icons.style_rounded,
                        color: Colors.amberAccent,
                        size: 76,
                      ),
                      onTap: _openCardsScreen,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _InventoryEntryButton(
                        label: 'BAKUGAN',
                        subtitle: 'Manage the Bakugan available in selection',
                        color: Colors.cyanAccent,
                        emblem: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                        onTap: _openBakuganCarousel,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _InventoryEntryButton(
                        label: 'CARDS',
                        subtitle: 'Browse every card in the app',
                        color: Colors.amberAccent,
                        emblem: const Icon(
                          Icons.style_rounded,
                          color: Colors.amberAccent,
                          size: 90,
                        ),
                        onTap: _openCardsScreen,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _inventoryBackground(Widget child) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/inventory_bg.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.68),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              unawaited(_playUiCancelSound());
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INVENTORY',
                  style: TextStyle(
                    fontFamily: 'title_font',
                    fontSize: 46,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [Shadow(color: Colors.cyan, blurRadius: 18)],
                  ),
                ),
                Text(
                  'BUILD YOUR COLLECTION  /  EXPLORE THE LIBRARY',
                  style: TextStyle(
                    fontFamily: 'button_font',
                    color: Colors.white60,
                    fontSize: 12,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          _buildInventoryCounter(),
        ],
      ),
    );
  }

  Widget _buildInventoryCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${_activeVariants.length} / ${_allVariants.length}',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'VARIANTS ACTIVE',
            style: TextStyle(
              color: Colors.white60,
              fontFamily: 'button_font',
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryEntryButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final Widget emblem;
  final VoidCallback onTap;

  const _InventoryEntryButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.emblem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        unawaited(_playUiConfirmSound());
        onTap();
      },
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.12),
        child: Container(
          height: 260,
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.72), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(0.12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: emblem),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'button_font',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontFamily: 'button_font',
                    fontSize: 11,
                    letterSpacing: 0.8,
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

class _InventoryToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _InventoryToggleButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: active ? 1 : 0.72,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.15),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: active ? 0.9 : 0.45),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: active ? 0.18 : 0.08),
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
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 9),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'button_font',
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
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

class InventoryCardsScreen extends StatefulWidget {
  const InventoryCardsScreen({super.key});

  @override
  State<InventoryCardsScreen> createState() => _InventoryCardsScreenState();
}

class _InventoryCardsScreenState extends State<InventoryCardsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final Future<List<CardCatalogEntry>> _cardsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _cardsFuture = loadCardCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CardCatalogEntry> _filteredCards(List<CardCatalogEntry> cards) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return cards;
    return cards
        .where(
          (card) =>
              card.name.toLowerCase().contains(query) ||
              card.typeLabel.toLowerCase().contains(query) ||
              card.description.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/inventory_bg.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.68),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            unawaited(_playUiCancelSound());
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'CARD LIBRARY',
                            style: TextStyle(
                              fontFamily: 'title_font',
                              fontSize: 42,
                              color: Colors.white,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(color: Colors.amber, blurRadius: 18),
                              ],
                            ),
                          ),
                        ),
                        FutureBuilder<List<CardCatalogEntry>>(
                          future: _cardsFuture,
                          builder: (context, snapshot) => Text(
                            snapshot.hasData
                                ? '${_filteredCards(snapshot.data!).length} CARDS'
                                : 'CARDS',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontFamily: 'button_font',
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(42, 4, 42, 10),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search cards',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.amberAccent,
                        ),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.62),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Colors.amberAccent,
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<CardCatalogEntry>>(
                      future: _cardsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'CARD LIBRARY UNAVAILABLE\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.amberAccent,
                            ),
                          );
                        }
                        final cards = _filteredCards(snapshot.data!);
                        if (cards.isEmpty) {
                          return const Center(
                            child: Text(
                              'NO CARDS MATCH YOUR SEARCH',
                              style: TextStyle(
                                color: Colors.white60,
                                fontFamily: 'button_font',
                                letterSpacing: 1.3,
                              ),
                            ),
                          );
                        }
                        return _CardCarousel(cards: cards);
                      },
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
}

class _CardCarousel extends StatefulWidget {
  final List<CardCatalogEntry> cards;

  const _CardCarousel({required this.cards});

  @override
  State<_CardCarousel> createState() => _CardCarouselState();
}

class _CardCarouselState extends State<_CardCarousel> {
  late final PageController _controller;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.32);
  }

  @override
  void didUpdateWidget(covariant _CardCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards != widget.cards) {
      _selectedIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex.clamp(0, widget.cards.length - 1);
    final card = widget.cards[selectedIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final descriptionWidth = min(940.0, constraints.maxWidth - 64);
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 32),
                    color: Colors.white70,
                    onPressed: () {
                      unawaited(_playUiConfirmSound());
                      _controller.previousPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: widget.cards.length,
                      onPageChanged: (index) {
                        setState(() => _selectedIndex = index);
                        unawaited(_playUiConfirmSound());
                      },
                      itemBuilder: (context, index) {
                        final item = widget.cards[index];
                        final selected = index == _selectedIndex;
                        return LayoutBuilder(
                          builder: (context, itemConstraints) {
                            final cardWidth = min(
                              440.0,
                              itemConstraints.maxWidth * 0.88,
                            );
                            return AnimatedScale(
                              scale: selected ? 1 : 0.84,
                              duration: const Duration(milliseconds: 180),
                              child: Center(
                                child: InteractiveCard(
                                  imagePath: item.imagePath,
                                  width: cardWidth,
                                  onTap: () {},
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 32),
                    color: Colors.white70,
                    onPressed: () {
                      unawaited(_playUiConfirmSound());
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
              child: FramedDescriptionPanel(
                width: descriptionWidth,
                esText: card.description.isEmpty
                    ? AppLocalizations.current.noDescription
                    : card.description,
                maxHeight: 220,
                frameGradient: _inventoryCardGradient(card),
                accentColor: _inventoryCardAccent(card),
                title: card.name,
                headerAction: Text(
                  '${card.typeLabel}  /  ${card.cardClass.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class BakuganInventoryCarouselScreen extends StatefulWidget {
  final List<Bakugan> bakugans;
  final Map<String, int>? initialGPowerByInventoryKey;
  final ValueChanged<List<BakuganVariant>>? onInventoryChanged;

  const BakuganInventoryCarouselScreen({
    super.key,
    required this.bakugans,
    this.initialGPowerByInventoryKey,
    this.onInventoryChanged,
  });

  @override
  State<BakuganInventoryCarouselScreen> createState() =>
      _BakuganInventoryCarouselScreenState();
}

class _BakuganInventoryCarouselScreenState
    extends State<BakuganInventoryCarouselScreen> {
  final PageController _carouselController = PageController(
    viewportFraction: 0.14,
  );
  static const List<String> _attributeWheelOrder = [
    'pyrus',
    'subterra',
    'haos',
    'darkus',
    'aquos',
    'ventus',
  ];

  int _selectedBakuganIndex = 0;
  int _selectedVariantIndex = 0;
  String? _selectedAttribute;
  _BakuganSortMode _sortMode = _BakuganSortMode.alphabetical;
  bool _collectionMode = false;
  final Map<String, int> _gPowerOverrides = <String, int>{};
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _gPowerOverrides.addAll(widget.initialGPowerByInventoryKey ?? const {});
  }

  List<BakuganVariant> get _allVariants => [
    for (final bakugan in widget.bakugans) ...bakugan.variants,
  ];

  BakuganVariant _effectiveVariant(BakuganVariant variant) {
    final override = _gPowerOverrides[bakuganVariantKey(variant)];
    return override == null ? variant : variant.copyWith(gPower: override);
  }

  List<BakuganVariant> get _activeVariants => [
    for (final variant in _allVariants)
      if (_isVariantOwned(variant)) _effectiveVariant(variant),
  ];

  bool _isVariantOwned(BakuganVariant variant) {
    return (_gPowerOverrides[bakuganVariantKey(variant)] ?? 0) > 0;
  }

  void _setCollectionMode(bool enabled) {
    if (_collectionMode == enabled) return;
    unawaited(_playUiConfirmSound());
    final currentBakugans = _visibleBakugans;
    final currentSpeciesName = _selectedBakuganIndex < currentBakugans.length
        ? currentBakugans[_selectedBakuganIndex].name
        : null;
    setState(() {
      _collectionMode = enabled;
      _syncSelection(preferredSpeciesName: currentSpeciesName);
    });
  }

  Future<void> _clearAllGPower() async {
    if (_activeVariants.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 180,
            vertical: 140,
          ),
          child: _SelectionOverlayShell(
            title: 'CLEAR ALL G POWER',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This removes every saved G-Power from your collection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'button_font',
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BakuganButton(
                      text: 'CANCEL',
                      onPressed: () => Navigator.of(context).pop(false),
                      width: 180,
                      height: 62,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 14),
                    BakuganButton(
                      text: 'CLEAR ALL',
                      onPressed: () => Navigator.of(context).pop(true),
                      width: 200,
                      height: 62,
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final currentBakugans = _visibleBakugans;
    final currentSpeciesName = _selectedBakuganIndex < currentBakugans.length
        ? currentBakugans[_selectedBakuganIndex].name
        : null;
    setState(() {
      for (final variant in _allVariants) {
        _gPowerOverrides[bakuganVariantKey(variant)] = 0;
      }
      _syncSelection(preferredSpeciesName: currentSpeciesName);
    });
    _queueInventorySave();
  }

  void _queueInventorySave() {
    final snapshot = _activeVariants.toList();
    widget.onInventoryChanged?.call(snapshot);
    _saveQueue = _saveQueue.then((_) async {
      await LeaderboardRepository.instance.saveBakuganInventory(snapshot);
    });
  }

  Bakugan _effectiveBakugan(Bakugan bakugan) {
    return Bakugan(
      name: bakugan.name,
      variants: bakugan.variants.map(_effectiveVariant).toList(),
    );
  }

  List<Bakugan> get _visibleBakugans {
    final allBakugans = widget.bakugans.map(_effectiveBakugan).toList();
    final sourceBakugans = _collectionMode
        ? allBakugans
              .map(
                (bakugan) => Bakugan(
                  name: bakugan.name,
                  variants: bakugan.variants.where(_isVariantOwned).toList(),
                ),
              )
              .where((bakugan) => bakugan.variants.isNotEmpty)
              .toList()
        : allBakugans;
    final visible = sourceBakugans
        .where(
          (bakugan) =>
              _selectedAttribute == null ||
              bakugan.variants.any(
                (variant) =>
                    variant.attribute.toLowerCase() == _selectedAttribute,
              ),
        )
        .toList();

    visible.sort((a, b) {
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
    return visible;
  }

  Bakugan get _currentBakugan => _visibleBakugans[_selectedBakuganIndex];
  BakuganVariant get _currentVariant =>
      _currentBakugan.variants[_selectedVariantIndex];

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

  void _syncSelection({String? preferredSpeciesName}) {
    final visibleBakugans = _visibleBakugans;
    if (visibleBakugans.isEmpty) {
      _selectedBakuganIndex = 0;
      _selectedVariantIndex = 0;
      return;
    }

    final currentSpeciesName =
        preferredSpeciesName ??
        (_selectedBakuganIndex < visibleBakugans.length
            ? visibleBakugans[_selectedBakuganIndex].name
            : null);
    final matchingIndex = currentSpeciesName == null
        ? -1
        : visibleBakugans.indexWhere(
            (bakugan) => bakugan.name == currentSpeciesName,
          );
    _selectedBakuganIndex = matchingIndex >= 0 ? matchingIndex : 0;
    _selectedVariantIndex = _preferredVariantIndex(
      visibleBakugans[_selectedBakuganIndex],
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_carouselController.hasClients) return;
      _carouselController.jumpToPage(_selectedBakuganIndex);
    });
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

  bool _showsPreyasDualAttributeIcon(BakuganVariant variant) {
    return variant.speciesName.trim().toLowerCase() == 'preyas diablo' &&
        variant.attribute.toLowerCase() != 'pyrus';
  }

  Future<void> _editGPower(BakuganVariant variant) async {
    final editedText = await _showSkewedInputPrompt(
      context: context,
      title:
          '${variant.speciesName.toUpperCase()}  /  ${variant.attribute.toUpperCase()}',
      confirmLabel: 'SAVE',
      initialValue: '${variant.gPower}',
      subtitle: 'Set the saved G-Power value for this Bakugan variant.',
      hintText: 'Enter G-Power',
      suffixText: 'G',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autofocus: true,
    );

    final key = bakuganVariantKey(variant);
    final previousValue = _gPowerOverrides[key] ?? 0;
    final editedValue = int.tryParse(editedText?.trim() ?? '');
    if (editedValue == null || editedValue == previousValue) return;
    setState(() {
      _gPowerOverrides[key] = editedValue;
    });
    _queueInventorySave();
  }

  Widget _buildInventoryToolbar(BoxConstraints constraints) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _BakuganCompactToolbar(
          width: min(1200.0, max(900.0, constraints.maxWidth - 280)),
          selectedAttribute: _selectedAttribute,
          sortMode: _sortMode,
          sortLabel: _sortModeLabel(_sortMode),
          sortIcon: _sortModeIcon(_sortMode),
          colorForAttribute: _colorForAttribute,
          onAttributeTap: _openAttributePicker,
          onSortTap: _openSortPicker,
          collectionMode: _collectionMode,
          onCollectionModeToggle: () => _setCollectionMode(!_collectionMode),
        ),
        _InventoryToggleButton(
          icon: Icons.clear_all_rounded,
          label: 'CLEAR ALL G POWER',
          color: Colors.redAccent,
          active: _activeVariants.isNotEmpty,
          onTap: _clearAllGPower,
        ),
      ],
    );
  }

  void _setAttributeFilter(String? attribute) {
    final currentSpeciesName =
        _visibleBakugans.isNotEmpty &&
            _selectedBakuganIndex < _visibleBakugans.length
        ? _visibleBakugans[_selectedBakuganIndex].name
        : null;
    unawaited(_playUiConfirmSound());
    setState(() {
      _selectedAttribute = attribute;
      if (attribute == null) _sortMode = _BakuganSortMode.alphabetical;
      _syncSelection(preferredSpeciesName: currentSpeciesName);
    });
  }

  void _setSortMode(_BakuganSortMode mode) {
    if (_selectedAttribute == null || _sortMode == mode) return;
    final currentSpeciesName =
        _visibleBakugans.isNotEmpty &&
            _selectedBakuganIndex < _visibleBakugans.length
        ? _visibleBakugans[_selectedBakuganIndex].name
        : null;
    unawaited(_playUiConfirmSound());
    setState(() {
      _sortMode = mode;
      _syncSelection(preferredSpeciesName: currentSpeciesName);
    });
  }

  Future<void> _openAttributePicker() async {
    unawaited(_playUiConfirmSound());
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
    unawaited(_playUiConfirmSound());
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

  void _setBakugan(int index) {
    final visibleBakugans = _visibleBakugans;
    setState(() {
      _selectedBakuganIndex = index;
      _selectedVariantIndex = _preferredVariantIndex(visibleBakugans[index]);
    });
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleBakugans = _visibleBakugans;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/inventory_bg.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.18),
                        Colors.redAccent.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 1800;
                  final horizontalPadding = isCompact ? 16.0 : 44.0;
                  final topSpacing = isCompact ? 18.0 : 42.0;

                  if (visibleBakugans.isEmpty) {
                    return _buildEmptyFilteredState(
                      horizontalPadding: horizontalPadding,
                      topSpacing: topSpacing,
                      constraints: constraints,
                    );
                  }

                  final bakugan = _currentBakugan;
                  final stageHeight = min(
                    540.0,
                    max(360.0, constraints.maxHeight - 390 - topSpacing),
                  );
                  final carouselWidth = max(520.0, constraints.maxWidth - 128);

                  return Column(
                    children: [
                      _buildCarouselHeader(
                        horizontalPadding: horizontalPadding,
                        topSpacing: topSpacing,
                        constraints: constraints,
                      ),
                      Expanded(
                        child: Transform.translate(
                          offset: Offset(0, isCompact ? -4 : -40),
                          child: Center(
                            child: _buildSelectionStage(
                              bakugan: bakugan,
                              constraints: constraints,
                              stageHeight: stageHeight,
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, isCompact ? -4 : -80),
                        child: _buildSpeciesCarousel(
                          visibleBakugans: visibleBakugans,
                          width: carouselWidth,
                          height: isCompact ? 150 : 180,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: isCompact ? 8 : 12,
                          top: 4,
                        ),
                        child: Text(
                          '${visibleBakugans.length} BAKUGAN',
                          style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'button_font',
                            fontSize: isCompact ? 9 : 11,
                            letterSpacing: 1.2,
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

  Widget _buildCarouselHeader({
    required double horizontalPadding,
    required double topSpacing,
    required BoxConstraints constraints,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        top: topSpacing,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.08),
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withValues(alpha: 0.54),
                const Color(0xCC071018),
                Colors.black.withValues(alpha: 0.42),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.cyanAccent.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(0.08),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildInventoryToolbar(constraints),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                    onPressed: () {
                      unawaited(_playUiCancelSound());
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredState({
    required double horizontalPadding,
    required double topSpacing,
    required BoxConstraints constraints,
  }) {
    return Column(
      children: [
        _buildCarouselHeader(
          horizontalPadding: horizontalPadding,
          topSpacing: topSpacing,
          constraints: constraints,
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Center(
              child: _SelectionInfoPanel(
                text: _collectionMode
                    ? 'No hay Bakugan en tu colección. Desactiva COLLECTION MODE para habilitar nuevos Bakugan.'
                    : 'No hay Bakugan para este atributo.',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionStage({
    required Bakugan bakugan,
    required BoxConstraints constraints,
    required double stageHeight,
  }) {
    final stageWidth = min(900.0, max(720.0, constraints.maxWidth - 32));
    final attributeRailWidth = min(140.0, stageWidth * 0.16);
    final previewLeft = attributeRailWidth - 40;

    return SizedBox(
      width: stageWidth,
      height: stageHeight,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: previewLeft,
            child: SizedBox(
              width: stageWidth - previewLeft,
              height: stageHeight,
              child: BakuganPreview(
                key: ValueKey(
                  'inventory_carousel_large_${_currentVariant.modelPath}_${_currentVariant.attribute}_${_currentVariant.texturePath}',
                ),
                variant: _currentVariant,
                isLarge: true,
                speciesName: bakugan.name,
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: SizedBox(
              height: stageHeight,
              width: attributeRailWidth,
              child: _buildSelectionAttributeRail(bakugan, stageHeight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionAttributeRail(Bakugan bakugan, double stageHeight) {
    const fixedItemHeight = 90.0;
    final isFullSet = bakugan.variants.length == 6;
    return Stack(
      clipBehavior: Clip.none,
      children: bakugan.variants.asMap().entries.map((entry) {
        final index = entry.key;
        final variant = entry.value;
        final isSelected = index == _selectedVariantIndex;
        final top = isFullSet
            ? index * (stageHeight - fixedItemHeight) / 5
            : index * fixedItemHeight;
        const popOutDistance = 30.0;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          top: top,
          left: isSelected
              ? index * -13.5 + 35 - popOutDistance
              : index * -13.5 + 35,
          child: GestureDetector(
            onTap: () {
              unawaited(_playUiConfirmSound());
              setState(() => _selectedVariantIndex = index);
            },
            onLongPress: () => _editGPower(variant),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(-0.15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: isSelected ? 100 + popOutDistance : 100,
                height: fixedItemHeight,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? variant.color.withValues(alpha: 0.4)
                      : Colors.black45,
                  border: Border(
                    top: BorderSide(
                      color: isSelected ? variant.color : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                    left: BorderSide(
                      color: isSelected ? variant.color : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                    bottom: BorderSide(
                      color: isSelected ? variant.color : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: variant.color.withValues(alpha: 0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.skewX(0.15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Opacity(
                          opacity: 1,
                          child: _showsPreyasDualAttributeIcon(variant)
                              ? ClipRect(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
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
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                      Text(
                        '${variant.gPower}G',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : Colors.white70,
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
  }

  Widget _buildSpeciesCarousel({
    required List<Bakugan> visibleBakugans,
    required double width,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 40),
            color: Colors.cyanAccent,
            onPressed: () {
              unawaited(_playUiConfirmSound());
              _carouselController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
          ),
          SizedBox(
            width: width,
            child: PageView.builder(
              controller: _carouselController,
              padEnds: false,
              itemCount: visibleBakugans.length,
              onPageChanged: _setBakugan,
              itemBuilder: (context, index) {
                final variant = _primaryVariantForSpecies(
                  visibleBakugans[index],
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: BakuganPreview(
                    key: ValueKey(
                      'inventory_carousel_thumb_${variant.modelPath}_${variant.attribute}_${variant.texturePath}',
                    ),
                    variant: variant,
                    isSelected: _selectedBakuganIndex == index,
                    speciesName: visibleBakugans[index].name,
                    gridOpacityOverride: 0.14,
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 40),
            color: Colors.cyanAccent,
            onPressed: () {
              unawaited(_playUiConfirmSound());
              _carouselController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
          ),
        ],
      ),
    );
  }
}
