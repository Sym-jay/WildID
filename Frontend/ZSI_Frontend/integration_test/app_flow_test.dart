// Native end-to-end test on an Android emulator or phone (Patrol).
//
//   patrol test -t integration_test/app_flow_test.dart --dart-define=ZSI_DEMO=true
//
// Covers what the browser tests cannot: the Android location permission
// dialog, GPS, the SQLite database and photo files on the device.
// The photo is supplied through the image picker's platform interface; the
// camera app's own UI differs per device and is not driven here.

import 'dart:io';

import 'package:fish_id_india/app.dart';
import 'package:fish_id_india/core/services/archive_service.dart';
import 'package:fish_id_india/main.dart' as entry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';

class _FixturePicker extends ImagePickerPlatform {
  _FixturePicker(this.path);

  final String path;
  int picks = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    picks++;
    return XFile(path);
  }
}

Future<String> _fixturePhoto() async {
  final data = await rootBundle.load('assets/species_images/sphyrna_lewini.jpg');
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/fixture_photo.jpg');
  await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  return file.path;
}

void main() {
  patrolTest(
    'identify, add details, survive a restart, and verify a report',
    ($) async {
      await entry.bootstrap(forceSemantics: false);
      final picker = _FixturePicker(await _fixturePhoto());
      ImagePickerPlatform.instance = picker;

      await $.pumpWidgetAndSettle(const ProviderScope(child: FishIDIndiaApp()));

      // Sign-in screen -> guest.
      await $('Continue as guest').tap();
      await $('IS IT\nPROTECTED?').waitUntilVisible();
      expect($('No reports yet'), findsOneWidget);

      // Identify: the app asks for location while checking the photo.
      await $('Take photo').tap();
      expect(picker.picks, 1);
      if (await $.platform.mobile.isPermissionDialogVisible(
        timeout: const Duration(seconds: 15),
      )) {
        await $.platform.mobile.grantPermissionWhenInUse();
      }
      await $('PROTECTED.\nDO NOT KEEP.').waitUntilVisible(timeout: const Duration(seconds: 40));
      expect($('Reef Manta Ray'), findsWidgets);
      expect($('Giant Devil Ray'), findsOneWidget); // scientific label resolved
      // GPS fix from the emulator, formatted like "37.42° N, 122.08° W".
      expect(find.textContaining('°'), findsOneWidget);

      // Report details update the same record.
      await $('Add details for ZSI').tap();
      await $('Fish landing centre').tap();
      await $('Alive').tap();
      await $('Save details').tap();
      await $('Edit report details').waitUntilVisible();
      await $(find.byTooltip('Back')).tap();

      // Cold-start the data layer: everything must come back from SQLite.
      await ArchiveService.reloadFromStorageForTest();
      final saved = ArchiveService.getUploadHistory();
      expect(saved, hasLength(1));
      final record = saved.single;
      expect(record.identifiedSpecies, 'Reef Manta Ray');
      expect(record.habitatType, 'Fish landing centre');
      expect(record.behaviors, startsWith('Condition: Alive.'));
      expect(record.location?.latitude, isNotNull);
      expect(record.imagePath, contains('sightings'));
      expect(File(record.imagePath).existsSync(), isTrue,
          reason: 'photo copied out of the picker cache');

      // The rebuilt UI shows the restored report.
      await $.pumpWidgetAndSettle(
        ProviderScope(key: UniqueKey(), child: const FishIDIndiaApp()),
      );
      await $('Continue as guest').tap();
      await $('History').tap();
      await $('Reef Manta Ray').waitUntilVisible();
      expect(find.textContaining('Fish landing centre'), findsOneWidget);

      // Expert review marks it verified, and that is saved too.
      await $('Profile').tap();
      await $('Expert review queue').tap();
      await $('Reef Manta Ray').tap();
      await $('Confirm species').scrollTo().tap();
      await $('Nothing to review').waitUntilVisible();

      await ArchiveService.reloadFromStorageForTest();
      expect(ArchiveService.getUploadHistory().single.status, 'verified');
    },
  );
}
