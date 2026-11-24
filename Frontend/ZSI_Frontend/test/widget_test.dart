import 'dart:math';
import 'dart:io';

import 'package:fish_id_india/core/services/archive_service.dart';
import 'package:fish_id_india/core/services/identification_service.dart';
import 'package:fish_id_india/core/services/species_lookup_service.dart';
import 'package:fish_id_india/core/theme/app_theme.dart';
import 'package:fish_id_india/shared/models/index.dart';
import 'package:fish_id_india/widgets/wild_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  // Tests must not try to download fonts.
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Species data', () {
    final species = SpeciesLookupService.parse(
      File('assets/species_data.json').readAsStringSync(),
    );
    final mapping = File('assets/ml/zsi_class_mapping.json').readAsStringSync();

    setUp(() => SpeciesLookupService.useSpecies(species));

    test('every species has a schedule from the ZSI dataset', () {
      expect(species, hasLength(65));
      expect(species.where((a) => a.schedule == null), isEmpty);
      expect(species.where((a) => a.schedule == 1), hasLength(18));
    });

    test('every model label resolves to a species', () {
      final labels = RegExp(r'"common_name":\s*"([^"]+)"')
          .allMatches(mapping)
          .map((m) => m.group(1)!)
          .toList();
      expect(labels, hasLength(66));
      final unresolved = labels.where((l) => SpeciesLookupService.lookupLoaded(l) == null).toList();
      expect(unresolved, isEmpty, reason: 'labels with no species info: $unresolved');
    });

    test('no species is listed twice', () {
      String n(String s) => SpeciesLookupService.normalize(s);
      final names = species.map((a) => n(a.name)).toList();
      final scientific = species.map((a) => n(a.scientificName)).toList();
      expect(names.toSet(), hasLength(names.length), reason: 'duplicate common name');
      expect(scientific.toSet(), hasLength(scientific.length), reason: 'duplicate scientific name');
    });

    test('old and misspelt model labels resolve to the corrected entry', () {
      String? name(String label) => SpeciesLookupService.lookupLoaded(label)?.name;
      expect(name('Variegated Eagle Ray'), 'Stripenose Guitarfish');
      expect(name('Glucostegus typus'), 'Giant Shovelnose Ray');
      expect(name('Mobula kuhli'), 'Shortfin Devil Ray');
      // The duplicate oceanic whitetip entry was merged into one.
      expect(name('Carcharhinus longimanus'), 'Oceanic Whitetip Shark');
      expect(name('Oceanic Whitetip Shark'), 'Oceanic Whitetip Shark');
      // "Spotted Guitarfish" means only the real one.
      expect(SpeciesLookupService.lookupLoaded('Spotted Guitarfish')?.scientificName,
          'Rhinobatos punctifer');
    });

    test('scientific-name labels map to the common name', () {
      expect(SpeciesLookupService.lookupLoaded('Prionace glauca')?.name, 'Blue Shark');
      expect(SpeciesLookupService.lookupLoaded('  whale SHARK ')?.schedule, 1);
    });
  });

  group('IdentificationService.clean', () {
    test('drops placeholders, keeps best per label, ranks and caps', () {
      final cleaned = IdentificationService.clean([
        IdentificationResult(label: 'Image Not Recognized', confidence: 0.0),
        IdentificationResult(label: 'Whale Shark', confidence: 0.4),
        IdentificationResult(label: 'whale shark', confidence: 0.7),
        IdentificationResult(label: 'Bull Ray', confidence: 0.1),
        IdentificationResult(label: 'Porcupine Ray', confidence: 0.2),
        IdentificationResult(label: 'Giant Grouper', confidence: 0.05),
      ]);
      expect(cleaned.map((r) => r.label), ['whale shark', 'Porcupine Ray', 'Bull Ray']);
      expect(cleaned.first.confidence, 0.7);
    });

    test('nothing usable means not recognised', () {
      expect(
        IdentificationService.clean([IdentificationResult(label: 'Unknown', confidence: 0.9)]),
        isEmpty,
      );
    });
  });

  group('CSV export', () {
    test('quotes commas, quotes and newlines', () {
      expect(ArchiveService.csvField('plain'), 'plain');
      expect(ArchiveService.csvField('a,b'), '"a,b"');
      expect(ArchiveService.csvField('say "hi"'), '"say ""hi"""');
      expect(ArchiveService.csvField('two\nlines'), '"two\nlines"');
      expect(ArchiveService.csvField(null), '');
    });
  });

  group('Theme', () {
    test('dark tokens are a real dark scheme, not a copy of light', () {
      expect(WildColors.dark.ground.computeLuminance(), lessThan(0.05));
      expect(WildColors.light.ground.computeLuminance(), greaterThan(0.8));
      // Body text stays readable on its ground in both themes.
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
      }
      expect(contrast(WildColors.light.ink, WildColors.light.ground), greaterThan(4.5));
      expect(contrast(WildColors.dark.ink, WildColors.dark.ground), greaterThan(4.5));
      expect(contrast(WildColors.light.muted, WildColors.light.card), greaterThan(4.5));
      expect(contrast(WildColors.dark.muted, WildColors.dark.card), greaterThan(4.5));
      for (final s in ProtectionStatus.values) {
        expect(contrast(s.onColor, s.color), greaterThan(4.5), reason: '$s band text');
      }
    });

    test('schedules map to statuses', () {
      expect(ProtectionStatusX.fromSchedule(1), ProtectionStatus.scheduleI);
      expect(ProtectionStatusX.fromSchedule(2), ProtectionStatus.scheduleII);
      expect(ProtectionStatusX.fromSchedule(null), ProtectionStatus.notListed);
    });

    testWidgets('StatusTag shows the short label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StatusTag(ProtectionStatus.scheduleI)),
      ));
      // The bundled Anek Latin loads asynchronously; let it finish.
      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pumpAndSettle();
      expect(find.text('SCH. I'), findsOneWidget);
    });
  });

  group('friendlyTime', () {
    final now = DateTime(2026, 11, 15, 12);
    test('recent, yesterday and older dates', () {
      expect(friendlyTime(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(friendlyTime(now.subtract(const Duration(hours: 2)), now: now), '2 h ago');
      expect(friendlyTime(DateTime(2026, 11, 14, 20), now: now), 'Yesterday');
      expect(friendlyTime(DateTime(2026, 11, 2), now: now), '2 Nov');
      expect(friendlyTime(DateTime(2025, 3, 9), now: now), '9 Mar 2025');
    });
  });
}
