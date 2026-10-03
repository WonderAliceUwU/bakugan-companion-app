part of '../../main.dart';

// OBJ preview tuning controls. Adjust these values to change the framing
// without touching the model-loading or card-layout code.
const _objCameraDistance = 11.0;
const _objClosedCameraDistance = 30.0;
const _objCameraHeight = 1.5;
const _objCameraTargetY = 0.0;
const _objCameraFov = 20.0;
const _objModelScale = 5.0;
const _objModelOffsetY = 0.35;
const _objInitialRotationX = 0.0;
const _objInitialRotationY = -32.0;
const _objInitialRotationZ = 0.0;
const _objRotationDegreesPerSecond = 10.0;
const _objLargePreviewOffsetY = 60.0;
const _objClosedPreviewOffsetY = 10.0;
const _objSmallPreviewOffsetY = 20.0;

class _BakuganObjViewer extends StatefulWidget {
  final String modelPath;
  final String? texturePath;
  final double cameraDistance;
  final bool enableTouch;
  final bool autoRotate;
  final VoidCallback? onTap;

  const _BakuganObjViewer({
    super.key,
    required this.modelPath,
    required this.texturePath,
    required this.cameraDistance,
    required this.enableTouch,
    required this.autoRotate,
    this.onTap,
  });

  @override
  State<_BakuganObjViewer> createState() => _BakuganObjViewerState();
}

class _BakuganObjViewerState extends State<_BakuganObjViewer> {
  late obj_scene.Scene _scene;
  Timer? _rotationTimer;
  obj_object.Object? _modelRoot;
  Offset? _lastPanPosition;
  double _rotationX = _objInitialRotationX;
  double _rotationY = _objInitialRotationY;
  double _rotationZ = _objInitialRotationZ;
  int _loadToken = 0;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _scene = _newScene();
    _loadModel();
  }

  obj_scene.Scene _newScene() {
    return obj_scene.Scene(
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<ui.Image> _loadTexture(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  Future<void> _loadModel() async {
    final int token = ++_loadToken;
    _rotationTimer?.cancel();
    setState(() {
      _isLoaded = false;
    });

    try {
      final meshes = await obj_mesh.loadObj(widget.modelPath, true);
      final texture = widget.texturePath == null
          ? null
          : await _loadTexture(widget.texturePath!);
      final scene = _newScene();
      // Keep the OBJ framing close to the old GLB preview. The package's
      // generic OBJ camera starts at z=10, which leaves these normalized
      // Bakugan models noticeably smaller than the previous preview.
      scene.camera.position.z = widget.cameraDistance;
      scene.camera.position.y = _objCameraHeight;
      scene.camera.target.y = _objCameraTargetY;
      scene.camera.fov = _objCameraFov;
      scene.texture = texture;

      var minX = double.infinity;
      var minY = double.infinity;
      var minZ = double.infinity;
      var maxX = double.negativeInfinity;
      var maxY = double.negativeInfinity;
      var maxZ = double.negativeInfinity;
      for (final mesh in meshes) {
        for (final vertex in mesh.vertices) {
          minX = min(minX, vertex.x);
          minY = min(minY, vertex.y);
          minZ = min(minZ, vertex.z);
          maxX = max(maxX, vertex.x);
          maxY = max(maxY, vertex.y);
          maxZ = max(maxZ, vertex.z);
        }
      }
      final modelCenterX = minX.isFinite ? (minX + maxX) / 2 : 0.0;
      final modelCenterY = minY.isFinite ? (minY + maxY) / 2 : 0.0;
      final modelCenterZ = minZ.isFinite ? (minZ + maxZ) / 2 : 0.0;
      final modelRoot = obj_object.Object(scene: scene);
      modelRoot.position.y = _objModelOffsetY;
      modelRoot.scale.setValues(_objModelScale, _objModelScale, _objModelScale);
      modelRoot.rotation.x = _rotationX;
      modelRoot.rotation.y = _rotationY;
      modelRoot.rotation.z = _rotationZ;
      modelRoot.updateTransform();
      scene.world.add(modelRoot);

      for (final mesh in meshes) {
        mesh.texture = texture;
        mesh.texturePath = widget.texturePath;
        if (texture != null) {
          // The OBJ assets do not always include their MTL files. When the
          // texture is supplied by the variant, replace the parser's default
          // 1x1 texture rectangle so UVs cover the complete image.
          mesh.textureRect = Rect.fromLTWH(
            0,
            0,
            texture.width.toDouble(),
            texture.height.toDouble(),
          );
        }
        final object = obj_object.Object(mesh: mesh, scene: scene);
        object.position.setValues(-modelCenterX, -modelCenterY, -modelCenterZ);
        object.updateTransform();
        modelRoot.add(object);
      }
      scene.updateTexture();

      if (!mounted || token != _loadToken) return;
      setState(() {
        _scene = scene;
        _modelRoot = modelRoot;
        _isLoaded = true;
      });
      _startRotation();
    } catch (error) {
      debugPrint('Error loading OBJ model: $error');
      if (!mounted || token != _loadToken) return;
      setState(() {
        _isLoaded = false;
      });
    }
  }

  void _startRotation() {
    _rotationTimer?.cancel();
    if (!widget.autoRotate || !_isLoaded) return;
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _rotationY += _objRotationDegreesPerSecond / 60;
      _modelRoot?.rotation.y = _rotationY;
      _modelRoot?.updateTransform();
      _scene.update();
    });
  }

  @override
  void didUpdateWidget(covariant _BakuganObjViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelPath != widget.modelPath ||
        oldWidget.texturePath != widget.texturePath) {
      _loadModel();
    } else if (oldWidget.cameraDistance != widget.cameraDistance) {
      _loadModel();
    } else if (oldWidget.autoRotate != widget.autoRotate) {
      _startRotation();
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final previousPosition = _lastPanPosition;
    if (previousPosition == null) {
      _lastPanPosition = details.localPosition;
      return;
    }
    _scene.camera.trackBall(
      obj_viewer.toVector2(previousPosition),
      obj_viewer.toVector2(details.localPosition),
      1.25,
    );
    _lastPanPosition = details.localPosition;
    _scene.update();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = _BakuganObjPainter(_scene);
        final child = CustomPaint(
          painter: painter,
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
        if (!widget.enableTouch) return child;
        return GestureDetector(
          // Use a drag recognizer for model rotation. Scale gestures make a
          // mouse drag look like a zoom on macOS even with one pointer.
          onTap: widget.onTap,
          onPanStart: (details) {
            _rotationTimer?.cancel();
            _lastPanPosition = details.localPosition;
          },
          onPanUpdate: _handlePanUpdate,
          onPanEnd: (_) {
            _lastPanPosition = null;
            _startRotation();
          },
          onPanCancel: () {
            _lastPanPosition = null;
            _startRotation();
          },
          child: child,
        );
      },
    );
  }
}

class _BakuganObjPainter extends CustomPainter {
  final obj_scene.Scene scene;

  const _BakuganObjPainter(this.scene);

  @override
  void paint(Canvas canvas, Size size) {
    scene.camera.viewportWidth = size.width;
    scene.camera.viewportHeight = size.height;
    scene.render(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _BakuganObjPainter oldDelegate) => true;
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
  final bool centerLargeFooter;
  final String? statusLabel;
  final String? illustrationAssetPath;
  final double? visualScaleOverride;
  final Alignment? visualAlignmentOverride;
  final EdgeInsets? visualPaddingOverride;
  final Widget? frameBackground;
  final bool showGridBackground;
  final double? gridOpacityOverride;
  final bool showIllustrationShadow;
  final Offset illustrationShadowOffset;
  final double illustrationShadowOpacity;
  final double illustrationShadowBlur;

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
    this.statusLabel,
    this.illustrationAssetPath,
    this.visualScaleOverride,
    this.visualAlignmentOverride,
    this.visualPaddingOverride,
    this.frameBackground,
    this.showGridBackground = true,
    this.gridOpacityOverride,
    this.showIllustrationShadow = false,
    this.illustrationShadowOffset = const Offset(14, 18),
    this.illustrationShadowOpacity = 0.42,
    this.illustrationShadowBlur = 10,
  });

  @override
  State<BakuganPreview> createState() => _BakuganPreviewState();
}

class _BakuganPreviewState extends State<BakuganPreview>
    with AutomaticKeepAliveClientMixin {
  bool _showClosedObj = true;

  bool get _uses3DViewer {
    final path = widget.variant.modelPath.toLowerCase();
    return path.endsWith('.glb') || path.endsWith('.gltf');
  }

  bool get _usesObjViewer =>
      widget.variant.modelPath.toLowerCase().endsWith('.obj');

  String get _objPreviewModelPath {
    if (widget.isLarge &&
        _usesObjViewer &&
        _showClosedObj &&
        widget.variant.closedModelPath != null) {
      return widget.variant.closedModelPath!;
    }
    return widget.variant.modelPath;
  }

  double get _pngScale {
    if (widget.isLarge) return 1.12;
    if (widget.isDeck) return 1.08;
    return 1.06;
  }

  double get _illustrationScale {
    if (widget.isLarge) return 1.6;
    if (widget.isDeck) return 0.98;
    return 0.96;
  }

  Alignment get _pngAlignment {
    if (widget.isLarge) return const Alignment(0.04, -0.03);
    if (widget.isDeck) return Alignment.center;
    return const Alignment(0.16, 0.0);
  }

  Alignment get _illustrationAlignment {
    if (widget.isLarge) return const Alignment(0.0, 0.12);
    return Alignment.center;
  }

  EdgeInsets get _pngPadding {
    if (widget.isLarge) return const EdgeInsets.fromLTRB(8, 8, 8, 52);
    return const EdgeInsets.all(8);
  }

  EdgeInsets get _illustrationPadding {
    if (widget.isLarge) return const EdgeInsets.fromLTRB(24, 80, 24, 14);
    return const EdgeInsets.all(12);
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
    _resetOpenCloseState();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant BakuganPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant.modelPath != widget.variant.modelPath ||
        oldWidget.variant.closedModelPath != widget.variant.closedModelPath ||
        oldWidget.variant.texturePath != widget.variant.texturePath ||
        oldWidget.isLarge != widget.isLarge ||
        oldWidget.isDeck != widget.isDeck ||
        oldWidget.theta != widget.theta ||
        oldWidget.phi != widget.phi ||
        oldWidget.autoRotate != widget.autoRotate) {
      _resetOpenCloseState();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _resetOpenCloseState() {
    _showClosedObj = false;
  }

  Future<void> _makeWindowsModelViewTransparent(
    InAppWebViewController controller,
  ) async {
    if (!Platform.isWindows) return;

    try {
      // flutter_inappwebview_windows applies the native alpha only when this
      // setting changes after the WebView2 controller has been created.
      await controller.setSettings(
        settings: InAppWebViewSettings(transparentBackground: false),
      );
      await controller.setSettings(
        settings: InAppWebViewSettings(transparentBackground: true),
      );
    } catch (error) {
      debugPrint('Error enabling transparent GLB background: $error');
    }
  }

  void _toggleOpenClose() {
    if (!widget.isLarge ||
        !_usesObjViewer ||
        widget.variant.closedModelPath == null) {
      return;
    }
    setState(() => _showClosedObj = !_showClosedObj);
  }

  Widget _unskewPreviewContent(Widget child) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(0.15),
      child: child,
    );
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
                    if (widget.frameBackground != null)
                      Positioned.fill(child: widget.frameBackground!),

                    if (widget.showGridBackground)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: GridPainter(
                            color: themeColor.withValues(
                              alpha:
                                  widget.gridOpacityOverride ??
                                  (widget.isLarge ? 0.12 : 0.05),
                            ),
                          ),
                        ),
                      ),

                    Positioned.fill(
                      child: Opacity(
                        opacity: widget.isTaken ? 0.2 : 1.0,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: widget.isLarge ? 65 : 20,
                          ),
                          child: _buildPreviewVisual(),
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

        if (widget.statusLabel != null && widget.isLarge)
          _buildStatusOverlay(widget.statusLabel!),
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
    );
  }

  // --- MODEL & OVERLAY HELPERS ---
  Widget _buildPreviewVisual() {
    final illustrationAssetPath = widget.illustrationAssetPath;
    if (illustrationAssetPath != null) {
      final padding = widget.visualPaddingOverride ?? _illustrationPadding;
      final alignment =
          widget.visualAlignmentOverride ?? _illustrationAlignment;
      final scale = widget.visualScaleOverride ?? _illustrationScale;
      Widget buildIllustration({bool includeKey = false}) {
        return Image.asset(
          illustrationAssetPath,
          key: includeKey
              ? ValueKey(
                  'illustration_${illustrationAssetPath}_${widget.isLarge}',
                )
              : null,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => _buildModel(),
        );
      }

      return IgnorePointer(
        ignoring: true,
        child: Padding(
          padding: padding,
          child: _unskewPreviewContent(
            Align(
              alignment: alignment,
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (widget.showIllustrationShadow)
                      Transform.translate(
                        offset: Offset(
                          widget.illustrationShadowOffset.dx * 0.38,
                          widget.illustrationShadowOffset.dy * 0.42,
                        ),
                        child: Opacity(
                          opacity: (widget.illustrationShadowOpacity + 0.18)
                              .clamp(0.0, 1.0),
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 3.4,
                              sigmaY: 3.4,
                            ),
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Colors.black,
                                BlendMode.srcATop,
                              ),
                              child: buildIllustration(),
                            ),
                          ),
                        ),
                      ),
                    buildIllustration(includeKey: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _buildModel();
  }

  Widget _buildModel({bool isDeck = false}) {
    if (_usesObjViewer) {
      return IgnorePointer(
        ignoring: isDeck || widget.disableInteraction || !widget.isLarge,
        child: _unskewPreviewContent(
          Transform.translate(
            offset: widget.isLarge
                ? Offset(
                    0,
                    _showClosedObj
                        ? _objClosedPreviewOffsetY
                        : _objLargePreviewOffsetY,
                  )
                : Offset(0, _objSmallPreviewOffsetY),
            child: _BakuganObjViewer(
              key: ValueKey(
                'obj_${widget.variant.texturePath}_${widget.isLarge}',
              ),
              modelPath: _objPreviewModelPath,
              texturePath: widget.variant.texturePath,
              cameraDistance: _showClosedObj
                  ? _objClosedCameraDistance
                  : _objCameraDistance,
              enableTouch: widget.isLarge && !widget.disableInteraction,
              autoRotate: widget.isLarge && widget.autoRotate,
              onTap: widget.isLarge ? _toggleOpenClose : null,
            ),
          ),
        ),
      );
    }

    if (!_uses3DViewer) {
      final padding = widget.visualPaddingOverride ?? _pngPadding;
      final alignment = widget.visualAlignmentOverride ?? _pngAlignment;
      final scale = widget.visualScaleOverride ?? _pngScale;
      return IgnorePointer(
        ignoring: true,
        child: Padding(
          padding: padding,
          child: _unskewPreviewContent(
            Align(
              alignment: alignment,
              child: Transform.scale(
                scale: scale,
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
        ),
      );
    }

    return IgnorePointer(
      ignoring: isDeck || widget.disableInteraction || !widget.isLarge,
      child: _unskewPreviewContent(
        model_viewer.ModelViewer(
          key: ValueKey('model_${widget.variant.modelPath}_${widget.isLarge}'),
          src: widget.variant.modelPath,
          cameraOrbit:
              '${widget.theta ?? (widget.isLarge ? 0 : 30)}deg '
              '${widget.phi ?? 75}deg 100%',
          cameraControls: widget.isLarge && !widget.disableInteraction,
          disableTap: true,
          autoRotate: widget.isLarge && widget.autoRotate,
          rotationPerSecond: '15deg',
          interactionPrompt: model_viewer.InteractionPrompt.none,
          activeGestureInterceptor: true,
          backgroundColor: Colors.transparent,
          progressBarColor: Colors.transparent,
          debugLogging: false,
          onWebViewCreated: (controller) =>
              unawaited(_makeWindowsModelViewTransparent(controller)),
        ),
      ),
    );
  }

  Widget _buildStatusOverlay(String label) {
    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          color: Colors.black87,
          child: Text(
            label,
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
  final double spacing;

  GridPainter({required this.color, this.spacing = 20});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const _PressScale({required this.child, this.onPressed});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (mounted && _pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTap: widget.onPressed,
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class BakuganModal extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final IconData? icon;
  final Color accentColor;
  final double width;
  final bool showGridBackground;
  final double gridOpacity;
  final EdgeInsets insetPadding;
  final EdgeInsets contentPadding;
  final bool showCloseButton;

  const BakuganModal({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.icon,
    this.accentColor = Colors.cyanAccent,
    this.width = 760,
    this.showGridBackground = true,
    this.gridOpacity = 0.035,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 32,
      vertical: 24,
    ),
    this.contentPadding = const EdgeInsets.fromLTRB(40, 0, 40, 36),
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: insetPadding,
      child: Transform(
        alignment: Alignment.center,
        transformHitTests: true,
        transform: Matrix4.skewX(-0.12),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accentColor.withValues(alpha: 0.95),
                const Color(0xFF1E8D92),
                const Color(0xFF0B4C53),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.18),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Container(
                  color: const Color(0xFF070C12),
                  child: Stack(
                    children: [
                      if (showGridBackground)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: GridPainter(
                              color: accentColor.withValues(alpha: gridOpacity),
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
                                Colors.white.withValues(alpha: 0.035),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.skewX(0.12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    const Color(
                                      0xFF070C12,
                                    ).withValues(alpha: 0.96),
                                    const Color(
                                      0xFF070C12,
                                    ).withValues(alpha: 0.82),
                                    Colors.transparent,
                                  ],
                                  stops: const [0, 0.58, 1],
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  contentPadding.left + 12,
                                  22,
                                  contentPadding.right,
                                  16,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    if (icon != null) ...[
                                      Baseline(
                                        baseline: 29,
                                        baselineType: TextBaseline.alphabetic,
                                        child: Transform.translate(
                                          offset: const Offset(0, 7),
                                          child: Icon(
                                            icon!,
                                            color: accentColor,
                                            size: 36,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                    ],
                                    Expanded(
                                      child: Text(
                                        title.toUpperCase(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          fontStyle: FontStyle.italic,
                                          letterSpacing: 1.5,
                                          shadows: [
                                            Shadow(
                                              color: accentColor,
                                              blurRadius: 14,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              height: 1.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    accentColor.withValues(alpha: 0.48),
                                    accentColor.withValues(alpha: 0.18),
                                    Colors.transparent,
                                  ],
                                  stops: const [0, 0.38, 1],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                contentPadding.left,
                                20,
                                contentPadding.right,
                                22,
                              ),
                              child: child,
                            ),
                            if (actions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                height: 1.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                    colors: [
                                      accentColor.withValues(alpha: 0.48),
                                      accentColor.withValues(alpha: 0.18),
                                      Colors.transparent,
                                    ],
                                    stops: const [0, 0.38, 1],
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 76,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: FractionallySizedBox(
                                          widthFactor: 0.55,
                                          heightFactor: 1,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerRight,
                                                end: Alignment.centerLeft,
                                                colors: [
                                                  const Color(
                                                    0xFF070C12,
                                                  ).withValues(alpha: 0.94),
                                                  const Color(
                                                    0xFF070C12,
                                                  ).withValues(alpha: 0.58),
                                                  Colors.transparent,
                                                ],
                                                stops: const [0, 0.58, 1],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right: contentPadding.right,
                                          bottom: 8,
                                        ),
                                        child: Wrap(
                                          alignment: WrapAlignment.end,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 14,
                                          runSpacing: 12,
                                          children: actions,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showCloseButton)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: const Offset(3, -3),
                    transformHitTests: true,
                    child: _BakuganModalIconButton(
                      icon: Icons.close_rounded,
                      color: Colors.cyanAccent,
                      backgroundGradient: const LinearGradient(
                        colors: [Colors.cyanAccent, Colors.cyanAccent],
                      ),
                      borderColor: Colors.cyanAccent,
                      iconColor: Colors.black,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.zero,
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(9),
                        bottomRight: Radius.zero,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      skew: 0,
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

enum BakuganButtonSize { s, m, l, xl }

extension BakuganButtonSizeValues on BakuganButtonSize {
  double get defaultWidth {
    switch (this) {
      case BakuganButtonSize.s:
        return 150;
      case BakuganButtonSize.m:
        return 190;
      case BakuganButtonSize.l:
        return 240;
      case BakuganButtonSize.xl:
        return 300;
    }
  }

  double get defaultHeight {
    switch (this) {
      case BakuganButtonSize.s:
        return 44;
      case BakuganButtonSize.m:
        return 58;
      case BakuganButtonSize.l:
        return 72;
      case BakuganButtonSize.xl:
        return 96;
    }
  }

  double get defaultTextFontSize {
    switch (this) {
      case BakuganButtonSize.s:
        return 16;
      case BakuganButtonSize.m:
        return 19;
      case BakuganButtonSize.l:
        return 22;
      case BakuganButtonSize.xl:
        return 25;
    }
  }
}

class BakuganModalActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final IconData? icon;
  final bool useCancelSound;
  final bool showGrid;
  final double gridOpacity;
  final bool useGradientBorder;
  final BakuganButtonSize size;
  final double? width;
  final double? height;
  final double? textFontSize;

  const BakuganModalActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = Colors.cyanAccent,
    this.icon,
    this.useCancelSound = false,
    this.showGrid = true,
    this.gridOpacity = 0.1,
    this.useGradientBorder = true,
    this.size = BakuganButtonSize.m,
    this.width,
    this.height,
    this.textFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final buttonWidth = width ?? size.defaultWidth;
    final buttonHeight = height ?? size.defaultHeight;
    final buttonTextFontSize = textFontSize ?? size.defaultTextFontSize;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-0.12),
      child: _PressScale(
        onPressed: () {
          unawaited(
            useCancelSound ? _playUiCancelSound() : _playUiConfirmSound(),
          );
          onPressed();
        },
        child: Container(
          width: buttonWidth,
          height: buttonHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: useGradientBorder ? null : color.withValues(alpha: 0.72),
            gradient: useGradientBorder
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      color.withValues(alpha: 0.48),
                      Colors.black,
                    ],
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF05080D),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Stack(
                children: [
                  if (showGrid)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GridPainter(
                          color: color.withValues(alpha: gridOpacity),
                          spacing: 13,
                        ),
                      ),
                    ),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.skewX(0.12),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: color, size: 21),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            text.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'button_font',
                              color: Colors.white,
                              fontSize: buttonTextFontSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              shadows: [Shadow(color: color, blurRadius: 10)],
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
    );
  }
}

class _BakuganModalIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final double skew;
  final Gradient? backgroundGradient;
  final Color? borderColor;
  final Color? iconColor;
  final BorderRadius borderRadius;

  const _BakuganModalIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.skew = -0.12,
    this.backgroundGradient,
    this.borderColor,
    this.iconColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(9)),
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transformHitTests: false,
      transform: Matrix4.skewX(skew),
      child: Container(
        width: 48,
        height: 44,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundGradient == null
              ? Colors.black.withValues(alpha: 0.7)
              : null,
          gradient: backgroundGradient,
          borderRadius: borderRadius,
          border: Border.all(
            color: borderColor ?? color.withValues(alpha: 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Transform(
                alignment: Alignment.center,
                transformHitTests: false,
                transform: Matrix4.skewX(0.08),
                child: _PressScale(
                  onPressed: onPressed,
                  child: SizedBox.expand(
                    child: Center(
                      child: Icon(icon, color: iconColor ?? color, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            border: Border.all(color: accentColor, width: 1.8),
          ),
          child: Icon(Icons.restart_alt_rounded, color: accentColor, size: 18),
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
                                      color: accentColor.withValues(
                                        alpha: 0.30,
                                      ),
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
  final bool useCancelSound;
  final double textFontSize;
  final double iconSize;

  const BakuganButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width = 250,
    this.height = 65,
    this.color,
    this.icon,
    this.iconOnly = false,
    this.useCancelSound = false,
    this.textFontSize = 30,
    this.iconSize = 28,
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
            unawaited(
              widget.useCancelSound
                  ? _playUiCancelSound()
                  : _playUiConfirmSound(),
            );
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
                        ? Icon(
                            widget.icon,
                            size: widget.iconSize,
                            color: Colors.white,
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.icon,
                                size: widget.iconSize,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                widget.text,
                                style: TextStyle(
                                  fontFamily: 'button_font',
                                  color: Colors.white,
                                  fontSize: widget.textFontSize,
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
                        fontSize: widget.textFontSize,
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
  final Set<int> selectedBakuganIndices;
  final Function(int)? onBakuganTap;
  final Function(int)? onBakuganLongPress;
  final List<MatchBakuganPileState>? bakuganPileStates;
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
    this.selectedBakuganIndices = const {},
    this.onBakuganTap,
    this.onBakuganLongPress,
    this.bakuganPileStates,
    this.isSelecting = false,
    this.isExpanded = false,
    this.onPortraitTap,
    this.portraitOverlay,
    this.portraitOverlayAbove = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSelectedBakuganIndices = <int>{
      ...selectedBakuganIndices,
      ...[selectedBakuganIndex].whereType<int>(),
    };
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
    final List<Color> standingGradient = [
      const Color(0xFF7BE6C2),
      const Color(0xFFD9F59A),
      const Color(0xFF2B7F6A),
    ];
    final List<Color> usedGradient = [
      const Color(0xFF565C68),
      const Color(0xFF2E3138),
      const Color(0xFF15171B),
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
          if (isSelecting && effectiveSelectedBakuganIndices.isEmpty)
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
              final isPicked = effectiveSelectedBakuganIndices.contains(i);
              final pileState =
                  bakuganPileStates != null && i < bakuganPileStates!.length
                  ? bakuganPileStates![i]
                  : MatchBakuganPileState.unused;
              final isStanding = pileState == MatchBakuganPileState.standing;
              final isUsed = pileState == MatchBakuganPileState.used;
              final isRemoved = pileState == MatchBakuganPileState.removed;
              final borderGradient = isPicked
                  ? activeGradient
                  : isStanding
                  ? standingGradient
                  : isRemoved
                  ? const [
                      Color(0xFF2A0E0E),
                      Color(0xFF111111),
                      Color(0xFF050505),
                    ]
                  : isUsed
                  ? usedGradient
                  : idleGradient;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.skewX(-0.15),
                child: GestureDetector(
                  onTap: hasBakugan && !isRemoved
                      ? () => onBakuganTap?.call(i)
                      : null,
                  onLongPress: hasBakugan && !isRemoved
                      ? () => onBakuganLongPress?.call(i)
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: isUsed ? 0.48 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: slotSize,
                      height: slotSize,
                      margin: EdgeInsets.only(
                        right: isMirrored ? 0 : slotGap,
                        left: isMirrored ? slotGap : 0,
                      ),
                      padding: EdgeInsets.all(isPicked || isStanding ? 4 : 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: borderGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: borderGradient.first.withValues(
                              alpha: isPicked || isStanding ? 0.58 : 0.34,
                            ),
                            blurRadius: isPicked || isStanding
                                ? 15
                                : (isUsed ? 4 : 8),
                            spreadRadius: isPicked || isStanding
                                ? 2
                                : (isUsed ? 0 : 1),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Stack(
                          children: [
                            if (hasBakugan && !isRemoved)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: BakuganPreview(
                                    variant: variant!,
                                    isDeck: true,
                                  ),
                                ),
                              ),
                            if (isRemoved)
                              Positioned.fill(
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.skewX(0.15),
                                  child: Center(
                                    child: Text(
                                      'OUT',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.32,
                                        ),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        fontStyle: FontStyle.italic,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
      crossAxisAlignment: isMirrored
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
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

class BattleResultShowcase extends StatelessWidget {
  final String title;
  final Widget previewChild;
  final VoidCallback? onTap;
  final double previewWidth;
  final double previewHeight;

  const BattleResultShowcase({
    super.key,
    required this.title,
    required this.previewChild,
    this.onTap,
    this.previewWidth = 560,
    this.previewHeight = 560,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<Offset>(
              tween: Tween<Offset>(
                begin: const Offset(-1.2, 0),
                end: Offset.zero,
              ),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, offset, child) {
                return Transform.translate(
                  offset: Offset(offset.dx * 480, 0),
                  child: child,
                );
              },
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 2,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(4, 4),
                      blurRadius: 10,
                    ),
                    Shadow(color: Colors.white24, blurRadius: 28),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: previewWidth,
              height: previewHeight,
              child: previewChild,
            ),
          ],
        ),
      ),
    );
  }
}
