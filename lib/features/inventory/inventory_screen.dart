part of '../../main.dart';

enum _InventorySection { bakugans, cards }

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

  String get description =>
      descriptionEs.trim().isNotEmpty ? descriptionEs : descriptionEn;

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

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cardSearchController = TextEditingController();
  _InventorySection _section = _InventorySection.bakugans;
  Set<String> _includedKeys = <String>{};
  bool _isLoading = true;
  Future<List<CardCatalogEntry>>? _cardsFuture;
  Future<void> _saveQueue = Future<void>.value();
  String _searchQuery = '';
  String _cardSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _cardSearchController.addListener(_onCardSearchChanged);
    unawaited(_playStoreMusic());
    unawaited(_loadInventory());
  }

  Future<void> _playStoreMusic() async {
    try {
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.setVolume(0.3);
      await _bgMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgMusicPlayer.play(AssetSource('music/menu/Store.flac'));
    } catch (_) {}
  }

  Future<void> _loadInventory() async {
    await loadAvailableBakugans();
    final store = await LeaderboardRepository.instance.loadStore();
    final savedKeys = store.bakuganInventory.bakugans
        .map((entry) => entry.inventoryKey)
        .toSet();
    if (!mounted) return;
    setState(() {
      _includedKeys = store.bakuganInventory.isConfigured
          ? savedKeys
          : _allVariants.map(bakuganVariantKey).toSet();
      _isLoading = false;
    });
  }

  List<BakuganVariant> get _allVariants => [
    for (final bakugan in availableBakugans) ...bakugan.variants,
  ];

  List<BakuganVariant> get _activeVariants => _allVariants
      .where((variant) => _includedKeys.contains(bakuganVariantKey(variant)))
      .toList();

  List<Bakugan> get _filteredBakugans {
    final query = _searchQuery.trim().toLowerCase();
    return availableBakugans.where((bakugan) {
      if (query.isNotEmpty &&
          !bakugan.name.toLowerCase().contains(query) &&
          !bakugan.variants.any(
            (variant) => variant.attribute.toLowerCase().contains(query),
          )) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Bakugan> get _activeBakugans {
    return availableBakugans
        .map(
          (bakugan) => Bakugan(
            name: bakugan.name,
            variants: bakugan.variants
                .where(
                  (variant) =>
                      _includedKeys.contains(bakuganVariantKey(variant)),
                )
                .toList(),
          ),
        )
        .where((bakugan) => bakugan.variants.isNotEmpty)
        .toList();
  }

  List<CardCatalogEntry> _filterCards(List<CardCatalogEntry> cards) {
    final query = _cardSearchQuery.trim().toLowerCase();
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

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _searchQuery = _searchController.text);
  }

  void _onCardSearchChanged() {
    if (!mounted) return;
    setState(() => _cardSearchQuery = _cardSearchController.text);
  }

  void _selectSection(_InventorySection section) {
    unawaited(_playUiConfirmSound());
    setState(() {
      _section = section;
      if (section == _InventorySection.cards) {
        _cardsFuture ??= loadCardCatalog();
      }
    });
  }

  void _toggleVariant(BakuganVariant variant) {
    final key = bakuganVariantKey(variant);
    setState(() {
      if (_includedKeys.contains(key)) {
        _includedKeys.remove(key);
      } else {
        _includedKeys.add(key);
      }
    });
    _queueSave();
  }

  void _toggleSpecies(Bakugan bakugan, bool enabled) {
    setState(() {
      for (final variant in bakugan.variants) {
        final key = bakuganVariantKey(variant);
        if (enabled) {
          _includedKeys.add(key);
        } else {
          _includedKeys.remove(key);
        }
      }
    });
    _queueSave();
  }

  void _queueSave() {
    final snapshot = _activeVariants.toList();
    _saveQueue = _saveQueue.then((_) async {
      await LeaderboardRepository.instance.saveBakuganInventory(snapshot);
    });
  }

  Future<void> _openBakuganCarousel() async {
    if (_activeBakugans.isEmpty) return;
    await Navigator.of(context).push(
      _zoomRoute(BakuganInventoryCarouselScreen(bakugans: _activeBakugans)),
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _cardSearchController
      ..removeListener(_onCardSearchChanged)
      ..dispose();
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
            _buildSectionNavigation(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _section == _InventorySection.bakugans
                    ? _buildBakuganSection()
                    : _buildCardsSection(),
              ),
            ),
          ],
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
            image: AssetImage('assets/images/selection-bg.png'),
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

  Widget _buildSectionNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _InventoryNavButton(
              icon: Icons.blur_on_rounded,
              label: 'BAKUGAN',
              subtitle: 'Choose what appears in battles',
              color: Colors.cyanAccent,
              selected: _section == _InventorySection.bakugans,
              onTap: () => _selectSection(_InventorySection.bakugans),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _InventoryNavButton(
              icon: Icons.style_rounded,
              label: 'CARDS',
              subtitle: 'Browse every card in the app',
              color: Colors.amberAccent,
              selected: _section == _InventorySection.cards,
              onTap: () => _selectSection(_InventorySection.cards),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBakuganSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1600;
        final filteredBakugans = _filteredBakugans;
        final horizontalPadding = isCompact ? 24.0 : 42.0;
        final columns = constraints.maxWidth >= 1180 ? 2 : 1;
        return Column(
          key: const ValueKey(_InventorySection.bakugans),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                4,
                horizontalPadding,
                10,
              ),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSearchField(_searchController, 'Search Bakugan'),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: BakuganButton(
                            text: 'OPEN CAROUSEL',
                            icon: Icons.view_carousel_rounded,
                            onPressed: _openBakuganCarousel,
                            width: min(280, constraints.maxWidth),
                            height: 62,
                            color: Colors.cyanAccent,
                            textFontSize: 21,
                            iconSize: 23,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildSearchField(
                            _searchController,
                            'Search Bakugan',
                          ),
                        ),
                        const SizedBox(width: 16),
                        BakuganButton(
                          text: 'OPEN CAROUSEL',
                          icon: Icons.view_carousel_rounded,
                          onPressed: _openBakuganCarousel,
                          width: 300,
                          height: 70,
                          color: Colors.cyanAccent,
                          textFontSize: 25,
                          iconSize: 26,
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: filteredBakugans.isEmpty
                  ? const Center(
                      child: Text(
                        'NO BAKUGAN MATCHES YOUR SEARCH',
                        style: TextStyle(
                          color: Colors.white60,
                          fontFamily: 'button_font',
                          letterSpacing: 1.3,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        6,
                        horizontalPadding,
                        32,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: isCompact
                            ? (columns == 2 ? 2.28 : 2.1)
                            : (columns == 2 ? 2.45 : 2.3),
                      ),
                      itemCount: filteredBakugans.length,
                      itemBuilder: (context, index) => _InventoryBakuganCard(
                        bakugan: filteredBakugans[index],
                        isIncluded: _isSpeciesIncluded(filteredBakugans[index]),
                        isVariantIncluded: (variant) =>
                            _includedKeys.contains(bakuganVariantKey(variant)),
                        onToggleSpecies: (enabled) =>
                            _toggleSpecies(filteredBakugans[index], enabled),
                        onToggleVariant: _toggleVariant,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  bool _isSpeciesIncluded(Bakugan bakugan) {
    return bakugan.variants.any(
      (variant) => _includedKeys.contains(bakuganVariantKey(variant)),
    );
  }

  Widget _buildCardsSection() {
    return FutureBuilder<List<CardCatalogEntry>>(
      key: const ValueKey(_InventorySection.cards),
      future: _cardsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'CARD LIBRARY UNAVAILABLE\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: Colors.amberAccent),
          );
        }

        final cards = _filterCards(snapshot.data!);
        if (cards.isEmpty) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(42, 4, 42, 10),
                child: _buildSearchField(_cardSearchController, 'Search cards'),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'NO CARDS MATCH YOUR SEARCH',
                    style: TextStyle(
                      color: Colors.white60,
                      fontFamily: 'button_font',
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(42, 4, 42, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSearchField(
                      _cardSearchController,
                      'Search cards',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${cards.length} CARDS',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontFamily: 'button_font',
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _CardCarousel(cards: cards)),
          ],
        );
      },
    );
  }

  Widget _buildSearchField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.cyanAccent),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                onPressed: controller.clear,
              ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.62),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Colors.cyanAccent, width: 1.6),
        ),
      ),
    );
  }
}

class _InventoryNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _InventoryNavButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: selected ? 0.82 : 0.54),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.9 : 0.25),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontFamily: 'button_font',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: color.withValues(alpha: selected ? 1 : 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryBakuganCard extends StatelessWidget {
  final Bakugan bakugan;
  final bool isIncluded;
  final bool Function(BakuganVariant variant) isVariantIncluded;
  final ValueChanged<bool> onToggleSpecies;
  final ValueChanged<BakuganVariant> onToggleVariant;

  const _InventoryBakuganCard({
    required this.bakugan,
    required this.isIncluded,
    required this.isVariantIncluded,
    required this.onToggleSpecies,
    required this.onToggleVariant,
  });

  @override
  Widget build(BuildContext context) {
    final previewVariant = bakugan.variants.first;
    final includedCount = bakugan.variants.where(isVariantIncluded).length;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isIncluded
              ? previewVariant.color.withValues(alpha: 0.72)
              : Colors.white12,
          width: isIncluded ? 1.6 : 1,
        ),
        boxShadow: isIncluded
            ? [
                BoxShadow(
                  color: previewVariant.color.withValues(alpha: 0.12),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            height: double.infinity,
            child: Container(
              color: previewVariant.color.withValues(alpha: 0.07),
              padding: const EdgeInsets.all(8),
              child: Opacity(
                opacity: isIncluded ? 1 : 0.34,
                child: BakuganPreview(
                  key: ValueKey(
                    'inventory_${previewVariant.modelPath}_${previewVariant.attribute}',
                  ),
                  variant: previewVariant,
                  isDeck: true,
                  autoRotate: false,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bakugan.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'button_font',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      Switch(
                        value: isIncluded,
                        activeThumbColor: previewVariant.color,
                        onChanged: onToggleSpecies,
                      ),
                    ],
                  ),
                  Text(
                    '$includedCount / ${bakugan.variants.length} ATTRIBUTES IN MATCHES',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontFamily: 'button_font',
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: bakugan.variants
                            .map(
                              (variant) => _InventoryAttributeChip(
                                variant: variant,
                                selected: isVariantIncluded(variant),
                                onTap: () => onToggleVariant(variant),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Tap an attribute to include or hide it',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryAttributeChip extends StatelessWidget {
  final BakuganVariant variant;
  final bool selected;
  final VoidCallback onTap;

  const _InventoryAttributeChip({
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? variant.color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? variant.color.withValues(alpha: 0.8)
                : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: selected ? 1 : 0.38,
              child: Image.asset(
                'assets/images/attributes/${variant.attribute}_game.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.circle, size: 16, color: variant.color),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${variant.gPower}G',
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w900,
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
    _controller = PageController(viewportFraction: 0.28);
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
                    return AnimatedScale(
                      scale: selected ? 1 : 0.84,
                      duration: const Duration(milliseconds: 180),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 842 / 1130,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: Colors.amberAccent.withValues(
                                          alpha: 0.34,
                                        ),
                                        blurRadius: 26,
                                        spreadRadius: 3,
                                      ),
                                    ]
                                  : null,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              item.imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                    'assets/images/cards/anverse.png',
                                    fit: BoxFit.cover,
                                  ),
                            ),
                          ),
                        ),
                      ),
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
          padding: const EdgeInsets.fromLTRB(44, 4, 44, 22),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 840),
            padding: const EdgeInsets.fromLTRB(22, 15, 22, 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontFamily: 'button_font',
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${card.typeLabel}  /  ${card.cardClass.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (card.attributes.isNotEmpty) ...[
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 240,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      alignment: WrapAlignment.end,
                      children: card.attributes.entries
                          .where((entry) => entry.value > 0)
                          .map(
                            (entry) => Text(
                              '${entry.key.toUpperCase()} ${entry.value}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BakuganInventoryCarouselScreen extends StatefulWidget {
  final List<Bakugan> bakugans;

  const BakuganInventoryCarouselScreen({super.key, required this.bakugans});

  @override
  State<BakuganInventoryCarouselScreen> createState() =>
      _BakuganInventoryCarouselScreenState();
}

class _BakuganInventoryCarouselScreenState
    extends State<BakuganInventoryCarouselScreen> {
  final PageController _carouselController = PageController(
    viewportFraction: 0.2,
  );
  int _selectedBakuganIndex = 0;
  int _selectedVariantIndex = 0;

  Bakugan get _currentBakugan => widget.bakugans[_selectedBakuganIndex];
  BakuganVariant get _currentVariant =>
      _currentBakugan.variants[_selectedVariantIndex];

  void _setBakugan(int index) {
    setState(() {
      _selectedBakuganIndex = index;
      _selectedVariantIndex = 0;
    });
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1600;
    final bakugan = _currentBakugan;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/selection-bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
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
                      'BAKUGAN CAROUSEL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'title_font',
                        fontSize: isCompact ? 26 : 34,
                        color: Colors.white,
                        letterSpacing: 1.3,
                        shadows: [Shadow(color: Colors.cyan, blurRadius: 18)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 16 : 44,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: isCompact ? 104 : 142,
                        child: _buildAttributeRail(bakugan),
                      ),
                      Expanded(
                        child: BakuganPreview(
                          key: ValueKey(
                            'inventory_carousel_${_currentVariant.modelPath}_${_currentVariant.attribute}',
                          ),
                          variant: _currentVariant,
                          isLarge: true,
                          speciesName: bakugan.name,
                          centerLargeFooter: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: isCompact ? 120 : 152,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 34),
                      color: Colors.white70,
                      onPressed: () {
                        _carouselController.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _carouselController,
                        itemCount: widget.bakugans.length,
                        onPageChanged: _setBakugan,
                        itemBuilder: (context, index) {
                          final item = widget.bakugans[index];
                          final variant = item.variants.first;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: BakuganPreview(
                              key: ValueKey(
                                'inventory_carousel_thumb_${variant.modelPath}_${variant.attribute}',
                              ),
                              variant: variant,
                              speciesName: item.name,
                              isSelected: index == _selectedBakuganIndex,
                              autoRotate: false,
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 34,
                      ),
                      color: Colors.white70,
                      onPressed: () {
                        _carouselController.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: isCompact ? 8 : 12, top: 4),
                child: Text(
                  '${widget.bakugans.length} BAKUGAN  /  ${widget.bakugans.fold<int>(0, (sum, item) => sum + item.variants.length)} ACTIVE VARIANTS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'button_font',
                    fontSize: isCompact ? 9 : 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttributeRail(Bakugan bakugan) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: bakugan.variants.asMap().entries.map((entry) {
        final index = entry.key;
        final variant = entry.value;
        final selected = index == _selectedVariantIndex;
        return GestureDetector(
          onTap: () {
            unawaited(_playUiConfirmSound());
            setState(() => _selectedVariantIndex = index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? variant.color.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? variant.color : Colors.white12,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/attributes/${variant.attribute}_game.png',
                  width: 30,
                  height: 30,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.circle, color: variant.color),
                ),
                const SizedBox(width: 7),
                Text(
                  '${variant.gPower}G',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
