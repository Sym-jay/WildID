import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/services/archive_service.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../dialogs/about_screen.dart';
import '../dialogs/help_center_screen.dart';
import 'login_screen.dart';
import 'verification_queue_screen.dart';

/// Profile tab: account, expert tools, help and contact.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _address =
      'Zoological Survey of India, M-Block, New Alipore, Kolkata 700053';
  static const _email = 'zsi@gov.in';
  static const _phone = '+91-33-2400-1893';

  void _showContact(BuildContext context) {
    final wild = WildColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Contact ZSI',
                style: GoogleFonts.anekLatin(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: wild.ink,
                ),
              ),
              const SizedBox(height: 12),
              for (final (icon, value) in const [
                (Icons.place_outlined, _address),
                (Icons.mail_outline, _email),
                (Icons.call_outlined, _phone),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon),
                  title: SelectableText(
                    value,
                    style: GoogleFonts.anekLatin(fontSize: 16, color: wild.ink),
                  ),
                  trailing: IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Copied')));
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your reports stay on this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    AuthService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    final user = AuthService.currentUser;
    final phone = AuthService.currentUserPhone;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ValueListenableBuilder<int>(
        valueListenable: ArchiveService.changes,
        builder: (context, _, __) {
          final stats = ArchiveService.getStatistics();
          final review = ArchiveService.getNeedsVerification().length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: wild.shell,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: wild.accent,
                      foregroundColor: wild.onAccent,
                      child: Text(
                        (user ?? 'G').substring(0, 1).toUpperCase(),
                        style: GoogleFonts.anekLatin(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user ?? 'Guest',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.anekLatin(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: wild.onShell,
                            ),
                          ),
                          Text(
                            phone ??
                                (user == null
                                    ? 'Sign in to get SMS alerts'
                                    : 'No phone number'),
                            style: GoogleFonts.anekLatin(
                              fontSize: 15,
                              color: wild.shellMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat(wild, '${stats['total']}', 'Reports'),
                  const SizedBox(width: 10),
                  _stat(wild, '${stats['verified']}', 'Verified'),
                  const SizedBox(width: 10),
                  _stat(wild, '$review', 'Need review'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: wild.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _tile(
                      context,
                      Icons.fact_check_outlined,
                      'Expert review queue',
                      review == 0 ? 'Nothing waiting' : '$review waiting',
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const VerificationQueueScreen(),
                        ),
                      ),
                    ),
                    const Divider(indent: 56),
                    _tile(
                      context,
                      Icons.help_outline,
                      'Help and photo tips',
                      null,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HelpCenterScreen(),
                        ),
                      ),
                    ),
                    const Divider(indent: 56),
                    _tile(
                      context,
                      Icons.support_agent_outlined,
                      'Contact ZSI',
                      null,
                      () => _showContact(context),
                    ),
                    const Divider(indent: 56),
                    _tile(
                      context,
                      Icons.info_outline,
                      'About WildID',
                      null,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (user == null)
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Sign in or create account'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(WildColors wild, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: wild.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.anekLatin(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: wild.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: GoogleFonts.anekLatin(fontSize: 14, color: wild.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback onTap,
  ) {
    // Own ink surface: rows sit on a coloured card, which would hide the ripple.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        minTileHeight: 56,
        leading: Icon(icon),
        title: Text(
          title,
          style: GoogleFonts.anekLatin(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
