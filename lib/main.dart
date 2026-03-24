import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

// REPRODUCTOR GLOBAL PARA MÚSICA DE FONDO
final AudioPlayer _bgMusicPlayer = AudioPlayer();
final AudioPlayer _battleMusicPlayer = AudioPlayer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _bgMusicPlayer.stop();
  } catch (_) {}
  runApp(const BakuganApp());
}

class BakuganApp extends StatelessWidget {
  const BakuganApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bakugan Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'body_font',
      ),
      home: const VideoSplashScreen(),
    );
  }
}

Route _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 600),
  );
}

Route _zoomRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 800),
  );
}

// --- MODELOS DE DATOS ---
class BakuganVariant {
  final String attribute;
  final String modelPath;
  final Color color;
  final int gPower;
  final String speciesName;
  BakuganVariant({
    required this.attribute,
    required this.modelPath,
    required this.color,
    required this.gPower,
    required this.speciesName,
  });
}

class Bakugan {
  final String name;
  final List<BakuganVariant> variants;
  Bakugan({required this.name, required this.variants});
}

class PlayerData {
  final String name;
  final String character;
  final List<BakuganVariant> deck = [];
  PlayerData({required this.name, required this.character});

  int get totalGPower => deck.fold(0, (sum, item) => sum + item.gPower);
}

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

      if (effect is Map && effect['type'] == 'named_bakugan_bonus_per_used_gate') {
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
    }

    return GateCardBonusBreakdown(
      baseBonus: baseBonus,
      effectBonusSegments: effectBonusSegments,
    );
  }

  int calculateBonus(
    BakuganVariant variant, {
    int usedGateCardsInAllPiles = 0,
  }) {
    return bonusBreakdownFor(
      variant,
      usedGateCardsInAllPiles: usedGateCardsInAllPiles,
    ).totalBonus;
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

  bool get supportsStartOfBattle => timings.contains('start_of_battle');
  bool get supportsDuringBattle {
    if (timings.isEmpty) return true;
    return timings.any((timing) => timing != 'start_of_battle');
  }
}

const double _gateCardAspectRatio = 842 / 1130;
const double _gateCardHeight = 560;
const double _gateCardWidth = _gateCardHeight * _gateCardAspectRatio;
const Offset _battleBonusAnchor = Offset(-40, 0);
const Offset _battlePendingBonusOffset = Offset(0, -10);
const double _battleBonusRiseStart = 42;
const double _descriptionPanelSkew = 22;
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

      // Extract G-Power if present (e.g., "550g")
      int gPower = 0;
      if (parts.last.endsWith('g')) {
        gPower =
            int.tryParse(parts.last.substring(0, parts.last.length - 1)) ?? 0;
        parts.removeLast(); // Remove the gPower part for further processing
      }

      String attribute = parts.last.toLowerCase();
      String speciesName = parts.length > 1
          ? parts
                .sublist(0, parts.length - 1)
                .map((word) => word[0].toUpperCase() + word.substring(1))
                .join(' ')
          : fileName[0].toUpperCase() + fileName.substring(1);

      Color color = Colors.red;
      if (attribute.contains('pyrus'))
        color = Colors.red;
      else if (attribute.contains('aquos'))
        color = Colors.blue;
      else if (attribute.contains('subterra'))
        color = Colors.brown;
      else if (attribute.contains('haos'))
        color = Colors.limeAccent;
      else if (attribute.contains('darkus'))
        color = Colors.deepPurple;
      else if (attribute.contains('ventus'))
        color = Colors.teal;

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

// --- PANTALLAS ---

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});
  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;
  late AudioPlayer _sfxPlayer;
  bool _isFinished = false;
  double _overlayOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    loadAvailableBakugans();
    _sfxPlayer = AudioPlayer();
    _controller =
        VideoPlayerController.asset('assets/video/bakugan_opening.mp4')
          ..initialize().then((_) {
            if (mounted) {
              _controller.setVolume(0.5);
              setState(() {});
              _controller.play();
            }
          });
    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (_controller.value.isInitialized &&
        _controller.value.position >= _controller.value.duration &&
        !_isFinished) {
      _startTransition();
    }
  }

  void _startTransition() {
    if (_isFinished) return;
    setState(() {
      _isFinished = true;
      _overlayOpacity = 1.0;
    });
    _controller.pause();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(_fadeRoute(const MainMenuScreen()));
      }
    });
  }

  Future<void> _handleTap() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sound/select.wav'));
    } catch (_) {}
    _startTransition();
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Center(
              child: _controller.value.isInitialized
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.red),
            ),
            AnimatedOpacity(
              opacity: _overlayOpacity,
              duration: const Duration(milliseconds: 600),
              child: Container(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});
  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late AudioPlayer _sfxPlayer;

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer();
    _playBackgroundMusic('music/menu/Title.flac');
  }

  Future<void> _playBackgroundMusic(String asset) async {
    try {
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.setVolume(0.3);
      await _bgMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgMusicPlayer.play(AssetSource(asset));
    } catch (_) {}
  }

  Future<void> _playClick() async {
    try {
      await _sfxPlayer.setVolume(0.5);
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sound/select.wav'));
    } catch (_) {}
  }

  void _navigateToBattleMode() async {
    _playClick();
    await Navigator.of(context).push(_fadeRoute(const BattleModeScreen()));
    _playBackgroundMusic('music/menu/Title.flac');
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Menu.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BakuganButton(
                      text: 'BATTLE',
                      onPressed: _navigateToBattleMode,
                      width: 420,
                      height: 100,
                    ),
                    const SizedBox(height: 25),
                    BakuganButton(
                      text: 'LEADERBOARD',
                      onPressed: _playClick,
                      width: 420,
                      height: 100,
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

class BattleModeScreen extends StatefulWidget {
  const BattleModeScreen({super.key});
  @override
  State<BattleModeScreen> createState() => _BattleModeScreenState();
}

class _BattleModeScreenState extends State<BattleModeScreen> {
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

  @override
  void dispose() {
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Menu.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
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
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 80.0),
                child: Text(
                  'SELECT MODE',
                  style: TextStyle(
                    fontFamily: 'title_font',
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 30.0,
                        color: Colors.blue,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BakuganButton(
                    text: 'BATTLE\nROYALE',
                    onPressed: () {
                      _playClick();
                      Navigator.push(
                        context,
                        _fadeRoute(
                          const CharacterSelectScreen(isTeamBattle: false),
                        ),
                      );
                    },
                    width: 240,
                    height: 480,
                  ),
                  const SizedBox(width: 40),
                  BakuganButton(
                    text: 'TEAM\nBATTLE',
                    onPressed: () {
                      _playClick();
                      Navigator.push(
                        context,
                        _fadeRoute(
                          const CharacterSelectScreen(isTeamBattle: true),
                        ),
                      );
                    },
                    width: 240,
                    height: 480,
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

class CharacterSelectScreen extends StatefulWidget {
  final bool isTeamBattle;
  const CharacterSelectScreen({super.key, required this.isTeamBattle});
  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class GameActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const GameActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.15),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Neon Glow
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
            // Gradient Border Simulation
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.5), Colors.black],
            ),
          ),
          padding: const EdgeInsets.all(4), // Border thickness
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // The Icon (un-skewed so it stays upright)
                Center(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.skewX(0.15),
                    child: Icon(icon, color: color, size: 40),
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

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  late AudioPlayer _sfxPlayer;
  int playerCount = 2;
  int currentPlayerIndex = 0;
  List<String?> selectedCharacters = List.filled(4, null);
  late List<TextEditingController> _nameControllers;
  final List<String> characters = [
    'dan',
    'runo',
    'shun',
    'alice',
    'julie',
    'marucho',
    'masquerade',
  ];

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer();
    playerCount = widget.isTeamBattle ? 4 : 2;
    _nameControllers = List.generate(
      4,
      (i) => TextEditingController(text: 'PLAYER ${i + 1}'),
    );
    _playMenuMusic();
  }

  Future<void> _playMenuMusic() async {
    try {
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.play(AssetSource('music/menu/Menu.flac'));
    } catch (_) {}
  }

  void _playClick() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sound/select.wav'));
  }

  void _onOkPressed() {
    _playClick();
    if (selectedCharacters[currentPlayerIndex] == null) return;
    if (currentPlayerIndex < playerCount - 1) {
      setState(() => currentPlayerIndex++);
    } else {
      List<PlayerData> players = List.generate(
        playerCount,
        (i) => PlayerData(
          name: _nameControllers[i].text,
          character: selectedCharacters[i]!,
        ),
      );
      Navigator.push(
        context,
        _fadeRoute(
          BakuganSelectScreen(
            players: players,
            isTeamBattle: widget.isTeamBattle,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (var c in _nameControllers) c.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            Column(
              children: [
                const SizedBox(height: 50),
                const Text(
                  'SELECT CHARACTER',
                  style: TextStyle(
                    fontFamily: 'title_font',
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 20, color: Colors.blueAccent)],
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < playerCount; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: PlayerSlot(
                            controller: _nameControllers[i],
                            char: selectedCharacters[i],
                            isActive: i == currentPlayerIndex,
                            isBlue: i % 2 == 0,
                          ),
                        ),
                      if (!widget.isTeamBattle && playerCount < 4)
                        GameActionButton(
                          icon: Icons.add,
                          color: Colors.blueAccent,
                          onPressed: () {
                            _playClick();
                            setState(() => playerCount++);
                          },
                        ),
                      const SizedBox(width: 20),
                      if (!widget.isTeamBattle && playerCount > 2)
                        GameActionButton(
                          icon: Icons.remove,
                          color: Colors.redAccent,
                          onPressed: () {
                            _playClick();
                            setState(() {
                              playerCount--;
                              if (currentPlayerIndex >= playerCount) {
                                currentPlayerIndex = playerCount - 1;
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
                Container(
                  height: 220,
                  width: double.infinity,
                  color: Colors.black45,
                  child: Center(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: characters.length,
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () {
                          _playClick();
                          setState(
                            () => selectedCharacters[currentPlayerIndex] =
                                characters[index],
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 15,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1.1,
                            child: CharacterMiniature(
                              char: characters[index],
                              isSelected:
                                  selectedCharacters[currentPlayerIndex] ==
                                  characters[index],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30.0),
                  child: BakuganButton(
                    text: 'OK',
                    onPressed: _onOkPressed,
                    width: 280,
                    height: 80,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
    if (availableBakugans.isEmpty)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                                            height:
                                                100, // Restored to original large size
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
                                        padding: const EdgeInsets.only(
                                          left: 0,
                                        ), // Adjust this if you need a specific margin from the edge
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
                              left:
                                  100, // Gives space for the tabs to sit on the edge
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
                                                              : 1.0, // Dims it instead of greying the whole layer
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

class BakuganPreview extends StatefulWidget {
  final BakuganVariant variant;
  final bool isLarge;
  final bool isDeck;
  final bool isSelected;
  final String? speciesName;
  final bool isTaken;
  final double? theta;
  final double? phi;
  final bool autoRotate;
  final bool disableInteraction;
  final bool showGPower;
  final bool mirrorImage;

  const BakuganPreview({
    super.key,
    required this.variant,
    this.isLarge = false,
    this.isDeck = false,
    this.isSelected = false,
    this.speciesName,
    this.isTaken = false,
    this.theta,
    this.phi,
    this.autoRotate = true,
    this.disableInteraction = false,
    this.showGPower = true,
    this.mirrorImage = false,
  });

  @override
  State<BakuganPreview> createState() => _BakuganPreviewState();
}

class _BakuganPreviewState extends State<BakuganPreview>
    with AutomaticKeepAliveClientMixin {
  late Flutter3DController _controller;

  bool get _uses3DViewer {
    final path = widget.variant.modelPath.toLowerCase();
    return path.endsWith('.glb') || path.endsWith('.gltf');
  }

  double get _pngScale {
    if (widget.isLarge) return 1.12;
    if (widget.isDeck) return 1.08;
    return 1.06;
  }

  Alignment get _pngAlignment {
    if (widget.isLarge) return const Alignment(0.04, -0.03);
    if (widget.isDeck) return Alignment.center;
    return const Alignment(0.16, 0.0);
  }

  EdgeInsets get _pngPadding {
    if (widget.isLarge) return const EdgeInsets.fromLTRB(8, 8, 8, 52);
    return const EdgeInsets.all(8);
  }

  Widget _wrapPngImage(Widget child) {
    if (!widget.mirrorImage) return child;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = Flutter3DController();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant BakuganPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant.modelPath != widget.variant.modelPath ||
        oldWidget.isLarge != widget.isLarge ||
        oldWidget.isDeck != widget.isDeck) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _configureModelView();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _configureModelView({int attempt = 0}) async {
    if (!mounted || !_uses3DViewer) return;

    final double theta = widget.theta ?? (widget.isLarge ? 0 : 30);
    final double phi = widget.phi ?? 75;

    try {
      _controller.setCameraOrbit(theta, phi, 100);
      if (widget.isLarge && widget.autoRotate) {
        _controller.startRotation(rotationSpeed: 15);
      }
    } catch (_) {
      if (attempt >= 20) return;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      await _configureModelView(attempt: attempt + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.isDeck) return _buildModel(isDeck: true);

    final Color themeColor = widget.isTaken
        ? Colors.grey
        : widget.variant.color;
    final Color borderColor = widget.isLarge
        ? themeColor
        : (widget.isSelected ? themeColor : Colors.white24);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // --- THE MAIN FRAME ---
        Positioned.fill(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(-0.15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: borderColor,
                  width: widget.isLarge ? 4 : (widget.isSelected ? 3 : 1.5),
                ),
                boxShadow:
                    (widget.isSelected || widget.isLarge) && !widget.isTaken
                    ? [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.5),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.1),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  6,
                ), // Slightly smaller to stay inside border
                child: Stack(
                  children: [
                    // Grid Background
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GridPainter(
                          color: themeColor.withValues(
                            alpha: widget.isLarge ? 0.12 : 0.05,
                          ),
                        ),
                      ),
                    ),

                    // SMALL FOOTER (Now inside the clip and background stack)
                    if (!widget.isLarge && widget.speciesName != null)
                      _buildSmallFooter(borderColor),
                  ],
                ),
              ),
            ),
          ),
        ),

        // --- LARGE FOOTER (Separate plate for large view) ---
        if (widget.isLarge && widget.speciesName != null && !widget.isTaken)
          _buildLargeFooter(themeColor),

        // --- THE 3D MODEL ---
        Positioned.fill(
          child: Opacity(
            opacity: widget.isTaken ? 0.2 : 1.0,
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.isLarge ? 65 : 20),
              child: _buildModel(),
            ),
          ),
        ),

        if (widget.isTaken && widget.isLarge) _buildTakenOverlay(),
      ],
    );
  }

  Widget _buildSmallFooter(Color borderColor) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          border: Border(
            top: BorderSide(
              color: borderColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
        ),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(0.15), // Un-skew the text
          child: Text(
            widget.speciesName!.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'button_font',
              fontWeight: FontWeight.w900,
              color: widget.isSelected ? Colors.white : Colors.white60,
              fontStyle: FontStyle.italic,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeFooter(Color themeColor) {
    return Positioned(
      bottom: 0,
      left: -30,
      right: 33,
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
                  child: Text(
                    widget.speciesName!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'title_font',
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 10, color: themeColor)],
                    ),
                  ),
                ),
                if (widget.showGPower)
                  Transform.translate(
                    offset: const Offset(
                      0,
                      4,
                    ), // Increase '6' to move it further down
                    child: Text(
                      '${widget.variant.gPower}G',
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

  // --- MODEL & OVERLAY HELPERS ---
  Widget _buildModel({bool isDeck = false}) {
    if (!_uses3DViewer) {
      return IgnorePointer(
        ignoring: true,
        child: Padding(
          padding: _pngPadding,
          child: Align(
            alignment: _pngAlignment,
            child: Transform.scale(
              scale: _pngScale,
              child: _wrapPngImage(
                Image.asset(
                  widget.variant.modelPath,
                  key: ValueKey(
                    'image_${widget.variant.modelPath}_${widget.isLarge}_${widget.mirrorImage}',
                  ),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      ignoring: isDeck || widget.disableInteraction || !widget.isLarge,
      child: Flutter3DViewer(
        key: ValueKey('model_${widget.variant.modelPath}_${widget.isLarge}'),
        src: widget.variant.modelPath,
        controller: _controller,
        progressBarColor: Colors.transparent,
        onLoad: (_) {
          Future<void>.delayed(const Duration(milliseconds: 180), () {
            _configureModelView();
          });
        },
      ),
    );
  }

  Widget _buildTakenOverlay() {
    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          color: Colors.black87,
          child: const Text(
            'PICKED',
            style: TextStyle(
              fontFamily: 'title_font',
              fontSize: 60,
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerSlot extends StatelessWidget {
  final TextEditingController controller;
  final String? char;
  final bool isActive;
  final bool isBlue;

  const PlayerSlot({
    super.key,
    required this.controller,
    this.char,
    required this.isActive,
    required this.isBlue,
  });

  @override
  Widget build(BuildContext context) {
    // Bakugan Palettes
    final List<Color> blueGradient = [
      Colors.blueAccent,
      Colors.cyan,
      Colors.blue.shade900,
    ];
    final List<Color> redGradient = [
      Colors.redAccent,
      Colors.orange,
      Colors.yellowAccent,
    ];

    final currentGradient = isBlue ? blueGradient : redGradient;
    final themeColor = currentGradient[0];

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-0.15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 300,
        height: 480,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: isActive ? 0.6 : 0.2),
              blurRadius: isActive ? 30 : 10,
              spreadRadius: isActive ? 5 : 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            // Matching CharacterMiniature border thickness
            padding: EdgeInsets.all(isActive ? 6 : 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: currentGradient,
              ),
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  // --- GRID BACKGROUND ---
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GridPainter(
                        color: themeColor.withValues(alpha: 0.15),
                      ),
                    ),
                  ),

                  // --- CHARACTER IMAGE (Full Brightness) ---
                  if (char != null)
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.skewX(0.15),
                      child: TweenAnimationBuilder(
                        key: ValueKey(char),
                        tween: Tween<double>(begin: 2.2, end: 1.8),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        builder: (context, double value, child) {
                          return OverflowBox(
                            maxWidth: double.infinity,
                            maxHeight: double.infinity,
                            child: Transform.scale(
                              scale: value,
                              alignment: const Alignment(0.2, -1),
                              child: Image.asset(
                                'assets/images/characters/$char.png',
                                fit: BoxFit.cover,
                                width: 300,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // --- METALLIC SHINE (From Miniature) ---
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- NAME INPUT ---
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      // Horizontal padding is equalized to keep the text perfectly centered
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        border: Border(
                          top: BorderSide(color: themeColor, width: 3),
                        ),
                      ),
                      child: Transform(
                        alignment: Alignment.center,
                        // Counter-skew the text so it appears upright while the container stays \"flat\"
                        transform: Matrix4.skewX(0.15),
                        child: TextField(
                          controller: controller,
                          textAlign: TextAlign.center, // Now centered
                          style: const TextStyle(
                            fontSize: 26,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontStyle: FontStyle
                                .italic, // Matches the CharacterMiniature style
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
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
    );
  }
}

class CharacterMiniature extends StatelessWidget {
  final String char;
  final bool isSelected;
  final bool showName;
  final String? label;
  final double? glowAlpha;
  final double? thickness; // NEW: Overrides default border padding

  const CharacterMiniature({
    super.key,
    required this.char,
    required this.isSelected,
    this.showName = true,
    this.label,
    this.glowAlpha,
    this.thickness,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> activeGradient = [
      Colors.redAccent,
      Colors.orange,
      Colors.yellowAccent,
    ];
    final List<Color> idleGradient = [
      Colors.blueAccent,
      Colors.cyan,
      Colors.blue.shade900,
    ];

    final currentGradient = isSelected ? activeGradient : idleGradient;
    // Use custom label if provided, otherwise default to character name
    final String displayName = label ?? char;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-0.15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: currentGradient[0].withValues(
                alpha: glowAlpha ?? (isSelected ? 0.6 : 0.2),
              ),
              blurRadius: glowAlpha != null
                  ? 30
                  : (isSelected ? 20 : 10), // Boosted blur for battle screen
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.all(thickness ?? (isSelected ? 6 : 3)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: currentGradient,
              ),
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GridPainter(color: Colors.white10),
                    ),
                  ),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.skewX(0.15),
                    child: Transform.scale(
                      scale: 2.4,
                      alignment: const Alignment(-0.5, -1),
                      child: Image.asset(
                        'assets/images/characters/$char.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (showName)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          border: Border(
                            top: BorderSide(
                              color: currentGradient[0],
                              width: 1,
                            ),
                          ),
                        ),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.skewX(0.15),
                          child: Text(
                            displayName
                                .toUpperCase(), // Shows Player Name or Char Name
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize:
                                  14, // Slightly smaller to fit longer player names
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontStyle: FontStyle.italic,
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
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 20)
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += 20)
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class BakuganButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double width, height;
  final Color? color;
  const BakuganButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width = 250,
    this.height = 65,
    this.color,
  });
  @override
  State<BakuganButton> createState() => _BakuganButtonState();
}

class _BakuganButtonState extends State<BakuganButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) _pulse.reverse();
        });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? const Color(0xFF4A90E2);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + (_pulse.value * 0.08),
        child: GestureDetector(
          onTap: () {
            _pulse.forward();
            widget.onPressed();
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: widget.color ?? const Color(0xFF6A6A6A),
                width: 5,
              ),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: _pulse.value * 0.8),
                  blurRadius: 25 * _pulse.value,
                  spreadRadius: 8 * _pulse.value,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'button_font',
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      blurRadius: 12.0 + (_pulse.value * 15),
                      color: themeColor,
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
}

class PlayerArenaInfo extends StatelessWidget {
  final PlayerData player;
  final bool isMirrored;
  final Color themeColor;
  final Widget? extra;
  final bool isSelected;
  final double? glowAlpha;
  final double? thickness;
  final int? selectedBakuganIndex;
  final Function(int)? onBakuganTap;
  final bool isSelecting;

  const PlayerArenaInfo({
    super.key,
    required this.player,
    this.isMirrored = false,
    required this.themeColor,
    this.extra,
    this.isSelected = false,
    this.glowAlpha,
    this.thickness,
    this.selectedBakuganIndex,
    this.onBakuganTap,
    this.isSelecting = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> activeGradient = [
      Colors.redAccent,
      Colors.orange,
      Colors.yellowAccent,
    ];
    final List<Color> idleGradient = [
      Colors.blueAccent,
      Colors.cyan,
      Colors.blue.shade900,
    ];

    final children = [
      // --- CHARACTER PORTRAIT ---
      SizedBox(
        width: 180,
        height: 210, // Increased size
        child: CharacterMiniature(
          char: player.character,
          isSelected: isSelected,
          showName: true,
          label: player.name.toUpperCase(),
          glowAlpha: glowAlpha,
          thickness: thickness,
        ),
      ),
      const SizedBox(width: 40), // Increased gap
      // --- INFO & DECK ---
      Column(
        crossAxisAlignment: isMirrored
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 15),

          // --- BAKUGAN SLOTS ---
          if (isSelecting && selectedBakuganIndex == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'CHOOSE!',
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 2,
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final hasBakugan = i < player.deck.length;
              final variant = hasBakugan ? player.deck[i] : null;
              final isPicked = selectedBakuganIndex == i;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.skewX(-0.15),
                child: GestureDetector(
                  onTap: hasBakugan ? () => onBakuganTap?.call(i) : null,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 90,
                    height: 90,
                    margin: EdgeInsets.only(
                      right: isMirrored ? 0 : 15,
                      left: isMirrored ? 15 : 0,
                    ),
                    padding: EdgeInsets.all(
                      isPicked ? 4 : 2,
                    ), // The "Border" thickness
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      // --- THE GRADIENT BORDER ---
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isPicked ? activeGradient : idleGradient,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isPicked ? activeGradient[0] : idleGradient[0])
                                  .withValues(alpha: 0.5),
                          blurRadius: isPicked ? 15 : 8,
                          spreadRadius: isPicked ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Container(
                      // This inner container "cuts out" the center to show the 3D model
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Stack(
                        children: [
                          if (hasBakugan)
                            Positioned.fill(
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.skewX(
                                  0.15,
                                ), // Un-skew the model
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: BakuganPreview(
                                    variant: variant!,
                                    isDeck: true,
                                  ),
                                ),
                              ),
                            ),

                          // HIT TEST OVERLAY
                          Positioned.fill(
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.01),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (extra != null) ...[const SizedBox(height: 20), extra!],
        ],
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: isMirrored ? children.reversed.toList() : children,
    );
  }
}

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
    _playBattleMusic();
  }

  Future<void> _playBattleMusic() async {
    try {
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.setVolume(0.4);
      await _bgMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgMusicPlayer.play(AssetSource('music/arena/arena-1.flac'));
    } catch (_) {}
  }

  void _addPoint(int index) async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sound/select.wav'));
    } catch (_) {}
    setState(() {
      if (scores[index] < 3) {
        scores[index]++;
      }
    });
  }

  int _scoreIndexForPlayer(PlayerData player) {
    final playerIndex = widget.players.indexOf(player);
    if (playerIndex < 0) return 0;
    if (!widget.isTeamBattle) return playerIndex;
    return playerIndex.isEven ? 0 : 1;
  }

  void _selectLeft(PlayerData player, int bIdx) {
    setState(() {
      leftPlayer = player;
      leftBakugan = player.deck[bIdx];
      leftBakuganIdx = bIdx;
    });
  }

  void _selectRight(PlayerData player, int bIdx) {
    setState(() {
      rightPlayer = player;
      rightBakugan = player.deck[bIdx];
      rightBakuganIdx = bIdx;
    });
  }

  void _playClick() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sound/select.wav'));
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    super.dispose();
  }

  Widget _buildSelectionStatus(bool isReady, String side) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isReady
            ? Colors.greenAccent.withValues(alpha: 0.2)
            : Colors.redAccent.withValues(alpha: 0.2),
        border: Border.all(
          color: isReady ? Colors.greenAccent : Colors.redAccent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isReady ? 'READY' : 'WAITING...',
        style: TextStyle(
          color: isReady ? Colors.greenAccent : Colors.redAccent,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/match-bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Logo in the center
            IgnorePointer(
              // Ensure the logo doesn't block any interactions
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: !selectionMode
                      ? Container(
                          key: const ValueKey('logo'),
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
                        )
                      : Column(
                          key: const ValueKey('prompt'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SELECT YOUR',
                              style: TextStyle(
                                fontFamily: 'title_font',
                                fontSize: 40,
                                color: Colors.white70,
                                letterSpacing: 10,
                              ),
                            ),
                            Text(
                              'BAKUGAN',
                              style: TextStyle(
                                fontFamily: 'title_font',
                                fontSize: 120,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 40,
                                    color: Colors.blueAccent,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildSelectionStatus(
                                  leftBakugan != null,
                                  "LEFT",
                                ),
                                const SizedBox(width: 40),
                                const Text(
                                  'VS',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(width: 40),
                                _buildSelectionStatus(
                                  rightBakugan != null,
                                  "RIGHT",
                                ),
                              ],
                            ),
                          ],
                        ),
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
                child: BakuganButton(
                  text: !selectionMode
                      ? 'BATTLE'
                      : (leftBakugan != null && rightBakugan != null
                            ? 'FIGHT!'
                            : 'CHOOSE...'),
                  onPressed: () {
                    if (!selectionMode) {
                      _playClick();
                      setState(() {
                        selectionMode = true;
                        leftBakugan = null;
                        rightBakugan = null;
                        leftPlayer = null;
                        rightPlayer = null;
                      });
                    } else if (leftBakugan != null && rightBakugan != null) {
                      Navigator.push(
                        context,
                        _fadeRoute(
                          BattleArenaScreen(
                            leftPlayer: leftPlayer!,
                            rightPlayer: rightPlayer!,
                            leftBakugan: leftBakugan!,
                            rightBakugan: rightBakugan!,
                            usedGateCardsInAllPiles: scores.fold(
                              0,
                              (sum, score) => sum + score,
                            ),
                          ),
                        ),
                      ).then((winnerIndex) {
                        if (!mounted || winnerIndex == null) return;
                        final sideWinner = winnerIndex as int;
                        final winningPlayer = sideWinner == 0
                            ? leftPlayer
                            : rightPlayer;
                        if (winningPlayer == null) return;
                        _addPoint(_scoreIndexForPlayer(winningPlayer));
                      });
                    }
                  },
                  color:
                      (selectionMode &&
                          (leftBakugan == null || rightBakugan == null))
                      ? Colors.grey
                      : null,
                  width: 300, // Increased
                  height: 85, // Increased
                ),
              ),
            ),

            // Back button
            Positioned(
              bottom: 0,
              child: BakuganButton(
                text: 'X',
                onPressed: () => Navigator.of(context).pop(),
                width: 80,
                height: 50,
              ),
            ),
          ],
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
      selectedBakuganIndex: isMirrored
          ? (rightPlayer == player ? rightBakuganIdx : null)
          : (leftPlayer == player ? leftBakuganIdx : null),
      onBakuganTap: selectionMode
          ? (bIdx) => isMirrored
                ? _selectRight(player, bIdx)
                : _selectLeft(player, bIdx)
          : null,
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
          selectedBakuganIndex: isMirrored
              ? (rightPlayer == player ? rightBakuganIdx : null)
              : (leftPlayer == player ? leftBakuganIdx : null),
          onBakuganTap: selectionMode
              ? (bIdx) => isMirrored
                    ? _selectRight(player, bIdx)
                    : _selectLeft(player, bIdx)
              : null,
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
              width: 35, // Increased
              height: 55, // Increased
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
                    width: 200,
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.skewX(0.15),
                        child: Text(
                          '$gPower',
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
                  color: Colors.white.withValues(alpha: _isHovered ? 0.8 : 0.6),
                  blurRadius: _isHovered ? 100 : 80,
                  spreadRadius: _isHovered ? 25 : 15,
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

class BattleArenaScreen extends StatefulWidget {
  final PlayerData leftPlayer;
  final PlayerData rightPlayer;
  final BakuganVariant leftBakugan;
  final BakuganVariant rightBakugan;
  final int usedGateCardsInAllPiles;

  const BattleArenaScreen({
    super.key,
    required this.leftPlayer,
    required this.rightPlayer,
    required this.leftBakugan,
    required this.rightBakugan,
    this.usedGateCardsInAllPiles = 0,
  });

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _BattleArenaScreenState extends State<BattleArenaScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _cardNameController = TextEditingController();
  final FocusNode _cardNameFocusNode = FocusNode();

  late final AnimationController _powerAnimationController;
  late final AudioPlayer _powerStartPlayer;
  late final AudioPlayer _countTickPlayer;
  Map<String, GateCard> _gateCards = {};
  Map<String, AbilityCard> _abilityCards = {};
  bool _isLoadingGateCards = true;
  bool _isLoadingAbilityCards = true;
  GateCard? _revealedCard;
  final List<AbilityCard> _leftAbilityCards = [];
  final List<AbilityCard> _rightAbilityCards = [];
  int _leftAppliedAbilityCount = 0;
  int _rightAppliedAbilityCount = 0;
  AbilityCard? _focusedLeftAbilityCard;
  AbilityCard? _focusedRightAbilityCard;
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
  int _leftAnimationStartGPower = 0;
  int _rightAnimationStartGPower = 0;
  int? _leftFloatingBonus;
  int? _rightFloatingBonus;
  String? _winnerText;
  Timer? _powerTickTimer;
  String? _currentBattleMusicAsset;

  @override
  void initState() {
    super.initState();
    _leftCurrentGPower = widget.leftBakugan.gPower;
    _rightCurrentGPower = widget.rightBakugan.gPower;
    _leftTargetGPower = _leftCurrentGPower;
    _rightTargetGPower = _rightCurrentGPower;
    _leftAnimationStartGPower = _leftCurrentGPower;
    _rightAnimationStartGPower = _rightCurrentGPower;
    _powerStartPlayer = AudioPlayer();
    _countTickPlayer = AudioPlayer();
    _powerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..addListener(_handlePowerAnimationTick);
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

      final Map<String, dynamic> decoded = Map<String, dynamic>.from(decodedJson);

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
        final String type = (data['type'] ?? '').toString().trim().toLowerCase();
        final String? fileName = data['file']?.toString();
        final String cardClass =
        (data['card_class'] ?? 'silver').toString().toLowerCase();

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
        final List<dynamic> effects =
        effectsRaw is List ? List<dynamic>.from(effectsRaw) : const [];

        final rulesRaw = data['rules'];
        final List<dynamic> rules =
        rulesRaw is List ? List<dynamic>.from(rulesRaw) : const [];

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
      debugPrint(
        'Gate names: ${loadedCards.values.map((c) => c.name).take(10).toList()}',
      );
      debugPrint(
        'Ability names: ${loadedAbilityCards.values.map((c) => c.name).take(10).toList()}',
      );

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
    if (query.isEmpty) return const [];

    final candidateCards = beforeGateReveal
        ? _abilityCards.values.where((card) => card.supportsStartOfBattle)
        : _abilityCards.values.where((card) => card.supportsDuringBattle);

    final ranked = candidateCards
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
    );
    final rightBreakdown = card.bonusBreakdownFor(
      widget.rightBakugan,
      usedGateCardsInAllPiles: widget.usedGateCardsInAllPiles,
    );
    try {
      await precacheImage(AssetImage(card.imagePath), context);
    } catch (_) {}
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
    });

    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    setState(() {
      _showRevealFlash = false;
    });

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
    final pendingBonus = card.calculateBonus(
      isLeft ? widget.leftBakugan : widget.rightBakugan,
    );

    try {
      await precacheImage(AssetImage(card.imagePath), context);
    } catch (_) {}

    setState(() {
      _winnerText = null;
      if (isLeft) {
        _leftAbilityCards.add(card);
        _focusedLeftAbilityCard = card;
      } else {
        _rightAbilityCards.add(card);
        _focusedRightAbilityCard = card;
      }
    });

    _showAbilityPresentation(isLeft, withFlash: true);

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
    if (_isResolvingCard || _revealedCard == null) return;

    final leftPendingCards = _leftAbilityCards.skip(_leftAppliedAbilityCount);
    final rightPendingCards = _rightAbilityCards.skip(
      _rightAppliedAbilityCount,
    );
    final leftBonus = leftPendingCards.fold<int>(
      0,
      (sum, card) => sum + card.calculateBonus(widget.leftBakugan),
    );
    final rightBonus = rightPendingCards.fold<int>(
      0,
      (sum, card) => sum + card.calculateBonus(widget.rightBakugan),
    );

    if (leftBonus <= 0 && rightBonus <= 0) {
      setState(() {
        _leftAppliedAbilityCount = _leftAbilityCards.length;
        _rightAppliedAbilityCount = _rightAbilityCards.length;
      });
      return;
    }

    await _animatePowerChange(
      leftTarget: _leftCurrentGPower + leftBonus,
      rightTarget: _rightCurrentGPower + rightBonus,
      leftBonus: leftBonus,
      rightBonus: rightBonus,
    );

    if (!mounted) return;
    setState(() {
      if (leftBonus > 0) _leftAppliedAbilityCount = _leftAbilityCards.length;
      if (rightBonus > 0) _rightAppliedAbilityCount = _rightAbilityCards.length;
    });
  }

  void _showAbilityPresentation(
    bool isLeft, {
    bool withFlash = false,
    AbilityCard? card,
  }) {
    setState(() {
      if (isLeft) {
        _focusedLeftAbilityCard = card ?? _focusedLeftAbilityCard;
        _showLeftAbilityPresentation = true;
        _showLeftAbilityFlash = withFlash;
      } else {
        _focusedRightAbilityCard = card ?? _focusedRightAbilityCard;
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

  void _endFight() {
    if (_leftCurrentGPower > _rightCurrentGPower) {
      Navigator.of(context).pop(0);
      return;
    }
    if (_rightCurrentGPower > _leftCurrentGPower) {
      Navigator.of(context).pop(1);
      return;
    }

    setState(() {
      _winnerText = 'The fight ends in a draw.';
    });
  }

  @override
  void dispose() {
    _stopPowerTickLoop();
    _cardNameController.dispose();
    _cardNameFocusNode.dispose();
    _powerAnimationController.dispose();
    _powerStartPlayer.dispose();
    _countTickPlayer.dispose();
    _currentBattleMusicAsset = null;
    _battleMusicPlayer.stop();
    _bgMusicPlayer.resume();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canEndFight = _revealedCard != null && !_isResolvingCard;

    return Scaffold(
      body: Stack(
        children: [
          // Blurred Background
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Image.asset('assets/images/menu-2.png', fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black38),
          ), // Subtle darken
          // Back button
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

          // Left Side
          Positioned(left: 50, top: 0, bottom: 0, child: _buildSide(true)),

          // Right Side
          Positioned(right: 50, top: 0, bottom: 0, child: _buildSide(false)),

          if (_revealedCard != null &&
              ((_revealedCard!.descriptionEn?.trim().isNotEmpty ?? false) ||
                  (_revealedCard!.descriptionEs?.trim().isNotEmpty ?? false)))
            Positioned(
              left: 0,
              right: 0,
              bottom: 170,
              child: Center(child: _buildGateDescriptionPanel(_revealedCard!)),
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Center(
              child: BakuganButton(
                text: 'END BRAWL',
                onPressed: canEndFight ? _endFight : () {},
                width: 300,
                height: 70,
                color: canEndFight ? null : Colors.grey,
              ),
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
                      onTap: () {}, // o null si prefieres que no haga nada al click
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
    final abilityCards = isLeft ? _leftAbilityCards : _rightAbilityCards;
    final appliedAbilityCount = isLeft
        ? _leftAppliedAbilityCount
        : _rightAppliedAbilityCount;
    final focusedAbilityCard = isLeft
        ? _focusedLeftAbilityCard
        : _focusedRightAbilityCard;
    final showAbilityPresentation = isLeft
        ? _showLeftAbilityPresentation
        : _showRightAbilityPresentation;
    final showAbilityFlash = isLeft
        ? _showLeftAbilityFlash
        : _showRightAbilityFlash;
    final pendingAbilityBonus = abilityCards
        .skip(appliedAbilityCount)
        .fold<int>(0, (sum, card) => sum + card.calculateBonus(variant));
    final canPresentAbility = !_isLoadingAbilityCards && !_isResolvingCard;

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
          SizedBox(
            height: 98,
            child: _buildAbilitySlot(
              isLeft: isLeft,
              abilityCards: abilityCards,
              focusedAbilityCard: focusedAbilityCard,
              showAbilityPresentation: showAbilityPresentation,
              canPresent: canPresentAbility,
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
            pendingBonusDelta: _revealedCard == null && pendingAbilityBonus > 0
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
                          width:
                              _gateCardWidth * _abilityPresentationCardScale,
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
              _buildAbilityOverlayDescription(card),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbilityOverlayDescription(AbilityCard card) {
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
  }) {
    const double panelSkew = -0.12;
    const double textInnerSkew = -0.04;
    final bool hasTitle = (title ?? '').trim().isNotEmpty;
    final int bodyMaxLines = hasTitle ? 3 : 4;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(panelSkew),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: frameGradient,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.18),
              blurRadius: 16,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: const Color(0xFF05080D),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(
                    color: accentColor.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.03),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.10),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.skewX(textInnerSkew),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasTitle) ...[
                        Text(
                          title!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1.6,
                            shadows: [
                              Shadow(
                                color: accentColor.withValues(alpha: 0.30),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 1.2,
                          color: accentColor.withValues(alpha: 0.28),
                        ),
                        const SizedBox(height: 12),
                      ],
                      AutoSizeText(
                        esText,
                        maxLines: bodyMaxLines,
                        minFontSize: 10,
                        stepGranularity: 0.5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.28,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              offset: Offset(1, 1),
                              blurRadius: 3,
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
    );
  }

  Widget _buildAbilitySlot({
    required bool isLeft,
    required List<AbilityCard> abilityCards,
    required AbilityCard? focusedAbilityCard,
    required bool showAbilityPresentation,
    required bool canPresent,
  }) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final card in abilityCards)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: showAbilityPresentation && card == focusedAbilityCard
                    ? 0
                    : 102,
                margin: EdgeInsets.symmetric(
                  horizontal:
                      showAbilityPresentation && card == focusedAbilityCard
                      ? 0
                      : 6,
                ),
                child: IgnorePointer(
                  ignoring: showAbilityPresentation && card == focusedAbilityCard,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    opacity: showAbilityPresentation && card == focusedAbilityCard
                        ? 0
                        : 1,
                    child: Align(
                      alignment: Alignment.center,
                      child: InteractiveCard(
                        imagePath: card.imagePath,
                        width: 90,
                        onTap: () => _showAbilityPresentation(isLeft, card: card),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: BakuganButton(
                text: _isLoadingAbilityCards ? '...' : '+',
                onPressed: canPresent
                    ? () => _openAbilityCardPrompt(isLeft)
                    : () {},
                width: 74,
                height: 56,
                color: canPresent ? null : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealCardFace extends StatelessWidget {
  final String imagePath;

  const _RevealCardFace({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.65),
            blurRadius: 80,
            spreadRadius: 18,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: _gateCardWidth,
          height: _gateCardHeight,
          child: Image.asset(
            imagePath,
            key: ValueKey(imagePath),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: false,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/cards/anverse.png',
                fit: BoxFit.contain,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SkewPanelClipper extends CustomClipper<Path> {
  final double horizontalInset;

  const _SkewPanelClipper({required this.horizontalInset});

  @override
  Path getClip(Size size) {
    final inset = horizontalInset.clamp(0, size.width / 2).toDouble();
    return Path()
      ..moveTo(inset, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - inset, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _SkewPanelClipper oldClipper) {
    return oldClipper.horizontalInset != horizontalInset;
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
