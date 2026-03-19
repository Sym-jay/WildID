
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';
import '../core/services/database_service.dart';
// New feature imports
import '../shared/widgets/user_profile_card.dart' as profile_widgets;
import '../dialogs/index.dart';
import '../core/services/index.dart';
import '../widgets/index.dart';
import 'login_screen.dart';
import 'identification_screen.dart';
import 'verification_queue_screen.dart';
import 'upload_history_screen.dart';
import 'browse_species_screen.dart';
import '../utils/app_utils.dart';


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (pickedFile != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => IdentificationScreen(imageFile: File(pickedFile.path)),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        String message = 'Permission denied. Please enable ${source == ImageSource.camera ? "camera" : "photo library"} access in settings.';
        if (Platform.isIOS && e.code == 'camera_access_denied') {
          message = 'Camera access denied. Go to Settings > Privacy > Camera to enable access.';
        } else if (Platform.isIOS && e.code == 'photo_access_denied') {
          message = 'Photo library access denied. Go to Settings > Privacy > Photos to enable access.';
        }
        AppUtils.showError(context, message);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'Error picking image: ${e.toString()}');
      }
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              AuthService.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Us'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Zoological Survey of India',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildContactRow(Icons.location_on, 'M-Block, New Alipore, Kolkata - 700053'),
              const SizedBox(height: 12),
              _buildContactRow(Icons.email, 'zsi@gov.in'),
              const SizedBox(height: 12),
              _buildContactRow(Icons.phone, '+91-33-2400-1893'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'For species identification assistance, please upload images through the app. Your uploads help conservation research.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
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

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  void _showAlertHistory() {
    final alerts = SMSService.getSentAlerts();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SMS History'),
        content: SizedBox(
          width: double.maxFinite,
          child: alerts.isEmpty
              ? const Center(child: Text('No SMS sent yet'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.sms, color: AppTheme.primaryColor),
                      title: Text(alerts[index], style: const TextStyle(fontSize: 12)),
                      dense: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    // Create sample user profile
    final profile = UserProfile(
      userId: AuthService.currentUser ?? 'guest',
      email: AuthService.currentUser ?? 'not-logged-in@example.com',
      displayName: 'Wildlife Observer',
      joinDate: DateTime.now().subtract(const Duration(days: 90)),
      totalSubmissions: ArchiveService.getUploadHistory().length,
      verifiedSubmissions: ArchiveService.getUploadHistory()
          .where((r) => r.status == 'verified')
          .length,
      accuracyScore: ArchiveService.getStatistics()['verifiedPercentage']?.toDouble() ?? 0.0,
      badges: _calculateBadges(),
    );

    final badges = [
      Badge(
        id: 'first_observation',
        name: 'First Step',
        description: 'Submit your first observation',
        icon: '🌱',
        condition: 'totalSubmissions >= 1',
      ),
      Badge(
        id: 'verified_100',
        name: 'Verified Century',
        description: 'Get 100 observations verified',
        icon: '✅',
        condition: 'verifiedSubmissions >= 100',
      ),
      Badge(
        id: 'accuracy_90',
        name: 'Expert Eye',
        description: 'Achieve 90% accuracy rate',
        icon: '👁️',
        condition: 'accuracyScore >= 90',
      ),
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: profile_widgets.UserProfileCard(profile: profile, badges: badges),
      ),
    );
  }

  List<String> _calculateBadges() {
    final badges = <String>[];
    final uploadHistory = ArchiveService.getUploadHistory();
    final verified = uploadHistory.where((r) => r.status == 'verified').length;
    
    if (uploadHistory.isNotEmpty) badges.add('first_observation');
    if (verified >= 100) badges.add('verified_100');
    
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZSI Wildlife Identifier'),
        actions: [
         /* IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const BrowseSpeciesScreen()),
            ),
            icon: const Icon(Icons.list),
            tooltip: 'Browse Species', */
         // ),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const HelpCenterScreen()),
              ),
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
            ),

          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              } else if (value == 'alerts') {
                _showAlertHistory();
              } else if (value == 'profile') {
                _showProfileDialog();
              } else if (value == 'verification') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const VerificationQueueScreen()),
                );
              } else if (value == 'uploads') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const UploadHistoryScreen()),
                );
              } else if (value == 'about') {
                _showAboutDialog();
              } else if (value == 'login') {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              if (AuthService.isLoggedIn) ...[
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 20),
                      const SizedBox(width: 8),
                      const Text('My Profile'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'verification',
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user, size: 20),
                      const SizedBox(width: 8),
                      Text('Verification Queue (${ArchiveService.getNeedsVerification().length})'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'uploads',
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 20),
                      const SizedBox(width: 8),
                      Text('Upload History (${ArchiveService.getUploadHistory().length})'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'alerts',
                  child: Row(
                    children: [
                      const Icon(Icons.sms, size: 20),
                      const SizedBox(width: 8),
                      Text('SMS History (${SMSService.getSentAlerts().length})'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ],
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Contact Us'),
                  ],
                ),
              ),
              if (AuthService.isLoggedIn)
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'login',
                  child: Row(
                    children: [
                      Icon(Icons.login, size: 20),
                      SizedBox(width: 8),
                      Text('Login / Register'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppTheme.backgroundColor],
          ),
        ),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(_slideAnimation),
          child: FadeTransition(
            opacity: _slideAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 30),
                Text(
                  'Identify Wildlife',
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Take a photo or upload an image to identify endangered species using AI',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (AuthService.isLoggedIn) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'SMS alerts & data archiving enabled',
                          style: TextStyle(color: Colors.green[800], fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 60),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 24),
                    label: const Text('Take Photo', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      elevation: 8,
                      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.image, size: 24),
                    label: const Text('Upload from Gallery', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 40),
                const Divider(height: 40),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const BrowseSpeciesScreen()),
                  ),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Browse Species Database', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// IDENTIFICATION SCREEN
// ============================================================================

