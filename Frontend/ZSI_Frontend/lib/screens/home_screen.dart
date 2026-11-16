import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/services/archive_service.dart';
import '../core/services/identification_service.dart';
import '../core/services/species_lookup_service.dart';
import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';
import '../widgets/wild_widgets.dart';
import 'browse_species_screen.dart';
import 'identification_screen.dart';
import 'profile_screen.dart';
import 'upload_history_screen.dart' show UploadHistoryScreen, showSightingSheet;

/// Protection status of a saved sighting, from the species it was matched to.
ProtectionStatus statusForRecord(UploadRecord record) {
  final label = record.verifiedSpecies ?? record.identifiedSpecies;
  if (label == null) return ProtectionStatus.unsure;
  if ((record.confidence ?? 1) < 0.5 && record.verifiedSpecies == null) {
    return ProtectionStatus.unsure;
  }
  final animal = SpeciesLookupService.lookupLoaded(label);
  if (animal == null) return ProtectionStatus.unsure;
  return ProtectionStatusX.fromSchedule(animal.schedule);
}

/// Display name for a sighting's species (common name when we know it).
String speciesNameForRecord(UploadRecord record) {
  final label = record.verifiedSpecies ?? record.identifiedSpecies;
  if (label == null) return 'Not recognised';
  return SpeciesLookupService.lookupLoaded(label)?.name ?? label;
}

/// App shell: Identify, Species, History, Profile.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final pages = [
      IdentifyTab(onSeeHistory: () => setState(() => _tab = 2)),
      const BrowseSpeciesScreen(),
      const UploadHistoryScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: 'Identify',
          ),
          NavigationDestination(
            icon: Icon(Icons.set_meal_outlined),
            selectedIcon: Icon(Icons.set_meal),
            label: 'Species',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Start an identification from the camera or gallery.
Future<void> startIdentification(
  BuildContext context,
  ImageSource source,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (image == null) return;
    await navigator.push(
      MaterialPageRoute(builder: (_) => IdentificationScreen(image: image)),
    );
  } on PlatformException catch (e) {
    final what = source == ImageSource.camera ? 'camera' : 'photos';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.code.contains('denied')
              ? 'WildID needs access to your $what. Allow it in your phone settings.'
              : 'Could not open the $what. Try again.',
        ),
      ),
    );
  }
}

class IdentifyTab extends StatefulWidget {
  const IdentifyTab({super.key, required this.onSeeHistory});

  final VoidCallback onSeeHistory;

  @override
  State<IdentifyTab> createState() => _IdentifyTabState();
}

class _IdentifyTabState extends State<IdentifyTab> {
  @override
  void initState() {
    super.initState();
    // Species names and schedules for the recent list.
    SpeciesLookupService.loadSpecies().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: wild.ground,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: wild.shell,
                padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _brandRow(wild),
                    const SizedBox(height: 22),
                    Semantics(
                      header: true,
                      child: Text(
                        'IS IT\nPROTECTED?',
                        style: AppTheme.display(46, wild.onShell),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        'Photograph the animal. You get its protection status in seconds.',
                        style: GoogleFonts.anekLatin(
                          fontSize: 17,
                          height: 1.4,
                          color: wild.shellMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => startIdentification(
                              context,
                              ImageSource.camera,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: wild.accent,
                              foregroundColor: wild.onAccent,
                              textStyle: GoogleFonts.anekLatin(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            icon: const Icon(Icons.photo_camera, size: 24),
                            label: const Text('Take photo'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => startIdentification(
                              context,
                              ImageSource.gallery,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: wild.onShell,
                              side: BorderSide(
                                color: wild.shellMuted.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              minimumSize: const Size(56, 56),
                            ),
                            child: const Icon(
                              Icons.photo_library_outlined,
                              semanticLabel: 'Choose from gallery',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: StatusKey()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              sliver: SliverToBoxAdapter(
                child: ValueListenableBuilder<int>(
                  valueListenable: ArchiveService.changes,
                  builder: (context, _, __) => _recent(context, wild),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandRow(WildColors wild) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/logo.jpg',
            width: 38,
            height: 38,
            semanticLabel: 'ZSI logo',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WildID',
                style: GoogleFonts.anekLatin(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: wild.onShell,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ZOOLOGICAL SURVEY OF INDIA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anekLatin(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: wild.shellMuted,
                ),
              ),
            ],
          ),
        ),
        if (IdentificationService.demoMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: wild.shellRaised,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Demo mode',
              style: GoogleFonts.anekLatin(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: wild.warning,
              ),
            ),
          ),
      ],
    );
  }

  Widget _recent(BuildContext context, WildColors wild) {
    final records = ArchiveService.getUploadHistory();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Your recent reports',
          action: records.length > 3 ? 'See all' : null,
          onAction: widget.onSeeHistory,
        ),
        const SizedBox(height: 8),
        if (records.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: wild.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const EmptyState(
              icon: Icons.photo_camera_outlined,
              title: 'No reports yet',
              message:
                  'Your identified animals appear here, with their protection status.',
            ),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: wild.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (final (i, r) in records.take(3).indexed) ...[
                  if (i > 0) const Divider(indent: 78),
                  SightingRow(
                    record: r,
                    onTap: () => showSightingSheet(context, r.id),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One sighting in a list: photo, species, place/time, status tag.
class SightingRow extends StatelessWidget {
  const SightingRow({super.key, required this.record, this.onTap});

  final UploadRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    final status = statusForRecord(record);
    final place =
        record.location?.address ??
        record.habitatType ??
        (record.location?.latitude != null ? 'Location saved' : null);
    final when = friendlyTime(record.observationDateTime ?? record.timestamp);
    final subtitle = [
      if (record.status == 'verified') 'Verified',
      if (place != null) place,
      when,
    ].join(' · ');

    // Own ink surface: rows sit on a coloured card, which would hide the ripple.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              WildImage(record.imagePath, width: 52, height: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      speciesNameForRecord(record),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anekLatin(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: wild.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anekLatin(
                        fontSize: 14,
                        color: wild.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusTag(status),
            ],
          ),
        ),
      ),
    );
  }
}
