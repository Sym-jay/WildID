import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';

/// Shared layout for sign-in screens: sea-green band with a condensed title,
/// then the form on the page ground.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: wild.ground,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: wild.shell,
              padding: EdgeInsets.fromLTRB(
                showBack ? 8 : 20,
                topInset + (showBack ? 4 : 24),
                20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back, color: wild.onShell),
                      tooltip: 'Back',
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/logo.jpg',
                        width: 48,
                        height: 48,
                        semanticLabel: 'ZSI logo',
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(left: showBack ? 12 : 0, top: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title.toUpperCase(),
                            style: AppTheme.display(42, wild.onShell),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: GoogleFonts.anekLatin(
                            fontSize: 17,
                            height: 1.4,
                            color: wild.shellMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
