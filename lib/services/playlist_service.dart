import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';

/// Hive-based Playlist Service
/// Efficient storage for multiple playlists with CRUD operations
class PlaylistService {
  static const String _boxName = 'playlists';
  static Box? _box;
  static const _uuid = Uuid();

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
        if (value is Map) {
          result[key.toString()] = _convertMap(value);
        } else if (value is List) {
          result[key.toString()] = value.map((item) {
            if (item is Map) return _convertMap(item);
            return item;
          }).toList();
        } else {
          result[key.toString()] = value;
        }
      });
    }
    return result;
  }

  /// Get all playlists
  static Future<List<PlaylistModel>> getAllPlaylists() async {
    if (_box == null) await initialize();

    try {
      print('DEBUG: Box keys count: ${_box!.keys.length}');
      print('DEBUG: Box keys: ${_box!.keys.toList()}');

      final List<PlaylistModel> playlists = [];
      for (var key in _box!.keys) {
        final playlistMap = _box!.get(key);
        print('DEBUG: Key=$key, Data type=${playlistMap.runtimeType}');
        if (playlistMap != null) {
          final Map<String, dynamic> typedMap = _convertMap(playlistMap);
          playlists.add(PlaylistModel.fromJson(typedMap));
        }
      }

      // Sort by updated date (most recent first)
      playlists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return playlists;
    } catch (e) {
      return [];
    }
  }

  /// Get a specific playlist by ID
  static Future<PlaylistModel?> getPlaylist(String id) async {
    if (_box == null) await initialize();

    try {
      final playlistMap = _box!.get(id);
      if (playlistMap != null) {
        final Map<String, dynamic> typedMap = _convertMap(playlistMap);
        return PlaylistModel.fromJson(typedMap);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create a new playlist
  static Future<PlaylistModel> createPlaylist({
    required String name,
    String description = '',
    List<SongModel>? initialSongs,
  }) async {
    if (_box == null) await initialize();

    try {
      final now = DateTime.now();
      final playlist = PlaylistModel(
        id: _uuid.v4(),
        name: name,
        description: description,
        songs: initialSongs ?? [],
        createdAt: now,
        updatedAt: now,
      );

      final playlistData = playlist.toJson();
      await _box!.put(playlist.id, playlistData);
      await _box!.flush(); // Force write to disk
      return playlist;
    } catch (e) {
      rethrow;
    }
  }

  /// Update playlist (name, description, or cover)
  static Future<void> updatePlaylist(PlaylistModel playlist) async {
    if (_box == null) await initialize();

    try {
      final updatedPlaylist = playlist.copyWith(updatedAt: DateTime.now());
      final playlistData = updatedPlaylist.toJson();
      await _box!.put(updatedPlaylist.id, playlistData);
      await _box!.flush(); // Force write to disk
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a playlist
  static Future<void> deletePlaylist(String id) async {
    if (_box == null) await initialize();

    try {
      await _box!.delete(id);
      await _box!.flush(); // Force write to disk
    } catch (e) {
      rethrow;
    }
  }

  /// Add a song to playlist
  static Future<void> addSongToPlaylist(
    String playlistId,
    SongModel song,
  ) async {
    if (_box == null) await initialize();

    try {
      final playlist = await getPlaylist(playlistId);
      if (playlist == null) throw Exception('Playlist not found');

      // Check if song already exists
      final songExists = playlist.songs.any(
        (s) => s.encryptedMediaUrl == song.encryptedMediaUrl,
      );

      if (!songExists) {
        final updatedSongs = [...playlist.songs, song];
        final updatedPlaylist = playlist.copyWith(
          songs: updatedSongs,
          updatedAt: DateTime.now(),
        );
        final playlistData = updatedPlaylist.toJson();
        await _box!.put(playlistId, playlistData);
        await _box!.flush(); // Force write to disk
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Remove a song from playlist
  static Future<void> removeSongFromPlaylist(
    String playlistId,
    SongModel song,
  ) async {
    if (_box == null) await initialize();

    try {
      final playlist = await getPlaylist(playlistId);
      if (playlist == null) throw Exception('Playlist not found');

      final updatedSongs = playlist.songs
          .where((s) => s.encryptedMediaUrl != song.encryptedMediaUrl)
          .toList();

      final updatedPlaylist = playlist.copyWith(
        songs: updatedSongs,
        updatedAt: DateTime.now(),
      );
      final playlistData = updatedPlaylist.toJson();
      await _box!.put(playlistId, playlistData);
      await _box!.flush(); // Force write to disk
    } catch (e) {
      rethrow;
    }
  }

  /// Check if a song exists in a specific playlist
  static Future<bool> isSongInPlaylist(
    String playlistId,
    SongModel song,
  ) async {
    if (_box == null) await initialize();

    try {
      final playlist = await getPlaylist(playlistId);
      if (playlist == null) return false;

      return playlist.songs.any(
        (s) => s.encryptedMediaUrl == song.encryptedMediaUrl,
      );
    } catch (e) {
      return false;
    }
  }

  /// Get all playlists containing a specific song
  static Future<List<PlaylistModel>> getPlaylistsWithSong(
    SongModel song,
  ) async {
    if (_box == null) await initialize();

    try {
      final allPlaylists = await getAllPlaylists();
      return allPlaylists.where((playlist) {
        return playlist.songs.any(
          (s) => s.encryptedMediaUrl == song.encryptedMediaUrl,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Reorder songs in a playlist
  static Future<void> reorderSongs(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    if (_box == null) await initialize();

    try {
      final playlist = await getPlaylist(playlistId);
      if (playlist == null) throw Exception('Playlist not found');

      final songs = List<SongModel>.from(playlist.songs);
      final song = songs.removeAt(oldIndex);
      songs.insert(newIndex, song);

      final updatedPlaylist = playlist.copyWith(
        songs: songs,
        updatedAt: DateTime.now(),
      );
      await _box!.put(playlistId, updatedPlaylist.toJson());
    } catch (e) {
      rethrow;
    }
  }

  /// Get playlist count
  static int getPlaylistCount() {
    if (_box == null) return 0;
    return _box!.length;
  }

  /// Clear all playlists (use with caution)
  static Future<void> clearAll() async {
    if (_box == null) await initialize();

    try {
      await _box!.clear();
    } catch (e) {
      rethrow;
    }
  }
}
