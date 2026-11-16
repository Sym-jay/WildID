import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/services/species_lookup_service.dart';
import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';
import '../widgets/wild_widgets.dart';
import 'species_detail_screen.dart';

/// Species tab: search and filter the 66 protected species.
class BrowseSpeciesScreen extends StatefulWidget {
  const BrowseSpeciesScreen({super.key});

  @override
  State<BrowseSpeciesScreen> createState() => _BrowseSpeciesScreenState();
}

class _BrowseSpeciesScreenState extends State<BrowseSpeciesScreen> {
  late final Future<List<Animal>> _species = SpeciesLookupService.loadSpecies();
  final _search = TextEditingController();
  String _query = '';
  int? _schedule; // null = all

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Animal> _filter(List<Animal> all) {
    final q = SpeciesLookupService.normalize(_query);
    final list =
        all.where((a) {
          if (_schedule != null && a.schedule != _schedule) return false;
          if (q.isEmpty) return true;
          return SpeciesLookupService.normalize(a.name).contains(q) ||
              SpeciesLookupService.normalize(a.scientificName).contains(q);
        }).toList()..sort((a, b) {
          final bySchedule = (a.schedule ?? 9).compareTo(b.schedule ?? 9);
          return bySchedule != 0 ? bySchedule : a.name.compareTo(b.name);
        });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Protected species')),
      body: FutureBuilder<List<Animal>>(
        future: _species,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load species',
              message:
                  'Restart the app. If this keeps happening, reinstall it.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final shown = _filter(all);
          final count1 = all.where((a) => a.schedule == 1).length;
          final count2 = all.where((a) => a.schedule == 2).length;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search by common or scientific name',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _query = '';
                                  }),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text('All ${all.length}'),
                            selected: _schedule == null,
                            onSelected: (_) => setState(() => _schedule = null),
                          ),
                          ChoiceChip(
                            label: Text('Schedule I · $count1'),
                            selected: _schedule == 1,
                            onSelected: (_) => setState(() => _schedule = 1),
                          ),
                          ChoiceChip(
                            label: Text('Schedule II · $count2'),
                            selected: _schedule == 2,
                            onSelected: (_) => setState(() => _schedule = 2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (shown.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: 'No species match "$_query"',
                    message: 'Try a shorter name, or the scientific name.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  sliver: DecoratedSliver(
                    decoration: BoxDecoration(
                      color: wild.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    sliver: SliverList.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const Divider(indent: 82),
                      itemBuilder: (context, i) =>
                          _SpeciesRow(animal: shown[i]),
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

class _SpeciesRow extends StatelessWidget {
  const _SpeciesRow({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    final showScientific =
        animal.scientificName.toLowerCase() != animal.name.toLowerCase();
    // Own ink surface: rows sit on a coloured card, which would hide the ripple.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SpeciesDetailScreen(animal: animal),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              WildImage(
                animal.imageUrl,
                width: 56,
                height: 56,
                background: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anekLatin(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: wild.ink,
                      ),
                    ),
                    if (showScientific)
                      Text(
                        animal.scientificName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.anekLatin(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: wild.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusTag(ProtectionStatusX.fromSchedule(animal.schedule)),
            ],
          ),
        ),
      ),
    );
  }
}
