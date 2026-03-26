part of '../../main.dart';

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
  final bool centerLargeFooter;

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
    this.centerLargeFooter = false,
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
      transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
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
          BakuganNameFooter(
            speciesName: widget.speciesName!,
            themeColor: themeColor,
            gPower: widget.showGPower ? widget.variant.gPower : null,
            center: widget.centerLargeFooter,
          ),

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

class _ProfileActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _ProfileActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.15),
        child: Container(
          width: 176,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, accent.withValues(alpha: 0.45), Colors.black],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.28),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(0.15),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 38, color: accent),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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

class PlayerSlot extends StatelessWidget {
  final String displayName;
  final String? char;
  final bool isActive;
  final bool isBlue;
  final bool isSavedProfile;

  const PlayerSlot({
    super.key,
    required this.displayName,
    this.char,
    required this.isActive,
    required this.isBlue,
    required this.isSavedProfile,
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
                  // --- NAME PLATE ---
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
                        transform: Matrix4.skewX(0.15),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName.toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 26,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              char == null
                                  ? 'OPEN SLOT'
                                  : (isSavedProfile ? 'REGISTERED' : 'INVITED'),
                              style: TextStyle(
                                color: char == null
                                    ? Colors.white70
                                    : (isSavedProfile
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
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
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: isSelected ? 1.0 : 0.94, end: 1.0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: currentGradient[0].withValues(
                  alpha: glowAlpha ?? (isSelected ? 0.6 : 0.2),
                ),
                blurRadius: glowAlpha != null ? 30 : (isSelected ? 20 : 10),
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
                              displayName.toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DescriptionHeaderActionButton extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onTap;

  const DescriptionHeaderActionButton({
    super.key,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(0.16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withValues(alpha: 0.16),
            border: Border.all(
              color: accentColor,
              width: 1.8,
            ),
          ),
          child: Icon(
            Icons.restart_alt_rounded,
            color: accentColor,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class FramedDescriptionPanel extends StatelessWidget {
  final double width;
  final String esText;
  final double maxHeight;
  final List<Color> frameGradient;
  final Color accentColor;
  final String? title;
  final Widget? headerAction;

  const FramedDescriptionPanel({
    super.key,
    required this.width,
    required this.esText,
    required this.maxHeight,
    required this.frameGradient,
    required this.accentColor,
    this.title,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
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
                            ),
                            if (headerAction != null) ...[
                              const SizedBox(width: 12),
                              Transform.translate(
                                offset: const Offset(0, -4),
                                child: headerAction!,
                              ),
                            ],
                          ],
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
}

class BakuganButton extends StatefulWidget {
  final IconData? icon;
  final bool iconOnly;
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
    this.icon,
    this.iconOnly = false,
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
              child: widget.icon != null
                  ? (widget.iconOnly
                        ? Icon(widget.icon, size: 40, color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(widget.icon, size: 28, color: Colors.white),
                              const SizedBox(width: 10),
                              Text(
                                widget.text,
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
                            ],
                          ))
                  : Text(
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
  final bool isExpanded;
  final VoidCallback? onPortraitTap;
  final Widget? portraitOverlay;
  final bool portraitOverlayAbove;

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
    this.isExpanded = false,
    this.onPortraitTap,
    this.portraitOverlay,
    this.portraitOverlayAbove = false,
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

    final double portraitWidth = isExpanded ? 230 : 180;
    final double portraitHeight = isExpanded ? 270 : 210;
    final double slotSize = isExpanded ? 116 : 90;
    final double slotGap = isExpanded ? 18 : 15;
    final double infoGap = isExpanded ? 54 : 40;

    final rowChildren = [
      // --- CHARACTER PORTRAIT ---
      GestureDetector(
        onTap: onPortraitTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubicEmphasized,
          width: portraitWidth,
          height: portraitHeight,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubicEmphasized,
            scale: isExpanded ? 1.0 : 0.92,
            child: CharacterMiniature(
              char: player.character,
              isSelected: isSelected,
              showName: true,
              label: player.name.toUpperCase(),
              glowAlpha: glowAlpha,
              thickness: thickness,
            ),
          ),
        ),
      ),
      SizedBox(width: infoGap),
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
                    width: slotSize,
                    height: slotSize,
                    margin: EdgeInsets.only(
                      right: isMirrored ? 0 : slotGap,
                      left: isMirrored ? slotGap : 0,
                    ),
                    padding: EdgeInsets.all(isPicked ? 4 : 2),
                    // The "Border" thickness
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

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: isMirrored ? rowChildren.reversed.toList() : rowChildren,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (portraitOverlayAbove && portraitOverlay != null) ...[
          portraitOverlay!,
          const SizedBox(height: 12),
        ],
        row,
        if (!portraitOverlayAbove && portraitOverlay != null) ...[
          const SizedBox(height: 12),
          portraitOverlay!,
        ],
      ],
    );
  }
}
