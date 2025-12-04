import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Service to check for app updates
class VersionCheckService {
  // Use GitHub API instead of raw URL for instant updates (no CDN cache)
  static const String _versionUrl =
      'https://api.github.com/repos/bhvym-sudo/RUNNR-flutter/contents/version.txt';

  /// Get current app version
  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return '2.0.0'; // Fallback to current version
    }
  }

  /// Fetch latest version from GitHub API (instant, no cache)
  static Future<String?> getLatestVersion() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$_versionUrl?ref=main&t=$timestamp');

      print('Fetching from GitHub API: $url');

      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // GitHub API returns base64 encoded content
        final jsonData = json.decode(response.body);
        final base64Content = jsonData['content'] as String;
        // Remove newlines from base64 string
        final cleanBase64 = base64Content.replaceAll('\n', '');
        final decodedBytes = base64.decode(cleanBase64);
        final version = utf8.decode(decodedBytes).trim();
        print('Decoded version from GitHub API: $version');
        return version;
      } else {
        print('HTTP error: ${response.statusCode}');
      }
      return null;
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
