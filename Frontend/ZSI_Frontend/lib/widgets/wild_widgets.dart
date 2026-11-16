import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';

/// Small coloured block naming a protection status ("SCH. I").
class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key, this.compact = false});

  final ProtectionStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: switch (status) {
        ProtectionStatus.scheduleI => 'Schedule I, protected',
        ProtectionStatus.scheduleII => 'Schedule II, protected',
        ProtectionStatus.unsure => 'Unsure',
        ProtectionStatus.notListed => 'Not listed',
      },
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: status.color,
          borderRadius: BorderRadius.circular(compact ? 5 : 6),
        ),
        child: Text(
          status.tag,
          style: GoogleFonts.anekLatin(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: status.onColor,
          ),
        ),
      ),
    );
  }
}

/// The four-colour key under the home header.
class StatusKey extends StatelessWidget {
  const StatusKey({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (ProtectionStatus.scheduleI, 'Sch. I', 'Release'),
      (ProtectionStatus.scheduleII, 'Sch. II', 'Protected'),
      (ProtectionStatus.unsure, 'Unsure', 'Retake'),
      (ProtectionStatus.notListed, 'Not listed', 'Local rules'),
    ];
    return Row(
      children: [
        for (final (status, title, hint) in items)
          Expanded(
            child: Container(
              color: status.color,
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anekLatin(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: status.onColor,
                    ),
                  ),
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anekLatin(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: status.onColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Shows a species asset, a saved sighting photo, or a network image, with a
/// quiet placeholder if it cannot load.
class WildImage extends StatelessWidget {
  const WildImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 10,
    this.background,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    Widget fallback(BuildContext _, Object __, StackTrace? ___) => Container(
      width: width,
      height: height,
      color: wild.line,
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported_outlined, color: wild.muted),
    );

    final cacheWidth = width != null && width!.isFinite
        ? (width! * MediaQuery.devicePixelRatioOf(context)).round()
        : null;

    Widget image;
    if (path.isEmpty) {
      image = fallback(context, 'empty', null);
    } else if (path.startsWith('assets/')) {
      image = Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: fallback,
      );
    } else if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
      image = Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: fallback,
      );
    } else {
      image = Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: fallback,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        color: background ?? wild.line.withValues(alpha: 0.4),
        width: width,
        height: height,
        child: image,
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

/// A friendly empty state: icon, one line of title, one line of help.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: wild.muted),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: wild.muted),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Relative date like "2 h ago", "Yesterday", "12 Nov".
String friendlyTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24 && current.day == time.day)
    return '${diff.inHours} h ago';
  final yesterday = DateTime(current.year, current.month, current.day - 1);
  if (time.year == yesterday.year &&
      time.month == yesterday.month &&
      time.day == yesterday.day) {
    return 'Yesterday';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final label = '${time.day} ${months[time.month - 1]}';
  return time.year == current.year ? label : '$label ${time.year}';
}
