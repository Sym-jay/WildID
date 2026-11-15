import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/services/archive_service.dart';
import '../core/services/species_lookup_service.dart';
import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';
import '../widgets/wild_widgets.dart';
import 'home_screen.dart' show speciesNameForRecord, statusForRecord;

/// Expert review: confirm or correct reports that need checking.
class VerificationQueueScreen extends StatefulWidget {
  const VerificationQueueScreen({super.key});

  @override
  State<VerificationQueueScreen> createState() => _VerificationQueueScreenState();
}

class _VerificationQueueScreenState extends State<VerificationQueueScreen> {
  late final Future<List<Animal>> _species = SpeciesLookupService.loadSpecies();

  Future<void> _review(UploadRecord record, List<Animal> species) async {
    final result = await showModalBottomSheet<_Decision>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReviewSheet(record: record, species: species),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.reject) {
      await ArchiveService.rejectUpload(record.id, result.notes);
      messenger.showSnackBar(const SnackBar(content: Text('Report rejected')));
    } else {
      await ArchiveService.verifyUpload(
        record.id,
        result.species!,
        result.notes,
        expertConfidence: result.confidence,
      );
      messenger.showSnackBar(SnackBar(content: Text('Verified as ${result.speciesName}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Expert review')),
      body: FutureBuilder<List<Animal>>(
        future: _species,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final species = snapshot.data!;
          return ValueListenableBuilder<int>(
            valueListenable: ArchiveService.changes,
            builder: (context, _, __) {
              final pending = ArchiveService.getUploadHistory()
                  .where((r) => r.status == 'pending')
                  .toList()
                ..sort((a, b) {
                  // Uncertain ones first, then oldest first.
                  if (a.needsVerification != b.needsVerification) return a.needsVerification ? -1 : 1;
                  return a.timestamp.compareTo(b.timestamp);
                });
              if (pending.isEmpty) {
                return const EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'Nothing to review',
                  message: 'New reports appear here until an expert confirms or corrects them.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: pending.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = pending[i];
                  return Material(
                    color: wild.card,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _review(r, species),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            WildImage(r.imagePath, width: 72, height: 72),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(speciesNameForRecord(r),
                                      style: GoogleFonts.anekLatin(fontSize: 17, fontWeight: FontWeight.w700, color: wild.ink)),
                                  Text(
                                    [
                                      if (r.confidence != null) 'AI ${(r.confidence! * 100).round()}%',
                                      friendlyTime(r.timestamp),
                                      if (r.needsVerification) 'Uncertain',
                                    ].join(' · '),
                                    style: GoogleFonts.anekLatin(fontSize: 14, color: wild.muted),
                                  ),
                                ],
                              ),
                            ),
                            StatusTag(statusForRecord(r)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _Decision {
  const _Decision({this.species, this.speciesName, this.notes = '', this.confidence, this.reject = false});

  final String? species;
  final String? speciesName;
  final String notes;
  final int? confidence;
  final bool reject;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.record, required this.species});

  final UploadRecord record;
  final List<Animal> species;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _notes = TextEditingController();
  String? _selected;
  double _confidence = 80;

  @override
  void initState() {
    super.initState();
    // Pre-select the AI's answer only if it is a known species.
    final label = widget.record.identifiedSpecies;
    final match = label == null ? null : SpeciesLookupService.lookupLoaded(label);
    _selected = match?.scientificName;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    final sorted = [...widget.species]..sort((a, b) => a.name.compareTo(b.name));
    final r = widget.record;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: WildImage(r.imagePath, fit: BoxFit.contain, radius: 14, background: wild.ground),
          ),
          const SizedBox(height: 12),
          Text(
            r.identifiedSpecies == null
                ? 'The AI did not recognise this animal.'
                : 'AI suggestion: ${speciesNameForRecord(r)} (${((r.confidence ?? 0) * 100).round()}%)',
            style: GoogleFonts.anekLatin(fontSize: 16, color: wild.muted),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Correct species'),
            items: [
              for (final a in sorted)
                DropdownMenuItem(
                  value: a.scientificName,
                  child: Text(
                    a.name == a.scientificName ? a.name : '${a.name} (${a.scientificName})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _selected = v),
          ),
          const SizedBox(height: 16),
          Text('How sure are you? ${_confidence.round()}%',
              style: GoogleFonts.anekLatin(fontSize: 16, fontWeight: FontWeight.w600, color: wild.ink)),
          Slider(
            value: _confidence,
            min: 0,
            max: 100,
            divisions: 10,
            label: '${_confidence.round()}%',
            onChanged: (v) => setState(() => _confidence = v),
          ),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes', hintText: 'Features you checked'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () {
                    final animal = SpeciesLookupService.lookupLoaded(_selected!);
                    Navigator.pop(
                      context,
                      _Decision(
                        species: _selected,
                        speciesName: animal?.name ?? _selected,
                        notes: _notes.text.trim(),
                        confidence: _confidence.round(),
                      ),
                    );
                  },
            child: const Text('Confirm species'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, _Decision(reject: true, notes: _notes.text.trim())),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Not a usable photo'),
          ),
        ],
      ),
    );
  }
}
