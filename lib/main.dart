import 'dart:convert';
import 'dart:io';
import 'dart:ui';
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
  BakuganVariant({required this.attribute, required this.modelPath, required this.color, required this.gPower, required this.speciesName});
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
        BakuganVariant(attribute: attribute, modelPath: path, color: color, gPower: gPower, speciesName: speciesName)
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
      BakuganVariant(attribute: 'pyrus', modelPath: 'assets/models/dragonoid/dragonoid_pyrus_550g.glb', color: Colors.red, gPower: 550, speciesName: 'Dragonoid'),
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
    await _sfxPlayer.play(AssetSource('sound/select.wav'));
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
              )
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
    await _sfxPlayer.play(AssetSource('sound/select.wav'));
  }

  void _onOkPressed() {
    _playClick();
    if (selectedCharacters[currentPlayerIndex] == null) return;
    if (currentPlayerIndex < playerCount - 1) {
      setState(() => currentPlayerIndex++);
    } else {
      List<PlayerData> players = List.generate(playerCount, (i) => PlayerData(name: _nameControllers[i].text, character: selectedCharacters[i]!));
      Navigator.push(context, _fadeRoute(BakuganSelectScreen(players: players, isTeamBattle: widget.isTeamBattle)));
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
                const Text('SELECT CHARACTER', style: TextStyle(fontFamily: 'title_font', fontSize: 60, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 20, color: Colors.blueAccent)])),
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
  final bool isTeamBattle;
  const BakuganSelectScreen({super.key, required this.players, required this.isTeamBattle});
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
      Navigator.push(context, _zoomRoute(ScoreboardScreen(players: widget.players, isTeamBattle: widget.isTeamBattle)));
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
              left: 60, top: 100, bottom: 40,
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
                          padding: const EdgeInsets.only(bottom: 60.0), // Large gap between players
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- CHARACTER PORTRAIT (Large) ---
                              SizedBox(
                                width: 180, height: 213,
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

                                    // TOTAL G POWER DISPLAY
                                    Align(
                                      alignment: const Alignment(-1.7, 0),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 0), // Adjust this if you need a specific margin from the edge
                                        child: Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.skewX(-0.15),
                                          child: Container(
                                            width: 320,
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [themeColor, themeColor.withValues(alpha: 0.3), Colors.black],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: themeColor.withValues(alpha: 0.4),
                                                  blurRadius: 15,
                                                  spreadRadius: 2,
                                                )
                                              ],
                                            ),
                                            child: Container(
                                              clipBehavior: Clip.antiAlias,
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  // Grid Background
                                                  Positioned.fill(
                                                    child: CustomPaint(
                                                      painter: GridPainter(
                                                        color: themeColor.withValues(alpha: 0.15),
                                                      ),
                                                    ),
                                                  ),

                                                  // Text Content
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    child: Transform(
                                                      alignment: Alignment.center,
                                                      transform: Matrix4.skewX(0.15),
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'TOTAL G POWER',
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(
                                                              fontFamily: 'button_font',
                                                              fontSize: 12,
                                                              color: Colors.white60,
                                                              letterSpacing: 2,
                                                              fontWeight: FontWeight.w900,
                                                            ),
                                                          ),
                                                          Text(
                                                            '${entry.value.totalGPower} G',
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(
                                                              fontFamily: 'button_font',
                                                              fontSize: 34,
                                                              color: themeColor,
                                                              fontWeight: FontWeight.w900,
                                                              fontStyle: FontStyle.italic,
                                                              shadows: [
                                                                Shadow(color: themeColor.withValues(alpha: 0.8), blurRadius: 12)
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
                            // 1. LARGE PREVIEW (Placed first so it's \"behind\" the tabs if needed)
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

                                        // The horizontal \"staircase\" offset
                                        final double baseLeft = index * -13.5 + 35;
// How much the tab should \"pop out\" to the left
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
                        if (widget.players.every((p) => p.deck.length == 3)) ...[
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
  final double? theta;
  final double? phi;
  final bool autoRotate;
  final bool disableInteraction;
  final bool showGPower;

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
  });

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

    if (widget.isDeck) return _buildModel(isDeck: true);

    final Color themeColor = widget.isTaken ? Colors.grey : widget.variant.color;
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
                    width: widget.isLarge ? 4 : (widget.isSelected ? 3 : 1.5)
                ),
                boxShadow: (widget.isSelected || widget.isLarge) && !widget.isTaken
                    ? [
                  BoxShadow(color: themeColor.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 1),
                  BoxShadow(color: themeColor.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 5),
                ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6), // Slightly smaller to stay inside border
                child: Stack(
                  children: [
                    // Grid Background
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GridPainter(
                            color: themeColor.withValues(alpha: widget.isLarge ? 0.12 : 0.05)
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
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          border: Border(top: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 1.5)),
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
      bottom: 0, left: -30, right: 33,
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
                      fontFamily: 'title_font', fontSize: 38,
                      fontWeight: FontWeight.w900, color: Colors.white,
                      shadows: [Shadow(blurRadius: 10, color: themeColor)],
                    ),
                  ),
                ),
                if (widget.showGPower)
                  Transform.translate(
                    offset: const Offset(0, 4), // Increase '6' to move it further down
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
    return IgnorePointer(
      ignoring: isDeck || widget.disableInteraction || !widget.isLarge,
      child: Flutter3DViewer(
        key: ValueKey('model_${widget.variant.modelPath}_${widget.isLarge}'),
        src: widget.variant.modelPath,
        controller: _controller,
        progressBarColor: Colors.transparent,
        onLoad: (_) {
          double t = widget.theta ?? (widget.isLarge ? 0 : 30);
          double p = widget.phi ?? 75;
          _controller.setCameraOrbit(t, p, 100);
          if (widget.isLarge && widget.autoRotate) _controller.startRotation(rotationSpeed: 15);
        },
      ),
    );
  }

  Widget _buildTakenOverlay() {
    return Center(
      child: Transform(alignment: Alignment.center, transform: Matrix4.skewX(-0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          color: Colors.black87,
          child: const Text('PICKED', style: TextStyle(fontFamily: 'title_font', fontSize: 60, color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
            )
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
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
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
                            fontStyle: FontStyle.italic, // Matches the CharacterMiniature style
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
    final List<Color> activeGradient = [Colors.redAccent, Colors.orange, Colors.yellowAccent];
    final List<Color> idleGradient = [Colors.blueAccent, Colors.cyan, Colors.blue.shade900];

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
              color: currentGradient[0].withValues(alpha: glowAlpha ?? (isSelected ? 0.6 : 0.2)),
              blurRadius: glowAlpha != null ? 30 : (isSelected ? 20 : 10), // Boosted blur for battle screen
              spreadRadius: 2,
            )
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
                    child: CustomPaint(painter: GridPainter(color: Colors.white10)),
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
                            top: BorderSide(color: currentGradient[0], width: 1),
                          ),
                        ),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.skewX(0.15),
                          child: Text(
                            displayName.toUpperCase(), // Shows Player Name or Char Name
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14, // Slightly smaller to fit longer player names
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

    final List<Color> activeGradient = [Colors.redAccent, Colors.orange, Colors.yellowAccent];
    final List<Color> idleGradient = [Colors.blueAccent, Colors.cyan, Colors.blue.shade900];

    final children = [
      // --- CHARACTER PORTRAIT ---
      SizedBox(
        width: 180, height: 210, // Increased size
        child: CharacterMiniature(char: player.character, isSelected: isSelected, showName: true, label: player.name.toUpperCase(), glowAlpha: glowAlpha, thickness: thickness),
      ),
      const SizedBox(width: 40), // Increased gap

      // --- INFO & DECK ---
      Column(
        crossAxisAlignment: isMirrored ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 15),

          // --- BAKUGAN SLOTS ---
          if (isSelecting && selectedBakuganIndex == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text('CHOOSE!', style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 2)),
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
                    width: 90, height: 90,
                    margin: EdgeInsets.only(
                      right: isMirrored ? 0 : 15,
                      left: isMirrored ? 15 : 0,
                    ),
                    padding: EdgeInsets.all(isPicked ? 4 : 2), // The "Border" thickness
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
                          color: (isPicked ? activeGradient[0] : idleGradient[0]).withValues(alpha: 0.5),
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
                                transform: Matrix4.skewX(0.15), // Un-skew the model
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: BakuganPreview(variant: variant!, isDeck: true),
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
          if (extra != null) ...[
            const SizedBox(height: 20),
            extra!,
          ],
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
  const ScoreboardScreen({super.key, required this.players, required this.isTeamBattle});

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
    scores = widget.isTeamBattle ? [0, 0] : List.filled(widget.players.length, 0);
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
        color: isReady ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
        border: Border.all(color: isReady ? Colors.greenAccent : Colors.redAccent, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isReady ? 'READY' : 'WAITING...',
        style: TextStyle(color: isReady ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/images/match-bg.png'), fit: BoxFit.cover),
        ),
        child: Stack(
          children: [
            // Logo in the center
            IgnorePointer( // Ensure the logo doesn't block any interactions
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
                            style: TextStyle(fontFamily: 'title_font', fontSize: 40, color: Colors.white70, letterSpacing: 10),
                          ),
                          Text(
                            'BAKUGAN',
                            style: TextStyle(
                              fontFamily: 'title_font',
                              fontSize: 120,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [Shadow(blurRadius: 40, color: Colors.blueAccent)],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSelectionStatus(leftBakugan != null, "LEFT"),
                              const SizedBox(width: 40),
                              const Text('VS', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                              const SizedBox(width: 40),
                              _buildSelectionStatus(rightBakugan != null, "RIGHT"),
                            ],
                          )
                        ],
                      ),
                ),
              ),
            ),

            if (!widget.isTeamBattle) ...[
              _buildCornerPlayer(0, Alignment.topLeft),
              _buildCornerPlayer(1, Alignment.topRight),
              if (widget.players.length > 2) _buildCornerPlayer(2, Alignment.bottomLeft),
              if (widget.players.length > 3) _buildCornerPlayer(3, Alignment.bottomRight),
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
                  text: !selectionMode ? 'BATTLE' : (leftBakugan != null && rightBakugan != null ? 'FIGHT!' : 'CHOOSE...'),
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
                      Navigator.push(context, _fadeRoute(BattleArenaScreen(leftPlayer: leftPlayer!, rightPlayer: rightPlayer!, leftBakugan: leftBakugan!, rightBakugan: rightBakugan!)));
                    }
                  },
                  color: (selectionMode && (leftBakugan == null || rightBakugan == null)) ? Colors.grey : null,
                  width: 300, // Increased
                  height: 85, // Increased
                ),
              ),
            ),

            // Back button
            Positioned(
              bottom: 0,
              child: BakuganButton(text: 'X', onPressed: () => Navigator.of(context).pop(), width: 80, height: 50),
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
        crossAxisAlignment: isMirrored ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
      selectedBakuganIndex: isMirrored ? (rightPlayer == player ? rightBakuganIdx : null) : (leftPlayer == player ? leftBakuganIdx : null),
      onBakuganTap: selectionMode ? (bIdx) => isMirrored ? _selectRight(player, bIdx) : _selectLeft(player, bIdx) : null,
    );
  }

  Widget _buildCornerPlayer(int index, Alignment alignment) {
    final player = widget.players[index];
    final bool isMirrored = alignment == Alignment.topRight || alignment == Alignment.bottomRight;
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
          selectedBakuganIndex: isMirrored ? (rightPlayer == player ? rightBakuganIdx : null) : (leftPlayer == player ? leftBakuganIdx : null),
          onBakuganTap: selectionMode ? (bIdx) => isMirrored ? _selectRight(player, bIdx) : _selectLeft(player, bIdx) : null,
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
                      ? [Colors.cyanAccent, Colors.purpleAccent.withValues(alpha: 0.8)]
                      : [Colors.blueGrey.withValues(alpha: 0.4), Colors.black87],
                ),
                border: Border.all(
                  color: isFilled ? Colors.cyanAccent : Colors.white10,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: isFilled ? [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.6),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ] : [],
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
    const double nudgeX = -1.0;    // Positive = Right, Negative = Left
    const double nudgeY = -1.0;   // Positive = Down, Negative = Up (Try -2.0 or -3.0)
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2.5),
                boxShadow: [
                  BoxShadow(color: themeColor.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2),
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
                              Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 4),
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
  const InteractiveCard({super.key, required this.imagePath});

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
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
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
              child: Image.asset(widget.imagePath, width: 400),
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
  
  const BattleArenaScreen({
    super.key, 
    required this.leftPlayer, 
    required this.rightPlayer, 
    required this.leftBakugan, 
    required this.rightBakugan
  });

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _BattleArenaScreenState extends State<BattleArenaScreen> {
  @override
  void initState() {
    super.initState();
    _startBattleMusic();
  }

  Future<void> _startBattleMusic() async {
    try {
      await _bgMusicPlayer.pause();
      await _battleMusicPlayer.stop();
      await _battleMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _battleMusicPlayer.play(AssetSource('music/battle/before_ability.flac'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _battleMusicPlayer.stop();
    _bgMusicPlayer.resume();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Positioned.fill(child: Container(color: Colors.black38)), // Subtle darken

          // Back button
          Positioned(top: 40, left: 20, child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30), onPressed: () => Navigator.of(context).pop())),

          // Middle: anverse.png
          const Center(
            child: InteractiveCard(imagePath: 'assets/images/cards/anverse.png'),
          ),

          // Left Side
          Positioned(
            left: 50, top: 0, bottom: 0,
            child: _buildSide(true),
          ),

          // Right Side
          Positioned(
            right: 50, top: 0, bottom: 0,
            child: _buildSide(false),
          ),
        ],
      ),
    );
  }

  Widget _buildSide(bool isLeft) {
    final variant = isLeft ? widget.leftBakugan : widget.rightBakugan;
    final player = isLeft ? widget.leftPlayer : widget.rightPlayer;

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
                  shadows: [Shadow(blurRadius: 20, color: Colors.blueAccent)]
              )
          ),
          const Spacer(),
          SizedBox(
            width: 500, height: 500,
            child: BakuganPreview(
              key: ValueKey('battle_arena_${isLeft ? 'L' : 'R'}_${variant.modelPath}'),
              variant: variant,
              isLarge: true,
              autoRotate: false,
              theta: isLeft ? -40 : 40,
              phi: 75,
              disableInteraction: true,
              speciesName: variant.speciesName,
              showGPower: false,
            ),
          ),
          const Spacer(),
          GPowerBadge(gPower: variant.gPower, attribute: variant.attribute, themeColor: variant.color),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
