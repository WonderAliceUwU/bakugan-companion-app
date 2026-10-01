part of '../../main.dart';

enum AppLanguage { es, en }

extension AppLanguageX on AppLanguage {
  String get code => name;

  String get label {
    switch (this) {
      case AppLanguage.es:
        return 'Español';
      case AppLanguage.en:
        return 'English';
    }
  }
}

class LanguageFlag extends StatelessWidget {
  final AppLanguage language;

  const LanguageFlag({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 20,
      child: CustomPaint(painter: _LanguageFlagPainter(language)),
    );
  }
}

class _LanguageFlagPainter extends CustomPainter {
  final AppLanguage language;

  const _LanguageFlagPainter(this.language);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(bounds, const Radius.circular(3)));

    if (language == AppLanguage.es) {
      final paint = Paint()..color = const Color(0xFFC60B1E);
      canvas.drawRect(bounds, paint);
      paint.color = const Color(0xFFFFC400);
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.25, size.width, size.height * 0.5),
        paint,
      );
    } else {
      final paint = Paint()..color = const Color(0xFF012169);
      canvas.drawRect(bounds, paint);

      _drawLine(canvas, size, Colors.white, size.height * 0.34, true);
      _drawLine(canvas, size, Colors.white, size.height * 0.34, false);
      _drawDiagonal(canvas, size, Colors.white, size.height * 0.28);
      _drawLine(
        canvas,
        size,
        const Color(0xFFC8102E),
        size.height * 0.16,
        true,
      );
      _drawLine(
        canvas,
        size,
        const Color(0xFFC8102E),
        size.height * 0.16,
        false,
      );
      _drawDiagonal(canvas, size, const Color(0xFFC8102E), size.height * 0.12);
    }

    canvas.restore();
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    Color color,
    double strokeWidth,
    bool horizontal,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final center = horizontal ? size.height / 2 : size.width / 2;
    if (horizontal) {
      canvas.drawLine(Offset(0, center), Offset(size.width, center), paint);
    } else {
      canvas.drawLine(Offset(center, 0), Offset(center, size.height), paint);
    }
  }

  void _drawDiagonal(
    Canvas canvas,
    Size size,
    Color color,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _LanguageFlagPainter oldDelegate) {
    return oldDelegate.language != language;
  }
}

class LanguageController extends ChangeNotifier {
  static final LanguageController instance = LanguageController._();
  LanguageController._();

  AppLanguage _uiLanguage = AppLanguage.en;
  AppLanguage _cardLanguage = AppLanguage.en;

  AppLanguage get uiLanguage => _uiLanguage;
  AppLanguage get cardLanguage => _cardLanguage;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final file = await _settingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final data = jsonDecode(content);
          if (data is Map) {
            final ui = data['uiLanguage']?.toString();
            final card = data['cardLanguage']?.toString();
            if (ui == 'en') _uiLanguage = AppLanguage.en;
            if (ui == 'es') _uiLanguage = AppLanguage.es;
            if (card == 'en') _cardLanguage = AppLanguage.en;
            if (card == 'es') _cardLanguage = AppLanguage.es;
          }
        }
      }
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  Future<File> _settingsFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/bakugan_language_settings.json');
  }

  Future<void> setUiLanguage(AppLanguage lang) async {
    if (_uiLanguage == lang) return;
    _uiLanguage = lang;
    notifyListeners();
    await _save();
  }

  Future<void> setCardLanguage(AppLanguage lang) async {
    if (_cardLanguage == lang) return;
    _cardLanguage = lang;
    notifyListeners();
    await _save();
  }

  Future<void> setLanguages({
    required AppLanguage ui,
    required AppLanguage card,
  }) async {
    if (_uiLanguage == ui && _cardLanguage == card) return;
    _uiLanguage = ui;
    _cardLanguage = card;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final file = await _settingsFile();
      await file.writeAsString(
        jsonEncode({
          'uiLanguage': _uiLanguage.code,
          'cardLanguage': _cardLanguage.code,
        }),
      );
    } catch (_) {}
  }
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    return scope?.notifier ?? LanguageController.instance;
  }
}

class AppLocalizations {
  final AppLanguage language;

  const AppLocalizations(this.language);

  static AppLocalizations of(BuildContext context) {
    final controller = LanguageScope.of(context);
    return AppLocalizations(controller.uiLanguage);
  }

  static AppLocalizations get current =>
      AppLocalizations(LanguageController.instance.uiLanguage);

  bool get isEs => language == AppLanguage.es;

  // --- COMMON / DIALOGS / BUTTONS ---
  String get ok => 'OK';
  String get cancel => isEs ? 'CANCELAR' : 'CANCEL';
  String get confirm => isEs ? 'CONFIRMAR' : 'CONFIRM';
  String get save => isEs ? 'GUARDAR' : 'SAVE';
  String get close => isEs ? 'CERRAR' : 'CLOSE';
  String get explore => isEs ? 'EXPLORAR' : 'EXPLORE';
  String get back => isEs ? 'VOLVER' : 'BACK';
  String get edit => isEs ? 'EDITAR' : 'EDIT';
  String get done => isEs ? 'HECHO' : 'DONE';

  // --- HOME / MENU ---
  String get battle => isEs ? 'BATALLA' : 'BATTLE';
  String get leaderboard => isEs ? 'CLASIFICACIÓN' : 'LEADERBOARD';
  String get history => isEs ? 'HISTORIAL' : 'HISTORY';
  String get inventory => isEs ? 'INVENTARIO' : 'INVENTORY';
  String get backupImport => isEs ? 'COPIA / IMPORTAR' : 'BACKUP / IMPORT';
  String get languageSettingsTitle =>
      isEs ? 'CONFIGURACIÓN DE IDIOMA' : 'LANGUAGE SETTINGS';
  String get uiLanguageLabel => isEs ? 'Idioma de la UI' : 'UI Language';
  String get cardLanguageLabel =>
      isEs ? 'Idioma de las Cartas' : 'Card Text Language';
  String get exportBackup => isEs ? 'EXPORTAR COPIA' : 'EXPORT BACKUP';
  String get importBackup => isEs ? 'IMPORTAR COPIA' : 'IMPORT BACKUP';
  String get backupDescription => isEs
      ? 'Elige si deseas exportar el estado completo de la app o restaurar la app desde una copia JSON.'
      : 'Choose whether to export the current full app state or restore the entire app from a backup JSON.';
  String get exportDialogSubtitle => isEs
      ? 'Exporta todo el estado de la app a un archivo JSON, incluyendo jugadores, temporadas e historial.'
      : 'This exports the full app state to a JSON backup, including saved players, leaderboard seasons, and match history.';
  String get importDialogSubtitle => isEs
      ? 'Importar restaura todo el estado de la app desde la copia JSON seleccionada.'
      : 'Importing restores the full app state from the selected JSON backup and replaces current data.';

  // --- BATTLE MODE SELECTION ---
  String get selectBattleMode =>
      isEs ? 'SELECCIONAR MODO' : 'SELECT BATTLE MODE';
  String get duel1vs1 => isEs ? '1 VS 1' : '1 VS 1';
  String get duel1vs1Sub =>
      isEs ? '2 Jugadores • Duelo clásico' : '2 Players • Classic duel';
  String get teamBattle => isEs ? 'MODO EQUIPOS' : 'TEAM BATTLE';
  String get teamBattleSub =>
      isEs ? '4 Jugadores • Batalla en equipos' : '4 Players • Team battle';

  // --- CHARACTER / PLAYER SELECTION ---
  String get selectCharacter =>
      isEs ? 'SELECCIONAR PERSONAJE' : 'SELECT CHARACTER';
  String get invite => isEs ? 'INVITAR' : 'INVITE';
  String get register => isEs ? 'REGISTRAR' : 'REGISTER';
  String get temporaryPlayer => isEs ? 'Jugador temporal' : 'Temporary player';
  String get savePlayer => isEs ? 'Guardar jugador' : 'Save a player';
  String get registerPlayerTitle =>
      isEs ? 'REGISTRAR JUGADOR' : 'REGISTER PLAYER';
  String get invitePlayerTitle => isEs ? 'INVITAR JUGADOR' : 'INVITE PLAYER';
  String get registerPlayerSub => isEs
      ? 'Elige una foto de perfil de Bakugan y guarda este jugador para más tarde.'
      : 'Choose a Bakugan profile photo and save this player for later.';
  String get invitePlayerSub => isEs
      ? 'Elige una foto de perfil de Bakugan para este jugador invitado temporal.'
      : 'Choose a Bakugan profile photo for this temporary invited player.';
  String get playerNameHint => isEs ? 'Nombre del jugador' : 'Player name';
  String get selecting => isEs ? 'Seleccionando...' : 'Selecting...';
  String get selectProfileMsg => isEs
      ? 'Selecciona, invita o registra un jugador primero.'
      : 'Select, invite, or register a player first.';
  String get slotNeedsProfileMsg => isEs
      ? 'Cada casilla necesita un perfil seleccionado.'
      : 'Every player slot needs a selected profile.';
  String get uniqueNamesMsg => isEs
      ? 'Los nombres de los jugadores deben ser únicos.'
      : 'Player names must be unique.';
  String enterNameMsg() =>
      isEs ? 'Introduce un nombre de jugador.' : 'Enter a player name.';
  String playerRegisteredMsg(String name) =>
      isEs ? '$name registrado.' : '$name registered.';
  String playerInvitedMsg(String name) => isEs
      ? '$name invitado para esta partida.'
      : '$name invited for this match.';

  // --- BAKUGAN SELECTION ---
  String get selectBakugan => isEs ? 'SELECCIONAR BAKUGAN' : 'SELECT BAKUGAN';
  String get clearAll => isEs ? 'LIMPIAR TODO' : 'CLEAR ALL';
  String get autoFill => isEs ? 'AUTO COMPLETAR' : 'AUTO FILL';
  String get startBattle => isEs ? 'INICIAR BATALLA' : 'START BATTLE';
  String get mustSelectBakugansMsg => isEs
      ? 'Cada jugador debe seleccionar exactamente 3 Bakugan.'
      : 'Each player must select exactly 3 Bakugans.';

  // --- LEADERBOARD ---
  String get leaderboardTitle =>
      isEs ? 'TABLA DE CLASIFICACIÓN' : 'LEADERBOARD';
  String get season => isEs ? 'TEMPORADA' : 'SEASON';
  String get currentSeason => isEs ? 'TEMPORADA ACTUAL' : 'CURRENT SEASON';
  String get archivedSeasons =>
      isEs ? 'TEMPORADAS ARCHIVADAS' : 'ARCHIVED SEASONS';
  String get newSeason => isEs ? 'NUEVA TEMPORADA' : 'NEW SEASON';
  String get playerHeader => isEs ? 'JUGADOR' : 'PLAYER';
  String get pointsHeader => isEs ? 'PUNTOS' : 'POINTS';
  String get winsHeader => isEs ? 'VICTORIAS' : 'WINS';
  String get matchesHeader => isEs ? 'PARTIDAS' : 'MATCHES';
  String get gateCardsHeader => isEs ? 'CARTAS PORTAL' : 'GATE CARDS';
  String get noPlayers =>
      isEs ? 'No hay jugadores registrados' : 'No registered players';
  String get deletePlayerTitle => isEs ? 'ELIMINAR JUGADOR' : 'DELETE PLAYER';
  String get deletePlayerConfirm => isEs
      ? '¿Estás seguro de que deseas eliminar este jugador?'
      : 'Are you sure you want to delete this player?';

  // --- MATCH HISTORY ---
  String get matchHistoryTitle =>
      isEs ? 'HISTORIAL DE PARTIDAS' : 'MATCH HISTORY';
  String get noHistory =>
      isEs ? 'Sin partidas registradas' : 'No matches recorded';
  String get winner => isEs ? 'GANADOR' : 'WINNER';
  String get team => isEs ? 'EQUIPO' : 'TEAM';
  String get battles => isEs ? 'BATALLAS' : 'BATTLES';
  String get playedAt => isEs ? 'Jugado el' : 'Played at';
  String get viewBattleDetails =>
      isEs ? 'VER DETALLES DE BATALLAS' : 'VIEW BATTLE DETAILS';

  // --- CARD INVENTORY ---
  String get cardInventoryTitle =>
      isEs ? 'INVENTARIO DE CARTAS' : 'CARD INVENTORY';
  String get allCards => isEs ? 'TODAS' : 'ALL';
  String get gateCards => isEs ? 'CARTAS PORTAL' : 'GATE CARDS';
  String get abilityCards => isEs ? 'CARTAS DE HABILIDAD' : 'ABILITY CARDS';
  String get searchCardsHint => isEs ? 'Buscar cartas...' : 'Search cards...';
  String get noCardsFound =>
      isEs ? 'No se encontraron cartas' : 'No cards found';

  // --- SCOREBOARD / BATTLE ARENA ---
  String get round => isEs ? 'RONDA' : 'ROUND';
  String get battleHeader => isEs ? 'BATALLA' : 'BATTLE';
  String get totalGPower => isEs ? 'G-POWER TOTAL' : 'TOTAL G-POWER';
  String get printedGPower => isEs ? 'G-POWER IMPRESO' : 'PRINTED G-POWER';
  String get gateCard => isEs ? 'CARTA PORTAL' : 'GATE CARD';
  String get abilities => isEs ? 'HABILIDADES' : 'ABILITIES';
  String get revealGateCard =>
      isEs ? 'REVELAR CARTA PORTAL' : 'REVELAR GATE CARD';
  String get useAbility => isEs ? 'USAR HABILIDAD' : 'USE ABILITY';
  String get selectGateCardTitle =>
      isEs ? 'SELECCIONAR CARTA PORTAL' : 'SELECT GATE CARD';
  String get selectAbilityCardTitle =>
      isEs ? 'SELECCIONAR CARTA DE HABILIDAD' : 'SELECT ABILITY CARD';
  String get searchCardNameHint =>
      isEs ? 'Escribe el nombre de la carta...' : 'Type card name...';
  String get winnerIs => isEs ? '¡GANADOR:' : 'WINNER:';
  String get drawMatch => isEs ? '¡EMPATE!' : 'DRAW!';
  String get endMatch => isEs ? 'FINALIZAR PARTIDA' : 'END MATCH';
  String get nextBattle => isEs ? 'SIGUIENTE BATALLA' : 'NEXT BATTLE';
  String get activeGlobalGates =>
      isEs ? 'Efectos Globales Activos' : 'Active Global Effects';
  String get externalAbilities =>
      isEs ? 'Habilidades Externas' : 'External Abilities';
  String get forbidAbilities =>
      isEs ? 'Habilidades Prohibidas' : 'Abilities Forbidden';
  String get noDescription =>
      isEs ? 'Sin descripción disponible.' : 'No description available.';
  String get untranslatedNote => isEs
      ? 'Nota: Los nombres de Bakugan y los atributos (Pyrus, Aquos, Subterra, Haos, Darkus, Ventus) no se traducen.'
      : 'Note: Bakugan names and attributes (Pyrus, Aquos, Subterra, Haos, Darkus, Ventus) remain untranslated.';
}
