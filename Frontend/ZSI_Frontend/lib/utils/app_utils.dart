
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================

// ============================================================================
class AppUtils {
  AppUtils._();

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'critically endangered':
        return Colors.red[800]!;
      case 'endangered':
        return Colors.red[600]!;
      case 'vulnerable':
        return Colors.orange[600]!;
      case 'near threatened':
        return Colors.yellow[700]!;
      case 'least concern':
        return Colors.green[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  static Future<void> launchURL(BuildContext context, String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $url'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Copy URL',
              textColor: Colors.white,
              onPressed: () => Clipboard.setData(ClipboardData(text: url)),
            ),
          ),
        );
      }
    }
  }

  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}


// ============================================================================
// SPLASH SCREEN
// ============================================================================

