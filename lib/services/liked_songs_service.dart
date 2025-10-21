import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';

class LikedSongsService {
  static const String _fileName = 'liked_songs.json';

  /// Get the file path for liked songs
  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final playlistsDir = Directory('${directory.path}/playlists');

    // Create directory if it doesn't exist
    if (!await playlistsDir.exists()) {
      await playlistsDir.create(recursive: true);
    }

    return File('${playlistsDir.path}/$_fileName');
  }

  /// Get all liked songs
  static Future<List<SongModel>> getLikedSongs() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      final List<dynamic> jsonData = json.decode(contents);

      return jsonData.map((item) => SongModel.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a song to liked songs
  static Future<void> addSong(SongModel song) async {
    try {
      final songs = await getLikedSongs();

      // Check if song already exists
      if (!songs.any((s) => s.encryptedMediaUrl == song.encryptedMediaUrl)) {
        songs.add(song);
        await _saveSongs(songs);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Remove a song from liked songs
  static Future<void> removeSong(SongModel song) async {
    try {
      final songs = await getLikedSongs();
      songs.removeWhere((s) => s.encryptedMediaUrl == song.encryptedMediaUrl);
      await _saveSongs(songs);
    } catch (e) {
      rethrow;
    }
  }

  /// Check if a song is liked
  static Future<bool> isLiked(SongModel song) async {
    try {
      final songs = await getLikedSongs();
      return songs.any((s) => s.encryptedMediaUrl == song.encryptedMediaUrl);
    } catch (e) {
      return false;
    }
  }

  /// Toggle like status of a song
  static Future<bool> toggleLike(SongModel song) async {
    try {
      final isCurrentlyLiked = await isLiked(song);

      if (isCurrentlyLiked) {
        await removeSong(song);
        return false;
      } else {
        await addSong(song);
        return true;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Save songs to file
  static Future<void> _saveSongs(List<SongModel> songs) async {
    try {
      final file = await _getFile();
      final jsonData = songs.map((song) => song.toJson()).toList();
      await file.writeAsString(json.encode(jsonData));
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all liked songs
  static Future<void> clearAll() async {
    try {
      await _saveSongs([]);
    } catch (e) {
      rethrow;
    }
  }

  /// Get count of liked songs
  static Future<int> getLikedCount() async {
    try {
      final songs = await getLikedSongs();
      return songs.length;
    } catch (e) {
      return 0;
    }
  }
}
