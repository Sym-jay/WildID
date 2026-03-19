import 'package:flutter/material.dart';
import '../models/index.dart' as models;

class UserProfileCard extends StatelessWidget {
  final models.UserProfile profile;
  final List<models.Badge> badges;

  const UserProfileCard({
    super.key,
    required this.profile,
    required this.badges,
  }) : super();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: Colors.blue.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName ?? 'User Profile',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Joined ${_formatDate(profile.joinDate)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _StatRow(
                  label: 'Total Submissions',
                  value: profile.totalSubmissions.toString(),
                ),
                const SizedBox(height: 12),
                _StatRow(
                  label: 'Verified',
                  value: '${profile.verifiedSubmissions}/${profile.totalSubmissions}',
                ),
                const SizedBox(height: 12),
                _StatRow(
                  label: 'Verification Rate',
                  value: '${profile.verificationRate.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 12),
                _StatRow(
                  label: 'Accuracy Score',
                  value: '${profile.accuracyScore.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Badges Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Badges (${profile.badges.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (profile.badges.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'No badges yet. Keep contributing!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: profile.badges.map((badgeId) {
                  final badge = badges.firstWhere(
                    (b) => b.id == badgeId,
                    orElse: () => models.Badge(
                      id: badgeId,
                      name: 'Unknown',
                      description: 'Badge',
                      icon: '⭐',
                      condition: '',
                    ),
                  );
                  return _BadgeWidget(badge: badge);
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}

class _BadgeWidget extends StatelessWidget {
  final models.Badge badge;

  const _BadgeWidget({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.description,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                badge.icon,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 70,
            child: Text(
              badge.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
