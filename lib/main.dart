import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

// REPRODUCTOR GLOBAL PARA MÚSICA DE FONDO
final AudioPlayer _bgMusicPlayer = AudioPlayer();

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

// --- MODELOS DE DATOS ---
class BakuganVariant {
  final String attribute;
  final String modelPath;
  final Color color;
  final int gPower;
  BakuganVariant({required this.attribute, required this.modelPath, required this.color, required this.gPower});
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

List<Bakugan> availableBakugans = [];

Future<void> loadAvailableBakugans() async {
  if (availableBakugans.isNotEmpty) return;
  try {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final modelPaths = manifest.listAssets()
        .where((String key) => key.startsWith('assets/models/') && key.endsWith('.glb'))
        .toList();

    Map<String, List<BakuganVariant>> grouped = {};

    for (var path in modelPaths) {
      String fileName = path.split('/').last.replaceAll('.glb', '');
      List<String> parts = fileName.split('_');
      
      // Extract G-Power if present (e.g., "550g")
      int gPower = 0;
      if (parts.last.endsWith('g')) {
        gPower = int.tryParse(parts.last.substring(0, parts.last.length - 1)) ?? 0;
        parts.removeLast(); // Remove the gPower part for further processing
      }

      String attribute = parts.last.toLowerCase();
      String speciesName = parts.length > 1
          ? parts.sublist(0, parts.length - 1).map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')
          : fileName[0].toUpperCase() + fileName.substring(1);

      Color color = Colors.red;
      if (attribute.contains('pyrus')) color = Colors.red;
      else if (attribute.contains('aquos')) color = Colors.blue;
      else if (attribute.contains('subterra')) color = Colors.orange;
      else if (attribute.contains('haos')) color = Colors.white;
      else if (attribute.contains('darkus')) color = Colors.purple;
      else if (attribute.contains('ventus')) color = Colors.green;

      grouped.putIfAbsent(speciesName, () => []).add(
        BakuganVariant(attribute: attribute, modelPath: path, color: color, gPower: gPower)
      );
    }

    availableBakugans = grouped.entries.map((e) => Bakugan(name: e.key, variants: e.value)).toList();

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
    Bakugan(name: 'Dragonoid', variants: [
      BakuganVariant(attribute: 'pyrus', modelPath: 'assets/models/dragonoid/dragonoid_pyrus_550g.glb', color: Colors.red, gPower: 550),
    ])
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
    _controller = VideoPlayerController.asset('assets/video/bakugan_opening.mp4')
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
        Navigator.of(context).pushReplacement(_fadeRoute(const MainMenuScreen()));
      }
    });
  }

  Future<void> _handleTap() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sound/select.mp3'));
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
                  ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller.value.size.width, height: _controller.value.size.height, child: VideoPlayer(_controller))))
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
      await _sfxPlayer.play(AssetSource('sound/select.mp3'));
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
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/Menu.png'), fit: BoxFit.cover)),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BakuganButton(text: 'BATTLE', onPressed: _navigateToBattleMode, width: 420, height: 100),
                    const SizedBox(height: 25),
                    BakuganButton(text: 'LEADERBOARD', onPressed: _playClick, width: 420, height: 100),
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
    await _sfxPlayer.play(AssetSource('sound/select.mp3'));
  }
  @override
  void dispose() { _sfxPlayer.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/Menu.png'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken))),
        child: Stack(
          children: [
            Positioned(top: 40, left: 20, child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30), onPressed: () { _playClick(); Navigator.of(context).pop(); })),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 80.0),
                child: Text('SELECT MODE', style: TextStyle(fontFamily: 'title_font', fontSize: 80, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(blurRadius: 30.0, color: Colors.blue, offset: Offset.zero)])),
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BakuganButton(text: 'BATTLE\nROYALE', onPressed: () { _playClick(); Navigator.push(context, _fadeRoute(const CharacterSelectScreen(isTeamBattle: false))); }, width: 240, height: 480),
                  const SizedBox(width: 40),
                  BakuganButton(text: 'TEAM\nBATTLE', onPressed: () { _playClick(); Navigator.push(context, _fadeRoute(const CharacterSelectScreen(isTeamBattle: true))); }, width: 240, height: 480),
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

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  late AudioPlayer _sfxPlayer;
  int playerCount = 2;
  int currentPlayerIndex = 0;
  List<String?> selectedCharacters = List.filled(4, null);
  late List<TextEditingController> _nameControllers;
  final List<String> characters = ['dan', 'runo', 'shun', 'alice', 'julie', 'marucho', 'masquerade'];

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer();
    playerCount = widget.isTeamBattle ? 4 : 2;
    _nameControllers = List.generate(4, (i) => TextEditingController(text: 'PLAYER ${i + 1}'));
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
    await _sfxPlayer.play(AssetSource('sound/select.mp3'));
  }

  void _onOkPressed() {
    _playClick();
    if (selectedCharacters[currentPlayerIndex] == null) return;
    if (currentPlayerIndex < playerCount - 1) {
      setState(() => currentPlayerIndex++);
    } else {
      List<PlayerData> players = List.generate(playerCount, (i) => PlayerData(name: _nameControllers[i].text, character: selectedCharacters[i]!));
      Navigator.push(context, _fadeRoute(BakuganSelectScreen(players: players)));
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
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/selection-bg.png'), fit: BoxFit.cover)),
        child: Stack(
          children: [
            Positioned(top: 40, left: 20, child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30), onPressed: () { _playClick(); Navigator.of(context).pop(); })),
            Column(
              children: [
                const SizedBox(height: 50),
                const Text('SELECT CHARACTER', style: TextStyle(fontFamily: 'title_font', fontSize: 60, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 20, color: Colors.redAccent)])),
                const SizedBox(height: 30),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < playerCount; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: PlayerSlot(controller: _nameControllers[i], char: selectedCharacters[i], isActive: i == currentPlayerIndex, isBlue: i % 2 == 0),
                        ),
                      if (!widget.isTeamBattle && playerCount < 4)
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 60),
                          onPressed: () { _playClick(); setState(() => playerCount++); },
                        ),
                      if (!widget.isTeamBattle && playerCount > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 60),
                          onPressed: () { _playClick(); setState(() { playerCount--; if (currentPlayerIndex >= playerCount) currentPlayerIndex = playerCount - 1; }); },
                        ),
                    ],
                  ),
                ),
                Container(
                  height: 220, width: double.infinity, color: Colors.black45,
                  child: Center(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal, shrinkWrap: true, itemCount: characters.length,
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () {
                          _playClick();
                          setState(() => selectedCharacters[currentPlayerIndex] = characters[index]);
                        },
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15), child: AspectRatio(aspectRatio: 1.1, child: CharacterMiniature(char: characters[index], isSelected: selectedCharacters[currentPlayerIndex] == characters[index]))),
                      ),
                    ),
                  ),
                ),
                Padding(padding: const EdgeInsets.symmetric(vertical: 30.0), child: BakuganButton(text: 'OK', onPressed: _onOkPressed, width: 280, height: 80)),
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
  const BakuganSelectScreen({super.key, required this.players});
  @override
  State<BakuganSelectScreen> createState() => _BakuganSelectScreenState();
}

class _BakuganSelectScreenState extends State<BakuganSelectScreen> {
  int currentPlayerIndex = 0;
  int selectedBakuganIndex = 0;
  int selectedVariantIndex = 0;
  final PageController _carouselController = PageController(viewportFraction: 0.2);
  late AudioPlayer _sfxPlayer;

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer();
  }

  void _playClick() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sound/select.mp3'));
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
      debugPrint("Battle Start!");
    }
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (availableBakugans.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final currentPlayer = widget.players[currentPlayerIndex];
    final currentSpecies = availableBakugans[selectedBakuganIndex];
    final currentVariant = currentSpecies.variants[selectedVariantIndex];
    final bool currentIsTaken = _isVariantTaken(currentVariant);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/selection-bg.png'), fit: BoxFit.cover)),
        child: Stack(
          children: [
            Positioned(top: 40, left: 20, child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30), onPressed: () { _playClick(); Navigator.of(context).pop(); })),
            
            // HORIZONTAL PLAYER LIST ON LEFT
            Positioned(
              left: 40, top: 100, bottom: 40,
              child: SizedBox(
                width: 600, // Wide enough for portrait + name + 3 slots
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.players.asMap().entries.map((entry) {
                      bool isCurrent = entry.key == currentPlayerIndex;
                      final themeColor = entry.key % 2 == 0 ? Colors.blueAccent : Colors.redAccent;

                      return GestureDetector(
                        onTap: () => setState(() => currentPlayerIndex = entry.key),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 80.0), // Large gap between players
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- CHARACTER PORTRAIT (Large) ---
                              SizedBox(
                                width: 180, height: 200,
                                child: CharacterMiniature(char: entry.value.character, isSelected: isCurrent, showName: false),
                              ),
                              const SizedBox(width: 45),

                              // --- INFO & DECK ---
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        entry.value.name.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 30, // Large font for visibility
                                          letterSpacing: 3,
                                          color: isCurrent ? themeColor : Colors.white70,
                                          fontFamily: 'title_font',
                                        )
                                    ),
                                    const SizedBox(height: 15),

                                    // --- BAKUGAN SLOTS ---
                                    Row(
                                      children: List.generate(3, (i) {
                                        final hasBakugan = i < entry.value.deck.length;
                                        final variant = hasBakugan ? entry.value.deck[i] : null;

                                        return GestureDetector(
                                          onTap: hasBakugan ? () => _removeBakugan(entry.key, i) : null,
                                          child: Container(
                                            width: 100, height: 100, // Restored to original large size
                                            margin: const EdgeInsets.only(right: 15),
                                            transform: Matrix4.skewX(-0.15),
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: hasBakugan ? variant!.color : Colors.white12,
                                                  width: hasBakugan ? 3 : 1.5
                                              ),
                                              boxShadow: hasBakugan
                                                  ? [BoxShadow(color: variant!.color.withValues(alpha: 0.5), blurRadius: 12)]
                                                  : null,
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: hasBakugan
                                                  ? Stack(
                                                children: [
                                                  // COUNTER-SKEW to fix deformation
                                                  Transform(
                                                    alignment: Alignment.center,
                                                    transform: Matrix4.skewX(0.15),
                                                    child: BakuganPreview(variant: variant!, isDeck: true),
                                                  ),
                                                  Positioned(
                                                      top: 4, right: 4,
                                                      child: Icon(Icons.cancel, size: 18, color: Colors.redAccent.withValues(alpha: 0.8))
                                                  ),

                                                ],
                                              )
                                                  : const Center(child: Icon(Icons.add, color: Colors.white10, size: 30)),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 15),
                                    
                                    // TOTAL G POWER DISPLAY (Now below the deck)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        border: Border.all(color: themeColor, width: 2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${entry.value.totalGPower} G',
                                        style: TextStyle(
                                          fontFamily: 'button_font',
                                          fontSize: 22,
                                          color: themeColor,
                                          fontWeight: FontWeight.bold,
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
                  Text(currentPlayer.name.toUpperCase(), style: const TextStyle(fontSize: 24, letterSpacing: 5, color: Colors.blueAccent)),
                  const Text('SELECT YOUR DECK', style: TextStyle(fontFamily: 'title_font', fontSize: 50, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 30.0, color: Colors.blue, offset: Offset.zero)])),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 900, // Fixed container for both elements
                        height: 500,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // 1. LARGE PREVIEW (Placed first so it's "behind" the tabs if needed)
                            Positioned(
                              left: 100, // Gives space for the tabs to sit on the edge
                              child: SizedBox(
                                width: 800,
                                height: 500,
                                child: BakuganPreview(
                                  key: ValueKey('large_${currentVariant.modelPath}'),
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
                                      children: variants.asMap().entries.map((vEntry) {
                                        final index = vEntry.key;
                                        final variant = vEntry.value;
                                        bool isSel = index == selectedVariantIndex;
                                        bool isTaken = _isVariantTaken(variant);

                                        double top = isFullSet
                                            ? index * (500 - fixedItemHeight) / 5
                                            : index * 90;

                                        // The horizontal "staircase" offset
                                        final double baseLeft = index * -13.5 + 35;
// How much the tab should "pop out" to the left
                                        const double popOutDistance = 30;

                                        return AnimatedPositioned(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeOutCubic,
                                          top: top,
                                          // SUBTRACT to move it left (outwards)
                                          left: isSel ? baseLeft - popOutDistance : baseLeft,
                                          child: GestureDetector(
                                            onTap: isTaken ? null : () {
                                              _playClick();
                                              setState(() => selectedVariantIndex = index);
                                            },
                                            child: Transform(
                                              alignment: Alignment.center,
                                              transform: Matrix4.skewX(-0.15),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 250),
                                                curve: Curves.easeOutCubic,
                                                // We increase width by the same distance so the right side
                                                // stays flush against the Preview
                                                width: isSel ? (100 + popOutDistance) : 100,
                                                height: fixedItemHeight,
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: isTaken
                                                      ? Colors.grey.withValues(alpha: 0.1)
                                                      : (isSel ? variant.color.withValues(alpha: 0.4) : Colors.black45),
                                                  border: Border(
                                                    top: BorderSide(color: isTaken ? Colors.grey : (isSel ? variant.color : Colors.white24), width: isSel ? 2 : 1),
                                                    left: BorderSide(color: isTaken ? Colors.grey : (isSel ? variant.color : Colors.white24), width: isSel ? 2 : 1),
                                                    bottom: BorderSide(color: isTaken ? Colors.grey : (isSel ? variant.color : Colors.white24), width: isSel ? 2 : 1),
                                                  ),
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(15),
                                                    bottomLeft: Radius.circular(15),
                                                  ),
                                                  boxShadow: isSel ? [
                                                    BoxShadow(color: variant.color.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 2)
                                                  ] : [],
                                                ),
                                                child: Transform(
                                                  alignment: Alignment.center,
                                                  transform: Matrix4.skewX(0.15),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Expanded(
                                                        child: Opacity(
                                                          opacity: isTaken ? 0.3 : 1.0, // Dims it instead of greying the whole layer
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
                                                          fontWeight: FontWeight.w900,
                                                          color: isSel ? Colors.white : Colors.white70,
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
                          IconButton(icon: const Icon(Icons.arrow_back_ios, size: 40), onPressed: () { _playClick(); _carouselController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }),
                          SizedBox(
                            width: 1200,
                            child: PageView.builder(
                              controller: _carouselController, itemCount: availableBakugans.length,
                              onPageChanged: (idx) => setState(() { 
                                selectedBakuganIndex = idx; 
                                selectedVariantIndex = 0;
                              }),
                              itemBuilder: (context, idx) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: BakuganPreview(
                                  key: ValueKey('preview_${availableBakugans[idx].variants[0].modelPath}'),
                                  variant: availableBakugans[idx].variants[0],
                                  isSelected: selectedBakuganIndex == idx,
                                  speciesName: availableBakugans[idx].name,
                                ),
                              ),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 40), onPressed: () { _playClick(); _carouselController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }),
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
                          width: 320, height: 90,
                          color: currentIsTaken ? Colors.grey : Colors.blueAccent,
                        ),
                        if (currentPlayer.deck.length == 3 || widget.players.any((p) => p.deck.isNotEmpty)) ...[
                          const SizedBox(width: 25),
                          BakuganButton(text: 'READY', onPressed: _nextPlayer, width: 240, height: 90),
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
  const BakuganPreview({super.key, required this.variant, this.isLarge = false, this.isDeck = false, this.isSelected = false, this.speciesName, this.isTaken = false});

  @override
  State<BakuganPreview> createState() => _BakuganPreviewState();
}

class _BakuganPreviewState extends State<BakuganPreview> with AutomaticKeepAliveClientMixin {
  final Flutter3DController _controller = Flutter3DController();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // If it's a small deck slot, we just want the model, no backgrounds or extra grids
    if (widget.isDeck) {
      return IgnorePointer(
        child: Flutter3DViewer(
          key: ValueKey('deck_model_${widget.variant.modelPath}'),
          src: widget.variant.modelPath,
          controller: _controller,
          progressBarColor: Colors.transparent,
          onLoad: (_) => _controller.setCameraOrbit(30, 75, 100),
        ),
      );
    }
    
    Color borderColor = widget.isLarge ? (widget.isTaken ? Colors.grey : widget.variant.color) : (widget.isSelected ? widget.variant.color : Colors.white24);
    final borderWidth = widget.isLarge ? 8.0 : (widget.isSelected ? 4.0 : 2.0);
    final themeColor = widget.isTaken ? Colors.grey : widget.variant.color;

    return Stack(
      children: [
        Positioned.fill(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(-0.15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: widget.isLarge ? Border.all(color: borderColor, width: borderWidth) : null,
                boxShadow: (widget.isSelected || widget.isLarge) && !widget.isTaken
                  ? [BoxShadow(color: themeColor.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)] 
                  : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: GridPainter(color: widget.isLarge ? (widget.isTaken ? Colors.white10 : themeColor.withValues(alpha: 0.15)) : Colors.white10),
                ),
              ),
            ),
          ),
        ),

        // REPLACE THIS SECTION:
        Positioned.fill(
          child: Opacity(
            // If taken, we dim it to 20% visibility instead of filtering the whole stack
            opacity: widget.isTaken ? 0.2 : 1.0,
            child: IgnorePointer(
              ignoring: !widget.isLarge,
              child: Flutter3DViewer(
                key: ValueKey('model_${widget.variant.modelPath}_${widget.isLarge}'),
                src: widget.variant.modelPath,
                controller: _controller,
                progressBarColor: Colors.transparent,
                onLoad: (_) {
                  if (!widget.isLarge) {
                    _controller.setCameraOrbit(30, 75, 100);
                  } else {
                    _controller.setCameraOrbit(0, 75, 100);
                    _controller.startRotation(rotationSpeed: 15);
                  }
                },
              ),
            ),
          ),
        ),

        if (widget.isTaken && widget.isLarge)
          Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(-0.15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                color: Colors.black87,
                child: const Text('PICKED', style: TextStyle(fontFamily: 'title_font', fontSize: 60, color: Colors.redAccent, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 15, color: Colors.black)])),
              ),
            ),
          ),

        if (widget.isLarge && widget.speciesName != null)
          Positioned(
            right: 40, bottom: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.skewX(-0.15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      border: Border(left: BorderSide(color: themeColor, width: 8)),
                    ),
                    child: Text(
                      widget.speciesName!.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'title_font',
                        fontSize: 45,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [Shadow(blurRadius: 15, color: themeColor)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.skewX(-0.15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    color: themeColor.withValues(alpha: 0.9),
                    child: Text(
                      '${widget.variant.gPower}G',
                      style: const TextStyle(
                        fontFamily: 'title_font',
                        fontSize: 35,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (!widget.isLarge)
          Positioned.fill(
            child: IgnorePointer(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.skewX(-0.15),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: borderWidth),
                  ),
                ),
              ),
            ),
          ),

        if (!widget.isLarge && !widget.isDeck && widget.speciesName != null)
           Positioned(
             left: 10, bottom: 10,
             child: Transform(
               alignment: Alignment.center,
               transform: Matrix4.skewX(-0.15),
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                 color: Colors.black54,
                 child: Text(widget.speciesName!.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
               ),
             ),
           ),
      ],
    );
  }
}


class PlayerSlot extends StatelessWidget {
  final TextEditingController controller;
  final String? char;
  final bool isActive;
  final bool isBlue;
  const PlayerSlot({super.key, required this.controller, this.char, required this.isActive, required this.isBlue});

  @override
  Widget build(BuildContext context) {
    final themeColor = isBlue ? Colors.blueAccent : Colors.redAccent;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-0.15),
      child: Container(
        width: 300, height: 480, clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: isActive ? themeColor : (char != null ? themeColor.withValues(alpha: 0.9) : Colors.white24), width: 10)),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), boxShadow: isActive ? [BoxShadow(color: themeColor.withValues(alpha: 0.6), blurRadius: 30, spreadRadius: 5)] : null),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: GridPainter(color: themeColor.withValues(alpha: 0.15)))),
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
                        child: Image.asset('assets/images/characters/$char.png', fit: BoxFit.cover, width: 300),
                      ),
                    );
                  },
                ),
              ),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(0.15),
              child: Align(alignment: Alignment.bottomCenter, child: Container(width: double.infinity, padding: const EdgeInsets.only(top: 8, bottom: 8, left: 10, right: 80), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.85), border: Border(top: BorderSide(color: themeColor, width: 3))), child: TextField(controller: controller, textAlign: TextAlign.end, style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w900), decoration: const InputDecoration(border: InputBorder.none, isDense: true))))
            ),
          ],
        ),
      ),
    );
  }
}

class CharacterMiniature extends StatelessWidget {
  final String char;
  final bool isSelected;
  final bool showName;
  const CharacterMiniature({super.key, required this.char, required this.isSelected, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? Colors.redAccent : Colors.blueAccent;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-0.15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: borderColor, width: isSelected ? 8 : 4)),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(5), boxShadow: [BoxShadow(color: borderColor.withValues(alpha: isSelected ? 0.8 : 0.3), blurRadius: isSelected ? 15 : 8)]),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: GridPainter(color: Colors.white12))),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(0.15),
              child: Transform.scale(scale: 2.4, alignment: const Alignment(-0.5, -1), child: Image.asset('assets/images/characters/$char.png', fit: BoxFit.cover))
            ),
            if (showName)
              Align(alignment: Alignment.bottomCenter, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4), color: Colors.black87, child: Transform(alignment: Alignment.center, transform: Matrix4.skewX(0.15), child: Text(char[0].toUpperCase() + char.substring(1), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))))),
          ],
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
    final paint = Paint()..color = color..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 20) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += 20) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class BakuganButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double width, height;
  final Color? color;
  const BakuganButton({super.key, required this.text, required this.onPressed, this.width = 250, this.height = 65, this.color});
  @override
  State<BakuganButton> createState() => _BakuganButtonState();
}

class _BakuganButtonState extends State<BakuganButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..addStatusListener((s) { if (s == AnimationStatus.completed) _pulse.reverse(); });
  }
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? const Color(0xFF4A90E2);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + (_pulse.value * 0.08),
        child: GestureDetector(
          onTap: () { _pulse.forward(); widget.onPressed(); },
          child: Container(
            width: widget.width, height: widget.height,
            decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(15), border: Border.all(color: widget.color ?? const Color(0xFF6A6A6A), width: 5), boxShadow: [BoxShadow(color: themeColor.withValues(alpha: _pulse.value * 0.8), blurRadius: 25 * _pulse.value, spreadRadius: 8 * _pulse.value)]),
            child: Center(child: Text(widget.text, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'button_font', color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 12.0 + (_pulse.value * 15), color: themeColor)]))),
          ),
        ),
      ),
    );
  }
}
