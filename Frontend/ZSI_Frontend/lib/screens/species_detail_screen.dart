import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';
import '../widgets/wild_widgets.dart';

class SpeciesDetailScreen extends StatelessWidget {
  const SpeciesDetailScreen({super.key, required this.animal});

  final Animal animal;

  Future<void> _openIucn(BuildContext context) async {
    final uri = Uri.tryParse(animal.iucnUrl);
    final ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the IUCN Red List page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    final status = ProtectionStatusX.fromSchedule(animal.schedule);
    final advice = switch (status) {
      ProtectionStatus.scheduleI =>
        'Schedule I. Catching, keeping, selling or harming it is an offence. Release it alive if you can.',
      ProtectionStatus.scheduleII =>
        'Schedule II. Protected; catching or trading it is controlled by law. Release it alive if you can.',
      _ => 'Not on the protected list. Local fishing rules still apply.',
    };
    final showScientific =
        animal.scientificName.toLowerCase() != animal.name.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(animal.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: WildImage(
              animal.imageUrl,
              fit: BoxFit.contain,
              radius: 16,
              background: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            animal.name,
            style: GoogleFonts.anekLatin(
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: wild.ink,
            ),
          ),
          if (showScientific)
            Text(
              animal.scientificName,
              style: GoogleFonts.anekLatin(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: wild.muted,
              ),
            ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: status.color,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status == ProtectionStatus.notListed
                      ? 'NOT LISTED'
                      : 'PROTECTED',
                  style: GoogleFonts.anekLatin(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: status.onColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  advice,
                  style: GoogleFonts.anekLatin(
                    fontSize: 16,
                    height: 1.4,
                    color: status.onColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            animal.description,
            style: GoogleFonts.anekLatin(
              fontSize: 17,
              height: 1.5,
              color: wild.ink,
            ),
          ),
          if (animal.iucnUrl.isNotEmpty) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _openIucn(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('See it on the IUCN Red List'),
            ),
          ],
        ],
      ),
    );
  }
}
