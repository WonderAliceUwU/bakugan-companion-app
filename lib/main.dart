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
  BakuganVariant({required this.attribute, required this.modelPath, required this.color});
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
        BakuganVariant(attribute: attribute, modelPath: path, color: color)
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
      BakuganVariant(attribute: 'pyrus', modelPath: 'assets/models/dragonoid/dragonoid_pyrus.glb', color: Colors.red),
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
              left: 40, top: 130, bottom: 40,
              child: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.players.asMap().entries.map((entry) {
                      bool isCurrent = entry.key == currentPlayerIndex;
                      final themeColor = entry.key % 2 == 0 ? Colors.blueAccent : Colors.redAccent;
                      return GestureDetector(
                        onTap: () => setState(() => currentPlayerIndex = entry.key),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 80.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 170, height: 190,
                                child: CharacterMiniature(char: entry.value.character, isSelected: isCurrent),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.value.name.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 2, color: isCurrent ? themeColor : Colors.white70)),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: List.generate(3, (i) {
                                        final hasBakugan = i < entry.value.deck.length;
                                        return GestureDetector(
                                          onTap: hasBakugan ? () => _removeBakugan(entry.key, i) : null,
                                          child: Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.skewX(-0.15),
                                            child: Container(
                                              width: 90, height: 90, margin: const EdgeInsets.only(right: 10),
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: hasBakugan ? entry.value.deck[i].color : Colors.white12, width: 2),
                                                boxShadow: hasBakugan ? [BoxShadow(color: entry.value.deck[i].color.withValues(alpha: 0.4), blurRadius: 10)] : null,
                                              ),
                                              child: hasBakugan 
                                                ? Stack(
                                                    children: [
                                                      BakuganPreview(variant: entry.value.deck[i], isDeck: true),
                                                      const Positioned(top: 2, right: 2, child: Icon(Icons.cancel, size: 16, color: Colors.redAccent)),
                                                    ],
                                                  ) 
                                                : const Center(child: Icon(Icons.add, color: Colors.white10, size: 24)),
                                            ),
                                          ),
                                        );
                                      }),
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
                  const Text('SELECT YOUR DECK', style: TextStyle(fontFamily: 'title_font', fontSize: 50)),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ATTRIBUTE SELECTOR
                          Transform.translate(
                            offset: const Offset(15, 0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: currentSpecies.variants.asMap().entries.map((vEntry) {
                                bool isSel = vEntry.key == selectedVariantIndex;
                                bool isTaken = _isVariantTaken(vEntry.value);
                                String attr = vEntry.value.attribute;
                                return GestureDetector(
                                  onTap: isTaken ? null : () { _playClick(); setState(() => selectedVariantIndex = vEntry.key); },
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.skewX(-0.15),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      padding: const EdgeInsets.all(10),
                                      width: 100,
                                      decoration: BoxDecoration(
                                        color: isTaken ? Colors.grey.withValues(alpha: 0.1) : (isSel ? vEntry.value.color.withValues(alpha: 0.4) : Colors.transparent),
                                        border: Border.all(color: isTaken ? Colors.grey : (isSel ? vEntry.value.color : Colors.white24), width: 2),
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
                                      ),
                                      child: Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.skewX(0.15),
                                        child: ColorFiltered(
                                          colorFilter: isTaken ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                                          child: Image.asset(
                                            'assets/images/attributes/${attr}_game.png',
                                            width: 50, height: 50,
                                            fit: BoxFit.contain,
                                            errorBuilder: (c, e, s) => const Icon(Icons.stars, size: 40, color: Colors.white24)
                                          ),
                                        )
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          // LARGE PREVIEW
                          SizedBox(
                            width: 800, height: 500,
                            child: BakuganPreview(
                              key: ValueKey('large_${currentVariant.modelPath}'),
                              variant: currentVariant, 
                              isLarge: true,
                              speciesName: currentSpecies.name,
                              isTaken: currentIsTaken,
                            ),
                          ),
                        ],
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
        
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: widget.isTaken ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
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
            child: Transform(
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
  const CharacterMiniature({super.key, required this.char, required this.isSelected});

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
