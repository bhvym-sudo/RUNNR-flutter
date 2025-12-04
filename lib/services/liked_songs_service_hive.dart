import 'package:hive_flutter/hive_flutter.dart';
import '../models/song_model.dart';

/// Hive-based Liked Songs Service
/// Much faster and more efficient than JSON for frequent read/write operations
class LikedSongsServiceHive {
  static const String _boxName = 'liked_songs';
  static Box? _box;

  /// Initialize Hive
  static Future<void> initialize() async {
    if (_box != null) return;
    _box = await Hive.openBox(_boxName);
  }

  /// Deep convert dynamic map to Map<String, dynamic>
  static Map<String, dynamic> _convertMap(dynamic map) {
    if (map is Map<String, dynamic>) return map;

    final Map<String, dynamic> result = {};
    if (map is Map) {
      map.forEach((key, value) {
        result[key.toString()] = value;
      });
    }
    return result;
  }

  /// Get all liked songs
  static Future<List<SongModel>> getLikedSongs() async {
    if (_box == null) await initialize();

    try {
      final List<SongModel> songs = [];
      for (var key in _box!.keys) {
        final songMap = _box!.get(key);
        if (songMap != null) {
          final Map<String, dynamic> typedMap = _convertMap(songMap);
          songs.add(SongModel.fromJson(typedMap));
        }
      }

      // Return in reverse order (most recently liked first)
      return songs.reversed.toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a song to liked songs
  static Future<void> addLikedSong(SongModel song) async {
    if (_box == null) await initialize();

    try {
      // Use encrypted media URL as unique key
      final songData = song.toJson();
      await _box!.put(song.encryptedMediaUrl, songData);
      await _box!.flush(); // Force write to disk
    } catch (e) {
      rethrow;
    }
  }

  /// Remove a song from liked songs
  static Future<void> removeLikedSong(SongModel song) async {
    if (_box == null) await initialize();

    try {
      await _box!.delete(song.encryptedMediaUrl);
      await _box!.flush(); // Force write to disk
    } catch (e) {
      rethrow;
    }
  }

  /// Check if a song is liked
  static Future<bool> isLiked(SongModel song) async {
    if (_box == null) await initialize();

    try {
      return _box!.containsKey(song.encryptedMediaUrl);
    } catch (e) {
      return false;
    }
  }

  /// Clear all liked songs
  static Future<void> clearAll() async {
    if (_box == null) await initialize();

    try {
      await _box!.clear();
      await _box!.flush(); // Force write to disk
    } catch (e) {
      rethrow;
    }
  }

  /// Get count of liked songs (faster than loading all)
  static int getLikedCount() {
    if (_box == null) return 0;
    return _box!.length;
  }
}
