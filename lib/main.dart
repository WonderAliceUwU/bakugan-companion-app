// ignore_for_file: unnecessary_library_name

library bakugan_companion;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

part 'app/app.dart';
part 'core/data/models.dart';
part 'core/data/cards.dart';
part 'features/menu/menu_screens.dart';
part 'features/selection/character_select_screen.dart';
part 'features/selection/bakugan_select_screen.dart';
part 'features/shared/shared_widgets.dart';
part 'features/match/scoreboard_screen.dart';
part 'features/match/battle_arena_screen.dart';

final AudioPlayer _bgMusicPlayer = AudioPlayer();
final AudioPlayer _battleMusicPlayer = AudioPlayer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _bgMusicPlayer.stop();
  } catch (_) {}
  runApp(const BakuganApp());
}
