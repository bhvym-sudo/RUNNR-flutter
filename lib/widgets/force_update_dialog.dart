import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Force update dialog that blocks the entire app
class ForceUpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;

  const ForceUpdateDialog({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
  });

  Future<void> _openReleasesPage() async {
    try {
      final url = Uri.parse(
        'https://github.com/bhvym-sudo/RUNNR-flutter/releases',
      );
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button from closing dialog
      child: Dialog(
        backgroundColor: const Color(0xFF1E202E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D59A1).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update,
                  size: 48,
                  color: Color(0xFF3D59A1),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Update Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                'A new version of RUNNR is available!\n\nCurrent: v$currentVersion\nLatest: v$latestVersion\n\nPlease update to continue using the app.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openReleasesPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D59A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Update Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
