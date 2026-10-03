// ignore_for_file: unnecessary_library_name

library bakugan_companion;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_3d_controller/src/core/modules/obj_viewer/mesh.dart'
    as obj_mesh;
import 'package:flutter_3d_controller/src/core/modules/obj_viewer/obj_viewer.dart'
    as obj_viewer;
import 'package:flutter_3d_controller/src/core/modules/obj_viewer/object.dart'
    as obj_object;
import 'package:flutter_3d_controller/src/core/modules/obj_viewer/scene.dart'
    as obj_scene;
import 'package:flutter_3d_controller/src/core/modules/model_viewer/model_viewer.dart'
    as model_viewer;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

part 'app/app.dart';
part 'core/localization/language_settings.dart';
part 'core/data/models.dart';
part 'core/data/cards.dart';
part 'features/menu/menu_screens.dart';
part 'features/inventory/inventory_screen.dart';
part 'features/selection/character_select_screen.dart';
part 'features/selection/bakugan_select_screen.dart';
part 'features/shared/shared_widgets.dart';
part 'features/match/scoreboard_screen.dart';
part 'features/match/battle_arena_screen.dart';

final AudioPlayer _bgMusicPlayer = AudioPlayer();
final AudioPlayer _battleMusicPlayer = AudioPlayer();
final AudioPlayer _uiConfirmPlayer = AudioPlayer();
final AudioPlayer _uiCancelPlayer = AudioPlayer();

Future<void> _playUiConfirmSound() async {
  try {
    await _uiConfirmPlayer.stop();
    await _uiConfirmPlayer.play(AssetSource('sound/select.wav'));
  } catch (_) {}
}

Future<void> _setAppPlayerBaseVolume(
  AudioPlayer player,
  double baseVolume,
) async {
  await AppVolumeController.instance.setBaseVolume(player, baseVolume);
}

Future<void> _setAppVideoBaseVolume(
  VideoPlayerController player,
  double baseVolume,
) async {
  await AppVolumeController.instance.setVideoBaseVolume(player, baseVolume);
}

Future<void> _playUiCancelSound() async {
  try {
    await _uiCancelPlayer.stop();
    await _uiCancelPlayer.play(AssetSource('sound/cancel.wav'));
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    fvp.registerWith(
      options: {
        'platforms': ['windows'],
      },
    );
  }
  AppVolumeController.instance.register(_bgMusicPlayer);
  AppVolumeController.instance.register(_uiConfirmPlayer);
  AppVolumeController.instance.register(_uiCancelPlayer);
  try {
    await _bgMusicPlayer.stop();
  } catch (_) {}
  await LanguageController.instance.init();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const BakuganApp());
}
