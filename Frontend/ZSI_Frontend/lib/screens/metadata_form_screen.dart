import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/services/archive_service.dart';
import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';

/// Adds field details to an existing sighting. Returns the updated record.
class MetadataFormScreen extends StatefulWidget {
  const MetadataFormScreen({super.key, required this.record});

  final UploadRecord record;

  @override
  State<MetadataFormScreen> createState() => _MetadataFormScreenState();
}

class _MetadataFormScreenState extends State<MetadataFormScreen> {
  static const places = [
    'At sea',
    'Beach or coast',
    'Estuary or backwater',
    'Fish landing centre',
    'Fish market',
    'River or lake',
    'Other',
  ];
  static const conditions = ['Alive', 'Dead', 'Not sure'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _depth;
  late final TextEditingController _notes;
  String? _place;
  String? _condition;
  late DateTime _when;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _place = places.contains(r.habitatType) ? r.habitatType : null;
    final parsed = _splitNotes(r.behaviors);
    _condition = parsed.$1;
    _notes = TextEditingController(text: parsed.$2);
    _depth = TextEditingController(
      text: r.waterDepth == null ? '' : r.waterDepth!.toStringAsFixed(r.waterDepth! % 1 == 0 ? 0 : 1),
    );
    _when = r.observationDateTime ?? r.timestamp;
  }

  @override
  void dispose() {
    _depth.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Notes are stored as "Condition: Alive. <free text>".
  static (String?, String) _splitNotes(String? stored) {
    if (stored == null) return (null, '');
    final match = RegExp(r'^Condition: (Alive|Dead|Not sure)\.\s*').firstMatch(stored);
    if (match == null) return (null, stored);
    return (match.group(1), stored.substring(match.end));
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (!mounted) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time?.hour ?? _when.hour, time?.minute ?? _when.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final notes = _notes.text.trim();
    final combined = [
      if (_condition != null) 'Condition: $_condition.',
      if (notes.isNotEmpty) notes,
    ].join(' ');
    final updated = widget.record.copyWith(
      habitatType: _place,
      waterDepth: double.tryParse(_depth.text.trim()),
      behaviors: combined.isEmpty ? null : combined,
      observationDateTime: _when,
    );
    await ArchiveService.updateRecord(updated);
    if (mounted) Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    final labelStyle = GoogleFonts.anekLatin(fontSize: 16, fontWeight: FontWeight.w700, color: wild.ink);
    final loc = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Report details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              'These details help ZSI researchers map where protected species are found. Everything is optional.',
              style: GoogleFonts.anekLatin(fontSize: 15, height: 1.4, color: wild.muted),
            ),
            const SizedBox(height: 22),
            Text('Where was it found?', style: labelStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in places)
                  ChoiceChip(
                    label: Text(p),
                    selected: _place == p,
                    onSelected: (on) => setState(() => _place = on ? p : null),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text('Was the animal alive?', style: labelStyle),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [for (final c in conditions) ButtonSegment(value: c, label: Text(c))],
              selected: {if (_condition != null) _condition!},
              onSelectionChanged: (s) => setState(() => _condition = s.isEmpty ? null : s.first),
            ),
            const SizedBox(height: 22),
            Text('When did you see it?', style: labelStyle),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickWhen,
              icon: const Icon(Icons.event_outlined),
              label: Text('${loc.formatMediumDate(_when)}, ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(_when))}'),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _depth,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Water depth in metres (if known)',
              ),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return null;
                final value = double.tryParse(text);
                if (value == null || value < 0 || value > 11000) return 'Enter a depth in metres, like 12';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Size, number of animals, gear used, anything unusual',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save details'),
          ),
        ),
      ),
    );
  }
}
