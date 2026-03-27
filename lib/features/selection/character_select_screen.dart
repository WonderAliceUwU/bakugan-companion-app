part of '../../main.dart';

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
          padding: const EdgeInsets.all(4),
          // Border thickness
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
  final List<SavedPlayerProfile?> _selectedPlayers = List.filled(4, null);
  List<SavedPlayerProfile> _savedPlayers = const [];
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
    _playMenuMusic();
    unawaited(_loadSavedPlayers());
  }

  Future<void> _playMenuMusic() async {
    try {
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.play(AssetSource('music/menu/Menu.flac'));
    } catch (_) {}
  }

  Future<void> _playTitleMusic() async {
    try {
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.setVolume(0.3);
      await _bgMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgMusicPlayer.play(AssetSource('music/menu/Title.flac'));
    } catch (_) {}
  }

  void _playClick() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sound/select_2.wav'));
  }

  void _playCancel() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sound/cancel.wav'));
  }

  Future<void> _loadSavedPlayers() async {
    final data = await LeaderboardRepository.instance.load();
    if (!mounted) return;
    setState(() => _savedPlayers = data.savedPlayers);
  }

  SavedPlayerProfile? _savedProfileByName(String value) {
    final key = _playerNameKey(value);
    for (final entry in _savedPlayers) {
      if (_playerNameKey(entry.name) == key) {
        return entry;
      }
    }
    return null;
  }

  SavedPlayerProfile? get _currentSelectedPlayer =>
      _selectedPlayers[currentPlayerIndex];

  void _assignPlayerToCurrentSlot(SavedPlayerProfile profile) {
    setState(() {
      _selectedPlayers[currentPlayerIndex] = profile;
    });
  }

  void _showCharacterSelectMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPlayerProfilePrompt({required bool saveProfile}) async {
    _playClick();
    String selectedCharacter = characters.first;
    final controller = TextEditingController();

    final draft = await showDialog<SavedPlayerProfile>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 60,
                vertical: 40,
              ),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.skewX(-0.08),
                child: Container(
                  width: 980,
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF07131E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.cyanAccent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.18),
                        blurRadius: 26,
                        spreadRadius: 3,
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
                          saveProfile ? 'REGISTER PLAYER' : 'INVITE PLAYER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          saveProfile
                              ? 'Choose a Bakugan profile photo and save this player for later.'
                              : 'Choose a Bakugan profile photo for this temporary invited player.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: controller,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Player name',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.28),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.cyanAccent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          height: 224,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(
                              left: 26,
                              right: 16,
                            ),
                            itemCount: characters.length,
                            itemBuilder: (context, index) {
                              final character = characters[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index == characters.length - 1 ? 0 : 18,
                                ),
                                child: SizedBox(
                                  width: 188,
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: () {
                                        _playClick();
                                        setDialogState(() {
                                          selectedCharacter = character;
                                        });
                                      },
                                      child: SizedBox(
                                        width: 176,
                                        child: CharacterMiniature(
                                          char: character,
                                          isSelected:
                                              selectedCharacter == character,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.orangeAccent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              onPressed: () {
                                _playCancel();
                                Navigator.of(context).pop();
                              },
                              child: const Text('CANCEL'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: saveProfile
                                    ? Colors.cyanAccent
                                    : Colors.orangeAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              onPressed: () {
                                _playClick();
                                final sanitized =
                                    _sanitizePlayerName(controller.text);
                                if (sanitized.isEmpty) {
                                  _showCharacterSelectMessage('Enter a player name.');
                                  return;
                                }
                                Navigator.of(context).pop(
                                  SavedPlayerProfile(
                                    name: sanitized,
                                    character: selectedCharacter,
                                  ),
                                );
                              },
                              child: Text(saveProfile ? 'SAVE' : 'INVITE'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();

    if (!mounted || draft == null) return;

    if (saveProfile) {
      final data = await LeaderboardRepository.instance.savePlayerProfile(
        rawName: draft.name,
        character: draft.character,
      );
      final canonical = data.savedPlayers.firstWhere(
        (entry) => _playerNameKey(entry.name) == _playerNameKey(draft.name),
        orElse: () => draft,
      );
      if (!mounted) return;
      setState(() {
        _savedPlayers = data.savedPlayers;
        _selectedPlayers[currentPlayerIndex] = canonical;
      });
      _showCharacterSelectMessage('${canonical.name} registered.');
      return;
    }

    _assignPlayerToCurrentSlot(draft);
    _showCharacterSelectMessage('${draft.name} invited for this match.');
  }

  void _onOkPressed() {
    final currentPlayer = _currentSelectedPlayer;
    if (currentPlayer == null) {
      _showCharacterSelectMessage('Select, invite, or register a player first.');
      return;
    }
    if (currentPlayerIndex < playerCount - 1) {
      setState(() => currentPlayerIndex++);
    } else {
      final currentNames = List.generate(
        playerCount,
        (i) => _selectedPlayers[i]?.name ?? '',
      );
      if (currentNames.any((name) => name.isEmpty)) {
        _showCharacterSelectMessage('Every player slot needs a selected profile.');
        return;
      }
      final uniqueKeys = currentNames.map(_playerNameKey).toSet();
      if (uniqueKeys.length != currentNames.length) {
        _showCharacterSelectMessage('Player names must be unique.');
        return;
      }
      List<PlayerData> players = List.generate(
        playerCount,
        (i) => PlayerData(
          name: _selectedPlayers[i]!.name,
          character: _selectedPlayers[i]!.character,
          isSavedProfile:
              _savedProfileByName(_selectedPlayers[i]!.name) != null,
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
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  _playCancel();
                  await _playTitleMusic();
                  if (!mounted) return;
                  navigator.pop();
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
                            displayName:
                                _selectedPlayers[i]?.name ?? 'Selecting...',
                            char: _selectedPlayers[i]?.character,
                            isActive: i == currentPlayerIndex,
                            isBlue: i % 2 == 0,
                            isSavedProfile: _selectedPlayers[i] != null &&
                                _savedProfileByName(_selectedPlayers[i]!.name) !=
                                    null,
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
                  height: 230,
                  width: double.infinity,
                  color: Colors.black45,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _savedPlayers.length + 2,
                          separatorBuilder: (_, _) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _ProfileActionCard(
                                icon: Icons.person_add_alt_1_rounded,
                                title: 'INVITE',
                                subtitle: 'Temporary player',
                                accent: Colors.orangeAccent,
                                onTap: () =>
                                    _openPlayerProfilePrompt(saveProfile: false),
                              );
                            }
                            if (index == 1) {
                              return _ProfileActionCard(
                                icon: Icons.add_circle_rounded,
                                title: 'REGISTER',
                                subtitle: 'Save a player',
                                accent: Colors.cyanAccent,
                                onTap: () =>
                                    _openPlayerProfilePrompt(saveProfile: true),
                              );
                            }

                            final profile = _savedPlayers[index - 2];
                            final currentKey = _playerNameKey(
                              _currentSelectedPlayer?.name ?? '',
                            );
                            return SizedBox(
                              width: 176,
                              child: GestureDetector(
                                onTap: () {
                                  _playClick();
                                  _assignPlayerToCurrentSlot(profile);
                                },
                                child: CharacterMiniature(
                                  char: profile.character,
                                  isSelected:
                                      currentKey == _playerNameKey(profile.name),
                                  label: profile.name,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
