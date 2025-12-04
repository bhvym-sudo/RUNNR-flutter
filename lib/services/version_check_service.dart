import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Service to check for app updates
class VersionCheckService {
  static const String _versionUrl =
      'https://raw.githubusercontent.com/bhvym-sudo/RUNNR-flutter/main/version.txt';

  /// Get current app version
  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return '2.0.0'; // Fallback to current version
    }
  }

  /// Fetch latest version from GitHub
  static Future<String?> getLatestVersion() async {
    try {
      // Add cache-busting query parameter with random value
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = DateTime.now().microsecondsSinceEpoch;
      final url = Uri.parse('$_versionUrl?cache=$timestamp&r=$random');

      print('Fetching from URL: $url');

      // Create a fresh client to avoid caching
      final client = http.Client();
      try {
        final response = await client
            .get(
              url,
              headers: {
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final version = response.body.trim();
          print('Fetched version from GitHub: $version');
          print('Response length: ${response.body.length}');
          return version;
        } else {
          print('HTTP error: ${response.statusCode}');
        }
        return null;
      } finally {
        client.close();
      }
    } catch (e) {
      print('Error fetching version: $e');
      return null;
    }
  }

  /// Check if update is required
  static Future<bool> isUpdateRequired() async {
    try {
      final currentVersion = await getCurrentVersion();
      final latestVersion = await getLatestVersion();

      print('DEBUG VERSION CHECK:');
      print('Current version: $currentVersion');
      print('Latest version: $latestVersion');

      if (latestVersion == null) {
        print('Latest version is null, no update required');
        return false;
      }

      final comparison = _compareVersions(currentVersion, latestVersion);
      print('Version comparison result: $comparison');
      print('Update required: ${comparison < 0}');

      return comparison < 0;
    } catch (e) {
      print('Error checking update: $e');
      return false;
    }
  }

  /// Compare two version strings (e.g., "1.0.0" vs "2.0.0")
  /// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final part1 = i < v1Parts.length ? v1Parts[i] : 0;
      final part2 = i < v2Parts.length ? v2Parts[i] : 0;

      if (part1 < part2) return -1;
      if (part1 > part2) return 1;
    }

    return 0;
  }
}
