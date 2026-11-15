import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../core/services/archive_service.dart';
import '../core/services/location_service.dart';
import '../core/services/species_lookup_service.dart';
import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';
import '../widgets/wild_widgets.dart';
import 'home_screen.dart' show SightingRow, speciesNameForRecord, statusForRecord;
import 'metadata_form_screen.dart';
import 'species_detail_screen.dart';

enum _HistoryFilter { all, protected, review, verified }

/// History tab: every saved sighting.
class UploadHistoryScreen extends StatefulWidget {
  const UploadHistoryScreen({super.key});

  @override
  State<UploadHistoryScreen> createState() => _UploadHistoryScreenState();
}

class _UploadHistoryScreenState extends State<UploadHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    SpeciesLookupService.loadSpecies().then((_) {
      if (mounted) setState(() {});
    });
  }

  bool _matches(UploadRecord r) => switch (_filter) {
        _HistoryFilter.all => true,
        _HistoryFilter.protected => switch (statusForRecord(r)) {
            ProtectionStatus.scheduleI || ProtectionStatus.scheduleII => true,
            _ => false,
          },
        _HistoryFilter.review => r.needsVerification && r.status == 'pending',
        _HistoryFilter.verified => r.status == 'verified',
      };

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    if (ArchiveService.getUploadHistory().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to export yet.')));
      return;
    }
    try {
      final csv = await ArchiveService.exportToCSV();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      await Share.shareXFiles(
        [
          XFile.fromData(
            utf8.encode(csv),
            mimeType: 'text/csv',
            name: 'wildid-sightings-$stamp.csv',
          ),
        ],
        subject: 'WildID sightings $stamp',
      );
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not export. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your reports'),
        actions: [
          IconButton(
            tooltip: 'Export as CSV',
            onPressed: _export,
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: ArchiveService.changes,
        builder: (context, _, __) {
          final all = ArchiveService.getUploadHistory();
          final shown = all.where(_matches).toList();
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (f, label) in const [
                        (_HistoryFilter.all, 'All'),
                        (_HistoryFilter.protected, 'Protected'),
                        (_HistoryFilter.review, 'Needs review'),
                        (_HistoryFilter.verified, 'Verified'),
                      ])
                        ChoiceChip(
                          label: Text(f == _HistoryFilter.all ? '$label ${all.length}' : label),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ),
              ),
              if (shown.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.history,
                    title: all.isEmpty ? 'No reports yet' : 'Nothing here',
                    message: all.isEmpty
                        ? 'Take a photo on the Identify tab. Every check is saved here.'
                        : 'No reports match this filter.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: DecoratedSliver(
                    decoration: BoxDecoration(color: wild.card, borderRadius: BorderRadius.circular(16)),
                    sliver: SliverList.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const Divider(indent: 78),
                      itemBuilder: (context, i) => SightingRow(
                        record: shown[i],
                        onTap: () => showSightingSheet(context, shown[i].id),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Bottom sheet with one sighting's details and actions.
Future<void> showSightingSheet(BuildContext context, String recordId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SightingSheet(recordId: recordId),
  );
}

class _SightingSheet extends StatelessWidget {
  const _SightingSheet({required this.recordId});

  final String recordId;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('The photo and details are removed from this phone. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await ArchiveService.deleteRecord(recordId);
    messenger.showSnackBar(const SnackBar(content: Text('Report deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: ArchiveService.changes,
      builder: (context, _, __) {
        final record = ArchiveService.getById(recordId);
        if (record == null) return const SizedBox(height: 120);
        final status = statusForRecord(record);
        final label = record.verifiedSpecies ?? record.identifiedSpecies;
        final animal = label == null ? null : SpeciesLookupService.lookupLoaded(label);
        final loc = MaterialLocalizations.of(context);
        final when = record.observationDateTime ?? record.timestamp;

        final facts = <(IconData, String)>[
          (Icons.schedule, '${loc.formatMediumDate(when)}, ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(when))}'),
          (Icons.place_outlined, record.location == null ? 'No location saved' : LocationService.format(record.location!)),
          if (record.confidence != null)
            (Icons.analytics_outlined, '${(record.confidence! * 100).round()}% match'),
          if (record.habitatType != null) (Icons.water_outlined, record.habitatType!),
          if (record.waterDepth != null) (Icons.straighten, '${record.waterDepth} m deep'),
          if (record.behaviors != null) (Icons.notes, record.behaviors!),
          (
            Icons.verified_outlined,
            switch (record.status) {
              'verified' => 'Verified by an expert${record.adminNotes?.isNotEmpty == true ? ': ${record.adminNotes}' : ''}',
              'rejected' => 'Rejected by an expert',
              _ => record.needsVerification ? 'Waiting for expert review' : 'Not reviewed yet',
            },
          ),
        ];

        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: WildImage(record.imagePath, fit: BoxFit.contain, radius: 14, background: wild.ground),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    speciesNameForRecord(record),
                    style: GoogleFonts.anekLatin(fontSize: 26, height: 1.1, fontWeight: FontWeight.w800, color: wild.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.only(top: 4), child: StatusTag(status)),
              ],
            ),
            if (animal != null && animal.scientificName != animal.name)
              Text(animal.scientificName,
                  style: GoogleFonts.anekLatin(fontSize: 16, fontStyle: FontStyle.italic, color: wild.muted)),
            const SizedBox(height: 14),
            for (final (icon, text) in facts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: wild.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text, style: GoogleFonts.anekLatin(fontSize: 16, color: wild.ink))),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MetadataFormScreen(record: record)),
              ),
              icon: const Icon(Icons.edit_note),
              label: const Text('Edit details'),
            ),
            if (animal != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SpeciesDetailScreen(animal: animal)),
                ),
                child: const Text('About this species'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _delete(context),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete report'),
            ),
          ],
        );
      },
    );
  }
}
