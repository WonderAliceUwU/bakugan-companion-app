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

  void _navigateToHistory() async {
    await Navigator.of(context).push(_fadeRoute(const MatchHistoryScreen()));
  }

  Future<void> _quickBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final exportedPath = await LeaderboardRepository.instance.exportToFile();
      if (!mounted) return;
      await _playUiConfirmSound();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Backup saved to $exportedPath')),
        );
    } catch (error) {
      if (!mounted) return;
      await _playUiCancelSound();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Backup failed: $error')));
    }
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = min(920.0, constraints.maxWidth);
                    final isCompact = availableWidth < 760;
                    final buttonWidth = isCompact
                        ? min(420.0, availableWidth)
                        : (availableWidth - 24) / 2;

                    final buttons = [
                      BakuganButton(
                        text: 'BATTLE',
                        onPressed: _navigateToBattleMode,
                        width: buttonWidth,
                        height: 100,
                      ),
                      BakuganButton(
                        text: 'LEADERBOARD',
                        onPressed: _navigateToLeaderboard,
                        width: buttonWidth,
                        height: 100,
                      ),
                      BakuganButton(
                        text: 'HISTORY',
                        onPressed: _navigateToHistory,
                        width: buttonWidth,
                        height: 100,
                      ),
                      BakuganButton(
                        text: 'QUICK BACKUP',
                        onPressed: _quickBackup,
                        width: buttonWidth,
                        height: 100,
                      ),
                    ];

                    return SizedBox(
                      width: availableWidth,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 24,
                        runSpacing: 24,
                        children: buttons,
                      ),
                    );
                  },
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
  late Future<LeaderboardStore> _leaderboardFuture;
  bool _isEditingLeaderboard = false;
  int? _selectedSeasonNumber;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = LeaderboardRepository.instance.loadStore();
  }

  Future<void> _reload() async {
    final future = LeaderboardRepository.instance.loadStore();
    setState(() => _leaderboardFuture = future);
    await future;
  }

  Future<void> _deleteLeaderboardPlayer(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await LeaderboardRepository.instance.deleteSavedPlayer(name);
    final store = await LeaderboardRepository.instance.loadStore();
    if (!mounted) return;
    setState(() {
      _leaderboardFuture = Future.value(store);
      if (data.players.isEmpty) {
        _isEditingLeaderboard = false;
      }
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$name deleted.')));
  }

  Future<String?> _showPathPrompt({
    required String title,
    required String confirmLabel,
    required String initialPath,
    required Future<String?> Function() onExplore,
    String? subtitle,
  }) async {
    final controller = TextEditingController(text: initialPath);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(-0.08),
              child: Container(
                width: 760,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.cyanAccent.withValues(alpha: 0.55),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.16),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.skewX(0.08),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      TextField(
                        controller: controller,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: '/path/to/leaderboard.json',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            borderSide: BorderSide(
                              color: Colors.cyanAccent,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.cyanAccent,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          onPressed: () async {
                            final exploredPath = await onExplore();
                            if (exploredPath == null || exploredPath.isEmpty) {
                              return;
                            }
                            controller.text = exploredPath;
                            controller.selection = TextSelection.collapsed(
                              offset: controller.text.length,
                            );
                          },
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('EXPLORE'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              _playUiCancelSound();
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'CANCEL',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            onPressed: () {
                              _playUiConfirmSound();
                              Navigator.of(context).pop(controller.text.trim());
                            },
                            child: Text(confirmLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _exportLeaderboard() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final suggestedPath = await LeaderboardRepository.instance
          .suggestedBackupPath();
      if (!mounted) return;
      final selectedPath = await _showPathPrompt(
        title: 'EXPORT LEADERBOARD',
        confirmLabel: 'EXPORT',
        initialPath: suggestedPath,
        onExplore: () async {
          final fileName = suggestedPath.split(Platform.pathSeparator).last;
          final selectedPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Export Leaderboard',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: const ['json'],
          );
          if (selectedPath == null || selectedPath.trim().isEmpty) {
            return null;
          }
          return selectedPath.toLowerCase().endsWith('.json')
              ? selectedPath
              : '$selectedPath.json';
        },
        subtitle:
            'This creates a backup JSON with saved players and ranking progress.',
      );
      if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
        return;
      }
      final exportedPath = await LeaderboardRepository.instance.exportToFile(
        selectedPath,
      );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Leaderboard exported to $exportedPath')),
        );
    } catch (error) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }

  Future<void> _importLeaderboard() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final selectedPath = await _showPathPrompt(
        title: 'IMPORT LEADERBOARD',
        confirmLabel: 'IMPORT',
        initialPath: '',
        onExplore: () async {
          final result = await FilePicker.platform.pickFiles(
            dialogTitle: 'Import Leaderboard',
            allowMultiple: false,
            type: FileType.custom,
            allowedExtensions: const ['json'],
          );
          final path = result?.files.single.path;
          if (path == null || path.trim().isEmpty) {
            return null;
          }
          return path;
        },
        subtitle:
            'Importing replaces the current leaderboard file with the selected backup JSON.',
      );
      if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
        return;
      }
      final data = await LeaderboardRepository.instance.importFromFile(
        selectedPath,
      );
      final store = await LeaderboardRepository.instance.loadStore();
      if (!mounted) return;
      setState(() {
        _leaderboardFuture = Future.value(store);
        if (data.players.isEmpty) {
          _isEditingLeaderboard = false;
        }
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Leaderboard imported successfully.')),
        );
    } catch (error) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
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
                child: FutureBuilder<LeaderboardStore>(
                  future: _leaderboardFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final store = snapshot.data!;
                    _selectedSeasonNumber ??= store.currentSeasonNumber;
                    final allSeasons = <LeaderboardSeason>[
                      LeaderboardSeason(
                        seasonNumber: store.currentSeasonNumber,
                        title: 'Season ${store.currentSeasonNumber}',
                        leaderboard: store.currentLeaderboard,
                      ),
                      ...store.archivedSeasons,
                    ];
                    LeaderboardSeason selectedSeason = allSeasons.first;
                    for (final season in allSeasons) {
                      if (season.seasonNumber == _selectedSeasonNumber) {
                        selectedSeason = season;
                        break;
                      }
                    }
                    final seasonData = selectedSeason.leaderboard;
                    final isCurrentSeason =
                        selectedSeason.seasonNumber ==
                        store.currentSeasonNumber;
                    if (seasonData.players.isEmpty) {
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

                    final rankedPlayers = seasonData.players
                        .where((entry) => entry.isRanked)
                        .toList();
                    final topPlayer = rankedPlayers.isEmpty
                        ? null
                        : rankedPlayers.first;
                    final rankByPlayerKey = <String, int>{};
                    for (int i = 0; i < rankedPlayers.length; i++) {
                      rankByPlayerKey[_playerNameKey(rankedPlayers[i].name)] =
                          i + 1;
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final contentWidth = min(
                          1120.0,
                          max(320.0, constraints.maxWidth - 48),
                        );
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Column(
                            children: [
                              SizedBox(
                                width: contentWidth,
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final season in allSeasons)
                                      ChoiceChip(
                                        selected:
                                            season.seasonNumber ==
                                            selectedSeason.seasonNumber,
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedSeasonNumber =
                                                season.seasonNumber;
                                            if (season.seasonNumber !=
                                                store.currentSeasonNumber) {
                                              _isEditingLeaderboard = false;
                                            }
                                          });
                                        },
                                        label: Text(
                                          season.seasonNumber ==
                                                  store.currentSeasonNumber
                                              ? '${season.title} • CURRENT'
                                              : season.title,
                                          style: TextStyle(
                                            color:
                                                season.seasonNumber ==
                                                    selectedSeason.seasonNumber
                                                ? Colors.black
                                                : Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        selectedColor: Colors.cyanAccent,
                                        backgroundColor: Colors.black
                                            .withValues(alpha: 0.55),
                                        side: BorderSide(
                                          color:
                                              season.seasonNumber ==
                                                  selectedSeason.seasonNumber
                                              ? Colors.cyanAccent
                                              : Colors.white24,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: contentWidth,
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: Colors.cyanAccent.withValues(
                                      alpha: 0.7,
                                    ),
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyanAccent.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 30,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: topPlayer == null
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${selectedSeason.title} Has No Ranked Players Yet',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w900,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Each player needs 5 matches to leave Unranked.',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Wrap(
                                        spacing: 22,
                                        runSpacing: 22,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            width: 96,
                                            height: 96,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.black.withValues(
                                                alpha: 0.32,
                                              ),
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
                                          SizedBox(
                                            width: min(
                                              420.0,
                                              max(260.0, contentWidth * 0.36),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${selectedSeason.title} Top Ranked Player',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  topPlayer.name.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 34,
                                                    fontWeight: FontWeight.w900,
                                                    fontStyle: FontStyle.italic,
                                                    height: 1.05,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Wrap(
                                            spacing: 14,
                                            runSpacing: 14,
                                            children: [
                                              _LeaderboardStat(
                                                label: 'Points',
                                                value: topPlayer.points
                                                    .toString(),
                                                width: 118,
                                              ),
                                              _LeaderboardStat(
                                                label: 'Wins',
                                                value: topPlayer.wins
                                                    .toString(),
                                                width: 100,
                                              ),
                                              _LeaderboardStat(
                                                label: 'Win Rate',
                                                value: _formatWinRate(
                                                  topPlayer,
                                                ),
                                                width: 110,
                                              ),
                                              _LeaderboardStat(
                                                label: 'Gate Cards',
                                                value: topPlayer.gateCardsWon
                                                    .toString(),
                                                width: 118,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 18),
                              Expanded(
                                child: Container(
                                  width: contentWidth,
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
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  Colors.cyanAccent,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              textStyle: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                            onPressed: isCurrentSeason
                                                ? () => unawaited(
                                                    _importLeaderboard(),
                                                  )
                                                : null,
                                            icon: const Icon(
                                              Icons.file_open_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('IMPORT'),
                                          ),
                                          const SizedBox(width: 6),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  Colors.amberAccent,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              textStyle: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                            onPressed: () =>
                                                unawaited(_exportLeaderboard()),
                                            icon: const Icon(
                                              Icons.save_alt_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('EXPORT'),
                                          ),
                                          const Spacer(),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: !isCurrentSeason
                                                  ? Colors.white38
                                                  : _isEditingLeaderboard
                                                  ? Colors.orangeAccent
                                                  : Colors.cyanAccent,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              textStyle: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                            onPressed: isCurrentSeason
                                                ? () {
                                                    setState(() {
                                                      _isEditingLeaderboard =
                                                          !_isEditingLeaderboard;
                                                    });
                                                  }
                                                : null,
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
                                          itemCount: seasonData.players.length,
                                          separatorBuilder: (_, _) => Divider(
                                            color: Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                            height: 12,
                                          ),
                                          itemBuilder: (context, index) {
                                            final entry =
                                                seasonData.players[index];
                                            final rank =
                                                rankByPlayerKey[_playerNameKey(
                                                  entry.name,
                                                )];
                                            final isTop = rank == 1;
                                            return _LeaderboardRow(
                                              entry: entry,
                                              rank: rank,
                                              isTop: isTop,
                                              showDeleteAction:
                                                  _isEditingLeaderboard &&
                                                  isCurrentSeason,
                                              onDelete: () => unawaited(
                                                _deleteLeaderboardPlayer(
                                                  entry.name,
                                                ),
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
  final double width;

  const _LeaderboardStat({
    required this.label,
    required this.value,
    this.width = 130,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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
  final double width;

  const _LeaderboardValue({
    required this.label,
    required this.value,
    this.width = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
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

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final int? rank;
  final bool isTop;
  final bool showDeleteAction;
  final VoidCallback onDelete;

  const _LeaderboardRow({
    required this.entry,
    required this.rank,
    required this.isTop,
    required this.showDeleteAction,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final rankLabel = rank == null ? '-' : '#$rank';
    final rankColor = rank == null
        ? Colors.orangeAccent
        : _leaderboardRankColor(rank! - 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isTop ? Colors.cyanAccent.withValues(alpha: 0.08) : Colors.black,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isTop
              ? Colors.cyanAccent.withValues(alpha: 0.4)
              : Colors.white10,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final leftBlock = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  rankLabel,
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: compact ? constraints.maxWidth - 74 : 320,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _LeaderboardStatusChip(entry: entry),
                  ],
                ),
              ),
            ],
          );

          final statBlock = Wrap(
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            spacing: 22,
            runSpacing: 16,
            children: [
              _LeaderboardValue(
                label: 'Pts',
                value: entry.points.toString(),
                width: 92,
              ),
              _LeaderboardValue(
                label: 'Wins',
                value: entry.wins.toString(),
                width: 82,
              ),
              _LeaderboardValue(
                label: 'WR',
                value: _formatWinRate(entry),
                width: 82,
              ),
              _LeaderboardValue(
                label: 'Match',
                value: entry.matches.toString(),
                width: 82,
              ),
              _LeaderboardValue(
                label: 'Gate',
                value: entry.gateCardsWon.toString(),
                width: 82,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftBlock,
                const SizedBox(height: 18),
                statBlock,
                if (showDeleteAction) ...[
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _DeleteLeaderboardButton(onTap: onDelete),
                  ),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: leftBlock),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: statBlock),
              if (showDeleteAction) ...[
                const SizedBox(width: 18),
                _DeleteLeaderboardButton(onTap: onDelete),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DeleteLeaderboardButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteLeaderboardButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _LeaderboardStatusChip extends StatelessWidget {
  final LeaderboardEntry entry;

  const _LeaderboardStatusChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isRanked = entry.isRanked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isRanked
            ? Colors.cyanAccent.withValues(alpha: 0.12)
            : Colors.orangeAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isRanked
              ? Colors.cyanAccent.withValues(alpha: 0.5)
              : Colors.orangeAccent.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        isRanked
            ? 'RANKED • ${entry.matches} matches'
            : 'UNRANKED • ${entry.matchesUntilRanked} matches left',
        style: TextStyle(
          color: isRanked ? Colors.cyanAccent : Colors.orangeAccent,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

String _formatWinRate(LeaderboardEntry entry) {
  if (entry.matches == 0) return '0%';
  return '${(entry.winRate * 100).round()}%';
}

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  late Future<LeaderboardStore> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = LeaderboardRepository.instance.loadStore();
  }

  Future<void> _reload() async {
    final future = LeaderboardRepository.instance.loadStore();
    setState(() => _historyFuture = future);
    await future;
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
                        'MATCH HISTORY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'title_font',
                          fontSize: 42,
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
                child: FutureBuilder<LeaderboardStore>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final history = snapshot.data!.matchHistory;
                    if (history.isEmpty) {
                      return Center(
                        child: Container(
                          width: 620,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: const Text(
                            'No matches recorded yet.\nFinish a match and it will appear here with players, Bakugan, abilities and gate cards.',
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

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final contentWidth = min(
                          1120.0,
                          max(320.0, constraints.maxWidth - 48),
                        );
                        return Center(
                          child: SizedBox(
                            width: contentWidth,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                              itemCount: history.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final entry = history[index];
                                return _MatchHistoryCard(entry: entry);
                              },
                            ),
                          ),
                        );
                      },
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

class _MatchHistoryCard extends StatefulWidget {
  final MatchHistoryEntry entry;

  const _MatchHistoryCard({required this.entry});

  @override
  State<_MatchHistoryCard> createState() => _MatchHistoryCardState();
}

class _MatchHistoryCardState extends State<_MatchHistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final winners = entry.winnerNames.join(', ').toUpperCase();
    final playedAt = _formatHistoryDate(entry.playedAt);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12, width: 2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (value) => setState(() => _isExpanded = value),
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          iconColor: Colors.cyanAccent,
          collapsedIconColor: Colors.cyanAccent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _HistoryBadge(
                    label: 'Season ${entry.seasonNumber}',
                    color: Colors.cyanAccent,
                  ),
                  _HistoryBadge(
                    label: entry.isTeamBattle ? 'TEAM BATTLE' : 'BATTLE ROYALE',
                    color: Colors.amberAccent,
                  ),
                  _HistoryBadge(label: playedAt, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 14),
              AutoSizeText(
                winners.isEmpty ? 'NO WINNER' : winners,
                maxLines: 1,
                minFontSize: 22,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${entry.players.length} players • ${entry.battles.length} battles',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          children: _isExpanded
              ? [
                  _MatchHistoryExpandedContent(entry: entry),
                ]
              : const [],
        ),
      ),
    );
  }
}

class _HistoryBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _HistoryBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _MatchHistoryExpandedContent extends StatelessWidget {
  final MatchHistoryEntry entry;

  const _MatchHistoryExpandedContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final player in entry.players) _HistoryPlayerCard(player: player),
          ],
        ),
        const SizedBox(height: 18),
        if (entry.battles.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'BATTLE LOG',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (final battle in entry.battles) ...[
                _HistoryBattleRow(battle: battle),
                if (battle != entry.battles.last)
                  Divider(
                    color: Colors.white.withValues(alpha: 0.08),
                    height: 20,
                  ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _HistoryPlayerCard extends StatelessWidget {
  final MatchHistoryPlayerEntry player;

  const _HistoryPlayerCard({required this.player});

  @override
  Widget build(BuildContext context) {
    final sortedSlots = [...player.abilitySlots]
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    return Container(
      width: 520,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: player.isWinner
            ? Colors.cyanAccent.withValues(alpha: 0.08)
            : Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: player.isWinner
              ? Colors.cyanAccent.withValues(alpha: 0.4)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                height: 112,
                child: CharacterMiniature(
                  char: player.character,
                  isSelected: player.isWinner,
                  showName: false,
                  thickness: 4,
                  glowAlpha: player.isWinner ? 0.42 : 0.18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            player.character.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _HistoryGateCardTicks(count: player.gateCardsWon),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (int i = 0; i < 3; i++) ...[
                            _HistoryAbilityMiniCard(
                              card: i < sortedSlots.length
                                  ? sortedSlots[i].card
                                  : null,
                              width: 58,
                              borderRadius: 2,
                            ),
                            if (i != 2) const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _HistorySectionTitle('BAKUGAN'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final bakugan in player.bakuganUsed)
                _HistoryBakuganMiniCard(bakugan: bakugan),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistorySectionTitle extends StatelessWidget {
  final String title;

  const _HistorySectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _HistoryGateCardTicks extends StatelessWidget {
  final int count;

  const _HistoryGateCardTicks({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final isFilled = index < count;
        return Transform(
          transform: Matrix4.skewX(-0.25),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28,
            height: 42,
            margin: const EdgeInsets.only(right: 6),
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
                width: 2.4,
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: isFilled
                  ? [
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
          ),
        );
      }),
    );
  }
}

class _HistoryBakuganMiniCard extends StatelessWidget {
  final MatchHistoryBakuganEntry bakugan;

  const _HistoryBakuganMiniCard({required this.bakugan});

  @override
  Widget build(BuildContext context) {
    final borderColor = _historyAttributeColor(bakugan.attribute);
    final variant = _historyVariantFromEntry(bakugan);
    return SizedBox(
      width: 148,
      child: Column(
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(-0.15),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor.withValues(alpha: 0.45)),
              ),
              child: SizedBox(
                width: 132,
                height: 102,
                child: variant == null
                    ? const SizedBox.expand()
                    : BakuganPreview(
                        variant: variant,
                        speciesName: variant.speciesName,
                        isDeck: true,
                        autoRotate: false,
                        disableInteraction: true,
                        showGPower: false,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bakugan.speciesName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${bakugan.gPower}G',
            style: TextStyle(
              color: borderColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryAbilityMiniCard extends StatelessWidget {
  final MatchHistoryCardEntry? card;
  final double width;
  final double borderRadius;

  const _HistoryAbilityMiniCard({
    required this.card,
    this.width = 74,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = card?.imagePath.isNotEmpty == true
        ? card!.imagePath
        : 'assets/images/cards/anverse.png';
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) => Image.asset(
            'assets/images/cards/anverse.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _HistoryBattleRow extends StatelessWidget {
  final MatchBattleRecord battle;

  const _HistoryBattleRow({required this.battle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    '${battle.leftPlayerName.toUpperCase()} VS ${battle.rightPlayerName.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'BATTLE ${battle.battleNumber}',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    _HistoryBattleCompetitor(
                      side: battle.leftSide,
                      isLeftSide: true,
                    ),
                    const SizedBox(height: 14),
                    _HistoryBattleGateCard(card: battle.revealedGateCard),
                    const SizedBox(height: 14),
                    _HistoryBattleCompetitor(
                      side: battle.rightSide,
                      isLeftSide: false,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _HistoryBattleCompetitor(
                      side: battle.leftSide,
                      isLeftSide: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _HistoryBattleGateCard(card: battle.revealedGateCard),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _HistoryBattleCompetitor(
                      side: battle.rightSide,
                      isLeftSide: false,
                    ),
                  ),
                ],
              );
            },
          ),
          if (battle.externalAbilitiesUsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text(
                    'EXT',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  for (final card in battle.externalAbilitiesUsed)
                    _HistoryAbilityMiniCard(
                      card: card,
                      borderRadius: 2,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryBattleCompetitor extends StatelessWidget {
  final MatchHistoryBattleSideEntry side;
  final bool isLeftSide;

  const _HistoryBattleCompetitor({
    required this.side,
    required this.isLeftSide,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isLeftSide ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (isLeftSide) ...[
          _HistoryBattleBakuganMini(side: side),
          if (side.abilitiesUsed.isNotEmpty) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Align(
                alignment: Alignment.center,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final card in side.abilitiesUsed)
                      _HistoryAbilityMiniCard(
                        card: card,
                        borderRadius: 2,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ] else ...[
          if (side.abilitiesUsed.isNotEmpty) ...[
            Flexible(
              child: Align(
                alignment: Alignment.center,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final card in side.abilitiesUsed)
                      _HistoryAbilityMiniCard(
                        card: card,
                        borderRadius: 2,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          _HistoryBattleBakuganMini(side: side),
        ],
      ],
    );
  }
}

class _HistoryBattleBakuganMini extends StatelessWidget {
  final MatchHistoryBattleSideEntry side;

  const _HistoryBattleBakuganMini({
    required this.side,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = _historyAttributeColor(side.bakugan.attribute);
    final variant = _historyVariantFromEntry(side.bakugan);
    return SizedBox(
      width: 170,
      child: Column(
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(-0.15),
            child: CustomPaint(
              foregroundPainter: _HistoryBakuganMiniBorderPainter(
                color: borderColor.withValues(alpha: 0.6),
                glowColor: side.isWinner ? borderColor : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 132,
                    height: 102,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.03),
                                  Colors.transparent,
                                  borderColor.withValues(alpha: 0.03),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: GridPainter(
                              color: borderColor.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        if (variant != null)
                          BakuganPreview(
                            variant: variant,
                            speciesName: variant.speciesName,
                            isDeck: true,
                            autoRotate: false,
                            disableInteraction: true,
                            showGPower: false,
                            showGridBackground: false,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(-0.15),
            child: Text(
              side.bakugan.speciesName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${side.finalGPower}G',
            style: TextStyle(
              color: borderColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryBakuganMiniBorderPainter extends CustomPainter {
  final Color color;
  final Color? glowColor;

  const _HistoryBakuganMiniBorderPainter({
    required this.color,
    this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    if (glowColor != null) {
      final glowPaint = Paint()
        ..color = glowColor!.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRRect(rrect, glowPaint);

      final outerGlowPaint = Paint()
        ..color = glowColor!.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
      canvas.drawRRect(rrect, outerGlowPaint);
    }

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(rrect.deflate(0.7), strokePaint);
  }

  @override
  bool shouldRepaint(covariant _HistoryBakuganMiniBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.glowColor != glowColor;
  }
}

class _HistoryBattleGateCard extends StatelessWidget {
  final MatchHistoryCardEntry? card;

  const _HistoryBattleGateCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final imagePath = card?.imagePath.isNotEmpty == true
        ? card!.imagePath
        : 'assets/images/cards/anverse.png';
    return SizedBox(
      width: 136,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(
              width: 136,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.18),
                    blurRadius: 26,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    blurRadius: 46,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => Image.asset(
                'assets/images/cards/anverse.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _historyAttributeColor(String attribute) {
  switch (attribute.trim().toLowerCase()) {
    case 'pyrus':
      return Colors.redAccent;
    case 'aquos':
      return Colors.lightBlueAccent;
    case 'subterra':
      return Colors.orangeAccent;
    case 'haos':
      return Colors.amberAccent;
    case 'darkus':
      return Colors.deepPurpleAccent;
    case 'ventus':
      return Colors.greenAccent;
    default:
      return Colors.white70;
  }
}

BakuganVariant? _historyVariantFromEntry(MatchHistoryBakuganEntry entry) {
  final modelPath = entry.modelPath?.trim() ?? '';
  if (modelPath.isNotEmpty) {
    return BakuganVariant(
      attribute: entry.attribute,
      modelPath: modelPath,
      color: _historyAttributeColor(entry.attribute),
      gPower: entry.gPower,
      speciesName: entry.speciesName,
    );
  }

  for (final bakugan in availableBakugans) {
    if (bakugan.name.trim().toLowerCase() !=
        entry.speciesName.trim().toLowerCase()) {
      continue;
    }
    for (final variant in bakugan.variants) {
      if (variant.attribute.trim().toLowerCase() !=
          entry.attribute.trim().toLowerCase()) {
        continue;
      }
      if (entry.gPower > 0 && variant.gPower != entry.gPower) {
        continue;
      }
      return variant;
    }
    for (final variant in bakugan.variants) {
      if (variant.attribute.trim().toLowerCase() ==
          entry.attribute.trim().toLowerCase()) {
        return variant;
      }
    }
  }

  return null;
}

String _formatHistoryDate(String rawIsoDate) {
  final parsed = DateTime.tryParse(rawIsoDate);
  if (parsed == null) return rawIsoDate;
  final local = parsed.toLocal();
  final month = switch (local.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} $month ${local.year} • $hour:$minute';
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
