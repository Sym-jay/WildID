import 'package:flutter/material.dart' hide Badge;

import '../core/theme/app_theme.dart';
import 'about_screen.dart';


class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            title: 'About',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.help_outline,
            title: 'FAQ',
            onTap: () {
              // Navigate to FAQ screen
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {
              // Navigate to Privacy Policy
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () {
              // Navigate to Terms
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.support_agent,
            title: 'Contact Support',
            onTap: () => _showContactDialog(context),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Version: 1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: support@zsi.gov.in'),
            SizedBox(height: 8),
            Text('Phone: +91-33-2400-1893'),
            SizedBox(height: 16),
            Text(
              'For technical issues, please email with screenshots and device details.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

