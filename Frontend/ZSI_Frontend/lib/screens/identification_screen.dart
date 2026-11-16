import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config/error_handler.dart';
import '../core/services/archive_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/identification_service.dart';
import '../core/services/location_service.dart';
import '../core/services/sms_service.dart';
import '../core/services/species_lookup_service.dart';
import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';
import '../widgets/wild_widgets.dart';
import 'metadata_form_screen.dart';
import 'species_detail_screen.dart';

/// Below this, the answer is shown as "Unsure" with the best guess.
const double kConfidentMatch = 0.5;

class IdentificationScreen extends StatefulWidget {
  const IdentificationScreen({super.key, required this.image});

  final XFile image;

  @override
  State<IdentificationScreen> createState() => _IdentificationScreenState();
}

class _IdentificationScreenState extends State<IdentificationScreen> {
  Uint8List? _bytes;
  IdentificationOutcome? _outcome;
  Animal? _topAnimal;
  final Map<String, Animal?> _animals = {};
  String? _error;
  bool _working = true;
  UploadRecord? _record;
  LocationData? _location;

  @override
  void initState() {
    super.initState();
    widget.image.readAsBytes().then((b) {
      if (mounted) setState(() => _bytes = b);
    });
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _working = true;
      _error = null;
    });
    // Ask for location while the photo is being identified.
    final locationFuture = LocationService.currentLocation();
    try {
      await SpeciesLookupService.loadSpecies();
      final outcome = await IdentificationService.identify(widget.image);
      for (final r in outcome.results) {
        _animals[r.label] = SpeciesLookupService.lookupLoaded(r.label);
      }
      final top = outcome.top;
      _location = await locationFuture;
      final record = await ArchiveService.archiveUpload(
        image: widget.image,
        identifiedSpecies: top?.label,
        confidence: top?.confidence,
        location: _location,
      );
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _topAnimal = top == null ? null : _animals[top.label];
        _record = record;
        _working = false;
      });
      unawaited(_maybeSendAlert());
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _working = false;
      });
    } catch (e) {
      debugPrint('Identification failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while checking the photo. Try again.';
        _working = false;
      });
    }
  }

  Future<void> _maybeSendAlert() async {
    final top = _outcome?.top;
    final phone = AuthService.currentUserPhone;
    if (top == null || phone == null || _topAnimal == null) return;
    if (top.confidence < 0.6 || !_topAnimal!.isProtected) return;
    await SMSService.sendEndangeredSpeciesAlert(phone, _topAnimal!.name);
  }

  ProtectionStatus get _status {
    final top = _outcome?.top;
    if (top == null || top.confidence < kConfidentMatch || _topAnimal == null) {
      return ProtectionStatus.unsure;
    }
    return ProtectionStatusX.fromSchedule(_topAnimal!.schedule);
  }

  Future<void> _addDetails() async {
    final record = _record;
    if (record == null) return;
    final updated = await Navigator.of(context).push<UploadRecord>(
      MaterialPageRoute(builder: (_) => MetadataFormScreen(record: record)),
    );
    if (updated != null && mounted) {
      setState(() => _record = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details saved to this report')),
      );
    }
  }

  Future<void> _retake() async {
    XFile? image;
    try {
      image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
    } catch (e) {
      debugPrint('Camera unavailable: $e');
    }
    if (image == null || !mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => IdentificationScreen(image: image!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    if (_working) return _loading(wild);
    if (_error != null) return _failure(wild);
    return _result(wild);
  }

  // ---------------------------------------------------------------- loading

  Widget _loading(WildColors wild) {
    return Scaffold(
      backgroundColor: wild.shell,
      appBar: AppBar(
        backgroundColor: wild.shell,
        foregroundColor: wild.onShell,
        title: const Text('Checking photo'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _photo(wild, fit: BoxFit.contain)),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                color: wild.accent,
                backgroundColor: wild.shellRaised,
              ),
              const SizedBox(height: 14),
              Text(
                'Comparing with 66 protected species…',
                style: GoogleFonts.anekLatin(fontSize: 17, color: wild.onShell),
              ),
              const SizedBox(height: 4),
              Text(
                'This usually takes a few seconds.',
                style: GoogleFonts.anekLatin(
                  fontSize: 15,
                  color: wild.shellMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo(WildColors wild, {BoxFit fit = BoxFit.cover, double? size}) {
    final bytes = _bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size,
        height: size,
        color: wild.card,
        child: bytes == null
            ? const SizedBox.shrink()
            : Image.memory(
                bytes,
                fit: fit,
                gaplessPlayback: true,
                semanticLabel: 'Your photo',
              ),
      ),
    );
  }

  // ---------------------------------------------------------------- failure

  Widget _failure(WildColors wild) {
    return Scaffold(
      appBar: AppBar(title: const Text('Could not check photo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SizedBox(height: 220, child: _photo(wild, fit: BoxFit.contain)),
            const SizedBox(height: 24),
            Icon(Icons.cloud_off_outlined, size: 40, color: wild.muted),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.anekLatin(
                fontSize: 18,
                height: 1.4,
                color: wild.ink,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- result

  Widget _result(WildColors wild) {
    final status = _status;
    final top = _outcome?.top;
    final alternatives = _outcome?.results.skip(1).toList() ?? const [];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _status == ProtectionStatus.unsure
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: wild.ground,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _band(status)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              sliver: SliverList.list(
                children: [
                  if (_outcome?.isDemo ?? false) ...[
                    _note(
                      wild,
                      Icons.science_outlined,
                      'Demo result: this build does not contact the server.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  _matchCard(wild, top),
                  if (alternatives.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _alternatives(wild, alternatives, status),
                  ],
                  const SizedBox(height: 14),
                  _savedLine(wild),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _addDetails,
                  icon: const Icon(Icons.edit_note),
                  label: Text(
                    (_record?.habitatType != null)
                        ? 'Edit report details'
                        : 'Add details for ZSI',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _retake,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Retake photo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _band(ProtectionStatus status) {
    final topInset = MediaQuery.paddingOf(context).top;
    final fg = status.onColor;
    final (eyebrow, headline, body) = switch (status) {
      ProtectionStatus.scheduleI => (
        'SCHEDULE I',
        'PROTECTED.\nDO NOT KEEP.',
        'Release it alive if you can. Catching, keeping or selling this species is an offence.',
      ),
      ProtectionStatus.scheduleII => (
        'SCHEDULE II',
        'PROTECTED.\nRELEASE IT.',
        'Catching or trading this species is controlled by law. Release it alive if you can.',
      ),
      ProtectionStatus.unsure => (
        'UNSURE',
        "CAN'T TELL.\nRETAKE.",
        'The match is not strong enough. Photograph the whole animal in daylight, from the side or top.',
      ),
      ProtectionStatus.notListed => (
        'NOT LISTED',
        'NOT ON THE\nPROTECTED LIST.',
        "This species is not in WildID's protected list. Local fishing rules still apply.",
      ),
    };
    final isSchedule =
        status == ProtectionStatus.scheduleI ||
        status == ProtectionStatus.scheduleII;

    return Container(
      color: status.color,
      padding: EdgeInsets.fromLTRB(8, topInset + 4, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: fg),
            tooltip: 'Back',
          ),
          // Read the verdict as one announcement, but keep Back reachable.
          Semantics(
            container: true,
            liveRegion: true,
            header: true,
            label: '$eyebrow. ${headline.replaceAll('\n', ' ')} $body',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    eyebrow,
                    style: GoogleFonts.anekLatin(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(headline, style: AppTheme.display(48, fg)),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: GoogleFonts.anekLatin(
                      fontSize: 17,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                  if (isSchedule) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Listed under India's Wildlife (Protection) Act, 1972.",
                      style: GoogleFonts.anekLatin(
                        fontSize: 14,
                        color: fg.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(WildColors wild, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ProtectionStatus.unsure.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: wild.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.anekLatin(fontSize: 15, color: wild.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchCard(WildColors wild, IdentificationResult? top) {
    final animal = _topAnimal;
    final name = animal?.name ?? top?.label ?? 'Not recognised';
    final confidence = top?.confidence ?? 0;
    final label = top == null
        ? 'No species matched'
        : confidence >= 0.8
        ? 'High confidence match'
        : confidence >= kConfidentMatch
        ? 'Likely match, check the details'
        : 'Best guess only';

    final percent = (confidence * 100).round();
    return Semantics(
      container: true,
      button: animal != null,
      label: [
        name,
        if (top != null) '$percent percent match',
        label,
        if (animal != null) 'Opens species details',
      ].join('. '),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: animal == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SpeciesDetailScreen(animal: animal),
                  ),
                ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _photo(wild, size: 112),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.anekLatin(
                        fontSize: 26,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: wild.ink,
                      ),
                    ),
                    if (animal != null &&
                        animal.scientificName != animal.name) ...[
                      const SizedBox(height: 2),
                      Text(
                        animal.scientificName,
                        style: GoogleFonts.anekLatin(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: wild.muted,
                        ),
                      ),
                    ],
                    if (top != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              label:
                                  '${(confidence * 100).round()} percent match',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: confidence,
                                  minHeight: 8,
                                  color: Theme.of(context).colorScheme.primary,
                                  backgroundColor: wild.line,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(confidence * 100).round()}%',
                            style: GoogleFonts.anekLatin(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: wild.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.anekLatin(
                        fontSize: 14,
                        color: wild.muted,
                      ),
                    ),
                    if (animal != null)
                      Text(
                        'About this species ›',
                        style: GoogleFonts.anekLatin(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alternatives(
    WildColors wild,
    List<IdentificationResult> alternatives,
    ProtectionStatus topStatus,
  ) {
    final statuses = alternatives.map((r) {
      final a = _animals[r.label];
      return a == null
          ? ProtectionStatus.unsure
          : ProtectionStatusX.fromSchedule(a.schedule);
    }).toList();
    final sameAdvice =
        topStatus != ProtectionStatus.unsure &&
        statuses.every((s) => s == topStatus);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: wild.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALSO POSSIBLE',
            style: GoogleFonts.anekLatin(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: wild.muted,
            ),
          ),
          for (final (i, r) in alternatives.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _animals[r.label]?.name ?? r.label,
                      style: GoogleFonts.anekLatin(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: wild.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${(r.confidence * 100).round()}%',
                    style: GoogleFonts.anekLatin(
                      fontSize: 15,
                      color: wild.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusTag(statuses[i], compact: true),
                ],
              ),
            ),
          if (sameAdvice) ...[
            const SizedBox(height: 10),
            Text(
              'These are also protected, so the advice stays the same.',
              style: GoogleFonts.anekLatin(fontSize: 14, color: wild.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _savedLine(WildColors wild) {
    final location = _record?.location ?? _location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (_record?.needsVerification ?? false)
                    ? 'Saved to your reports and marked for expert review'
                    : 'Saved to your reports',
                style: GoogleFonts.anekLatin(fontSize: 15, color: wild.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.place_outlined, size: 20, color: wild.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                location == null
                    ? 'No location (turn on GPS to add it)'
                    : LocationService.format(location),
                style: GoogleFonts.anekLatin(fontSize: 15, color: wild.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
