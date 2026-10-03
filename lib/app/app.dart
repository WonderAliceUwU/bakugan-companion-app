part of '../main.dart';

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<bool> _isAppSettingsOpen = ValueNotifier<bool>(false);

class BakuganApp extends StatelessWidget {
  const BakuganApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageController.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'Bakugan Stadium App',
          navigatorKey: _appNavigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            fontFamily: 'body_font',
          ),
          builder: (context, child) {
            return LanguageScope(
              controller: LanguageController.instance,
              child: _BakuganResponsiveSurface(
                child: _AppVolumeSurface(child: child),
              ),
            );
          },
          home: const VideoSplashScreen(),
        );
      },
    );
  }
}

const Size _bakuganReferenceSize = Size(2560, 1440);
const double _bakuganUiScale = 1.10;

class _BakuganResponsiveSurface extends StatelessWidget {
  final Widget? child;

  const _BakuganResponsiveSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = constraints.biggest;
        final virtualWidth = _bakuganReferenceSize.width / _bakuganUiScale;
        final widthScale = viewportSize.width / virtualWidth;
        final virtualHeight = viewportSize.height / widthScale;
        final virtualSize = Size(virtualWidth, virtualHeight);
        final designMediaQuery = mediaQuery.copyWith(
          size: virtualSize,
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
          viewInsets: EdgeInsets.zero,
          systemGestureInsets: EdgeInsets.zero,
        );

        return ColoredBox(
          color: Colors.black,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            child: MediaQuery(
              data: designMediaQuery,
              child: SizedBox(
                width: virtualSize.width,
                height: virtualSize.height,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
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

class AppVolumeController extends ChangeNotifier {
  AppVolumeController._();

  static final AppVolumeController instance = AppVolumeController._();

  final Map<AudioPlayer, double> _baseVolumes = <AudioPlayer, double>{};
  final Map<VideoPlayerController, double> _videoBaseVolumes =
      <VideoPlayerController, double>{};
  double _volume = 1;
  bool _isMuted = false;

  double get volume => _volume;
  bool get isMuted => _isMuted;
  double get effectiveVolume => _isMuted ? 0 : _volume;

  void register(AudioPlayer player, {double baseVolume = 1}) {
    _baseVolumes[player] = baseVolume;
    unawaited(player.setVolume(baseVolume * effectiveVolume));
  }

  void unregister(AudioPlayer player) {
    _baseVolumes.remove(player);
  }

  void registerVideo(VideoPlayerController player, {double baseVolume = 1}) {
    _videoBaseVolumes[player] = baseVolume;
    unawaited(player.setVolume(baseVolume * effectiveVolume));
  }

  void unregisterVideo(VideoPlayerController player) {
    _videoBaseVolumes.remove(player);
  }

  Future<void> setBaseVolume(AudioPlayer player, double baseVolume) async {
    register(player, baseVolume: baseVolume);
    await player.setVolume(baseVolume * effectiveVolume);
  }

  Future<void> setVideoBaseVolume(
    VideoPlayerController player,
    double baseVolume,
  ) async {
    registerVideo(player, baseVolume: baseVolume);
    await player.setVolume(baseVolume * effectiveVolume);
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 1).toDouble();
    if (_volume > 0) _isMuted = false;
    notifyListeners();
    await _applyVolume();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    notifyListeners();
    await _applyVolume();
  }

  Future<void> _applyVolume() async {
    final effectiveVolume = this.effectiveVolume;
    for (final entry in _baseVolumes.entries) {
      try {
        await entry.key.setVolume(entry.value * effectiveVolume);
      } catch (_) {}
    }
    for (final entry in _videoBaseVolumes.entries) {
      try {
        await entry.key.setVolume(entry.value * effectiveVolume);
      } catch (_) {}
    }
  }
}

class _AppVolumeSurface extends StatelessWidget {
  final Widget? child;

  const _AppVolumeSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(builder: (context) => child ?? const SizedBox.shrink()),
        OverlayEntry(
          builder: (context) {
            return ValueListenableBuilder<bool>(
              valueListenable: _isAppSettingsOpen,
              builder: (context, isOpen, _) {
                if (isOpen) return const SizedBox.shrink();
                return const Positioned(
                  top: 22,
                  right: 24,
                  child: _AppSettingsButton(),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _AppSettingsButton extends StatelessWidget {
  const _AppSettingsButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.settingsTitle,
      child: Material(
        type: MaterialType.transparency,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(-0.12),
          child: Container(
            width: 70,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF090D13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.9),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.22),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: GridPainter(
                      color: Colors.cyanAccent.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.cyanAccent.withValues(alpha: 0.12),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                ),
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.skewX(0.12),
                  child: _PressScale(
                    onPressed: _openAppSettingsDialog,
                    child: const SizedBox.expand(
                      child: Center(
                        child: Icon(
                          Icons.settings_rounded,
                          color: Colors.cyanAccent,
                          size: 32,
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
    );
  }
}

Future<void> _openAppSettingsDialog() async {
  if (_isAppSettingsOpen.value) return;
  final navigatorContext = _appNavigatorKey.currentContext;
  if (navigatorContext == null) return;

  _isAppSettingsOpen.value = true;
  try {
    await showGeneralDialog<void>(
      context: navigatorContext,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),
              const Center(child: AppSettingsDialog()),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curvedAnimation, child: child),
        );
      },
    );
  } finally {
    _isAppSettingsOpen.value = false;
  }
}

class AppSettingsDialog extends StatefulWidget {
  const AppSettingsDialog({super.key});

  @override
  State<AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends State<AppSettingsDialog> {
  late AppLanguage _selectedUiLang;
  late AppLanguage _selectedCardLang;

  @override
  void initState() {
    super.initState();
    _selectedUiLang = LanguageController.instance.uiLanguage;
    _selectedCardLang = LanguageController.instance.cardLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations(_selectedUiLang);

    return BakuganModal(
      title: l10n.settingsTitle,
      icon: Icons.settings_rounded,
      width: 820,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel(
              icon: Icons.volume_up_rounded,
              label: l10n.volume,
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 12),
            const _AppVolumeControls(),
            const SizedBox(height: 24),
            _buildSectionLabel(
              icon: Icons.language_rounded,
              label: l10n.languageLabel,
              color: Colors.amberAccent,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.uiLanguageLabel.toUpperCase(),
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildLanguageOption(
                  language: AppLanguage.es,
                  isSelected: _selectedUiLang == AppLanguage.es,
                  accentColor: Colors.cyanAccent,
                  onTap: () {
                    _playUiConfirmSound();
                    setState(() => _selectedUiLang = AppLanguage.es);
                  },
                ),
                const SizedBox(width: 14),
                _buildLanguageOption(
                  language: AppLanguage.en,
                  isSelected: _selectedUiLang == AppLanguage.en,
                  accentColor: Colors.cyanAccent,
                  onTap: () {
                    _playUiConfirmSound();
                    setState(() => _selectedUiLang = AppLanguage.en);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l10n.cardLanguageLabel.toUpperCase(),
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildLanguageOption(
                  language: AppLanguage.es,
                  isSelected: _selectedCardLang == AppLanguage.es,
                  accentColor: Colors.amberAccent,
                  onTap: () {
                    _playUiConfirmSound();
                    setState(() => _selectedCardLang = AppLanguage.es);
                  },
                ),
                const SizedBox(width: 14),
                _buildLanguageOption(
                  language: AppLanguage.en,
                  isSelected: _selectedCardLang == AppLanguage.en,
                  accentColor: Colors.amberAccent,
                  onTap: () {
                    _playUiConfirmSound();
                    setState(() => _selectedCardLang = AppLanguage.en);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        BakuganModalActionButton(
          text: l10n.ok,
          showGrid: false,
          useGradientBorder: false,
          onPressed: () {
            LanguageController.instance.setLanguages(
              ui: _selectedUiLang,
              card: _selectedCardLang,
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildSectionLabel({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageOption({
    required AppLanguage language,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: _PressScale(
        onPressed: onTap,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(-0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? accentColor : Colors.white24,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(0.12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LanguageFlag(language: language),
                  const SizedBox(width: 10),
                  Text(
                    language.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
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

class _AppVolumeControls extends StatelessWidget {
  const _AppVolumeControls();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: AppVolumeController.instance,
      builder: (context, _) {
        final controller = AppVolumeController.instance;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(-0.12),
          child: Container(
            height: 86,
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.75),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(0.12),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: controller.isMuted
                        ? l10n.unmuteAudio
                        : l10n.muteAudio,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.skewX(-0.12),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.2),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.skewX(0.12),
                          child: _PressScale(
                            onPressed: () => unawaited(controller.toggleMute()),
                            child: SizedBox.expand(
                              child: Center(
                                child: Icon(
                                  controller.isMuted || controller.volume == 0
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.92),
                            const Color(0xFF07151B).withValues(alpha: 0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 8,
                                activeTrackColor: Colors.cyanAccent,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.cyanAccent,
                                overlayColor: Colors.cyanAccent.withValues(
                                  alpha: 0.16,
                                ),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 18,
                                ),
                              ),
                              child: Slider(
                                value: controller.volume,
                                onChanged: (value) =>
                                    unawaited(controller.setVolume(value)),
                              ),
                            ),
                          ),
                          Text(
                            '${(controller.volume * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
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
      },
    );
  }
}
