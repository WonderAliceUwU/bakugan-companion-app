part of '../../main.dart';

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
      await _sfxPlayer.play(AssetSource('sound/select_2.wav'));
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

  void _navigateToBattleMode() async {
    await Navigator.of(context).push(_fadeRoute(const BattleModeScreen()));
  }

  void _navigateToLeaderboard() async {
    await Navigator.of(context).push(_fadeRoute(const LeaderboardScreen()));
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
                      onPressed: _navigateToLeaderboard,
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

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<LeaderboardData> _leaderboardFuture;
  bool _isEditingLeaderboard = false;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = LeaderboardRepository.instance.load();
  }

  Future<void> _reload() async {
    final future = LeaderboardRepository.instance.load();
    setState(() => _leaderboardFuture = future);
    await future;
  }

  Future<void> _deleteLeaderboardPlayer(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await LeaderboardRepository.instance.deleteSavedPlayer(name);
    if (!mounted) return;
    setState(() {
      _leaderboardFuture = Future.value(data);
      if (data.players.isEmpty) {
        _isEditingLeaderboard = false;
      }
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$name deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Menu.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        _playUiCancelSound();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'LEADERBOARD',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'title_font',
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.blueAccent, blurRadius: 24),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _reload,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<LeaderboardData>(
                  future: _leaderboardFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final data = snapshot.data!;
                    if (data.players.isEmpty) {
                      return Center(
                        child: Container(
                          width: 560,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: const Text(
                            'No registered players yet.\nAdd one from character selection with the register button.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    }

                    final topPlayer = data.players.first;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        children: [
                          Container(
                            width: 920,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.cyanAccent.withValues(alpha: 0.7),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withValues(alpha: 0.18),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.32),
                                    border: Border.all(
                                      color: Colors.amberAccent,
                                      width: 3,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '#1',
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 22),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Top Player',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        topPlayer.name.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _LeaderboardStat(
                                  label: 'Wins',
                                  value: topPlayer.wins.toString(),
                                ),
                                const SizedBox(width: 16),
                                _LeaderboardStat(
                                  label: 'Points',
                                  value: topPlayer.points.toString(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: Container(
                              width: 920,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Spacer(),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: _isEditingLeaderboard
                                              ? Colors.orangeAccent
                                              : Colors.cyanAccent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          textStyle: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isEditingLeaderboard =
                                                !_isEditingLeaderboard;
                                          });
                                        },
                                        icon: Icon(
                                          _isEditingLeaderboard
                                              ? Icons.close_rounded
                                              : Icons.edit_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _isEditingLeaderboard
                                              ? 'DONE'
                                              : 'EDIT',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: data.players.length,
                                      separatorBuilder: (_, _) => Divider(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        height: 12,
                                      ),
                                      itemBuilder: (context, index) {
                                        final entry = data.players[index];
                                        final isTop = index == 0;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isTop
                                                ? Colors.cyanAccent.withValues(
                                                    alpha: 0.08,
                                                  )
                                                : Colors.black,
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(
                                              color: isTop
                                                  ? Colors.cyanAccent.withValues(
                                                      alpha: 0.4,
                                                    )
                                                  : Colors.white10,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 70,
                                                child: Text(
                                                  '#${index + 1}',
                                                  style: TextStyle(
                                                    color:
                                                        _leaderboardRankColor(
                                                          index,
                                                        ),
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  entry.name.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w900,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                              _LeaderboardValue(
                                                label: 'Wins',
                                                value: entry.wins.toString(),
                                              ),
                                              const SizedBox(width: 12),
                                              _LeaderboardValue(
                                                label: 'Points',
                                                value: entry.points.toString(),
                                              ),
                                              if (_isEditingLeaderboard) ...[
                                                const SizedBox(width: 14),
                                                GestureDetector(
                                                  onTap: () => unawaited(
                                                    _deleteLeaderboardPlayer(
                                                      entry.name,
                                                    ),
                                                  ),
                                                  child: Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.redAccent,
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.delete_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardStat extends StatelessWidget {
  final String label;
  final String value;

  const _LeaderboardStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardValue extends StatelessWidget {
  final String label;
  final String value;

  const _LeaderboardValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
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

  void _playCancel() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sound/cancel.wav'));
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
                  _playCancel();
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
