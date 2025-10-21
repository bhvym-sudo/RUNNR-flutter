import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';

class JioSaavnService {
  static const String _baseUrl = 'https://www.jiosaavn.com/api.php';

  // Headers as per the Android app
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138 Safari/537.36',
    'Referer': 'https://www.jiosaavn.com/',
    'Origin': 'https://www.jiosaavn.com',
    'Accept': 'application/json',
    'Connection': 'keep-alive',
  };

  /// Search for songs on JioSaavn
  static Future<List<SongModel>> searchSongs(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        '$_baseUrl?p=1&q=$encodedQuery&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=20&__call=search.getResults',
      );

      final response = await http.get(
        url,
        headers: {
          ..._headers,
          'Referer': 'https://www.jiosaavn.com/search/song/$query',
        },
      );

      if (response.statusCode == 200) {
        // Clean the response (JioSaavn sometimes returns with )}]', prefix)
        String responseBody = response.body;
        if (responseBody.startsWith(")]}',")) {
          responseBody = responseBody.substring(5);
        } else if (responseBody.startsWith(")]}'")) {
          responseBody = responseBody.substring(4);
        }

        final jsonData = json.decode(responseBody);
        final results = jsonData['results'] as List?;

        if (results != null) {
          return results
              .map((item) => SongModel.fromJson(item))
              .where((song) => song.encryptedMediaUrl.isNotEmpty)
              .toList();
        }
      } else {
        throw Exception('Failed to search songs: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
    return [];
  }

  /// Get streaming URL from encrypted media URL
  static Future<String?> getStreamUrl(String encryptedMediaUrl) async {
    try {
      final encodedUrl = Uri.encodeComponent(encryptedMediaUrl);
      final url = Uri.parse(
        '$_baseUrl?__call=song.generateAuthToken&url=$encodedUrl&bitrate=320&api_version=4&_format=json&ctx=web6dot0&_marker=0',
      );

      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        // Clean the response (JioSaavn sometimes returns with )}]', prefix)
        String responseBody = response.body;
        if (responseBody.startsWith(")]}',")) {
          responseBody = responseBody.substring(5);
        } else if (responseBody.startsWith(")]}'")) {
          responseBody = responseBody.substring(4);
        }

        final jsonData = json.decode(responseBody);
        final authUrl = jsonData['auth_url'] as String?;

        // Ensure HTTPS
        if (authUrl != null && authUrl.startsWith('http://')) {
          return authUrl.replaceFirst('http://', 'https://');
        }

        return authUrl;
      } else {
        throw Exception('Failed to get stream URL: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get trending songs (using search with popular terms)
  static Future<List<SongModel>> getTrendingSongs() async {
    try {
      // Using popular search terms to get trending content
      return await searchSongs('trending hindi');
    } catch (e) {
      return [];
    }
  }

  /// Get songs by album or playlist ID (optional feature)
  static Future<List<SongModel>> getAlbumSongs(String albumId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?__call=content.getAlbumDetails&albumid=$albumId&api_version=4&_format=json&ctx=web6dot0&_marker=0',
      );

      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final songs = jsonData['songs'] as List?;

        if (songs != null) {
          return songs
              .map((item) => SongModel.fromJson(item))
              .where((song) => song.encryptedMediaUrl.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      // Error getting album songs
    }
    return [];
  }
}
