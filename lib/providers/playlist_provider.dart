import 'package:flutter/foundation.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/playlist_service.dart';
import 'player_provider.dart';

class PlaylistProvider extends ChangeNotifier {
  List<PlaylistModel> _playlists = [];
  bool _isLoading = false;
  PlayerProvider? _playerProvider;

  List<PlaylistModel> get playlists => _playlists;
  bool get isLoading => _isLoading;
  int get count => _playlists.length;

  /// Set player provider reference for playlist synchronization
  void setPlayerProvider(PlayerProvider playerProvider) {
    _playerProvider = playerProvider;
  }

  /// Load all playlists from storage
  Future<void> loadPlaylists() async {
    _isLoading = true;
    notifyListeners();

    try {
      _playlists = await PlaylistService.getAllPlaylists();
    } catch (e) {
      // Failed to load playlists
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a specific playlist by ID
  Future<PlaylistModel?> getPlaylist(String id) async {
    try {
      return await PlaylistService.getPlaylist(id);
    } catch (e) {
      return null;
    }
  }

  /// Create a new playlist
  Future<PlaylistModel?> createPlaylist({
    required String name,
    String description = '',
    List<SongModel>? initialSongs,
  }) async {
    try {
      final playlist = await PlaylistService.createPlaylist(
        name: name,
        description: description,
        initialSongs: initialSongs,
      );

      _playlists.insert(0, playlist);
      notifyListeners();
      return playlist;
    } catch (e) {
      rethrow;
    }
  }

  /// Update playlist details (name, description)
  Future<void> updatePlaylist(PlaylistModel playlist) async {
    try {
      await PlaylistService.updatePlaylist(playlist);

      // Update in local list
      final index = _playlists.indexWhere((p) => p.id == playlist.id);
      if (index != -1) {
        _playlists[index] = playlist;

        // Sync with player if currently playing from this playlist
        _syncPlaylistWithPlayer(playlist);

        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a playlist
  Future<void> deletePlaylist(String id) async {
    try {
      await PlaylistService.deletePlaylist(id);
      _playlists.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Add a song to a playlist
  Future<void> addSongToPlaylist(String playlistId, SongModel song) async {
    try {
      await PlaylistService.addSongToPlaylist(playlistId, song);

      // Reload the specific playlist
      final updatedPlaylist = await PlaylistService.getPlaylist(playlistId);
      if (updatedPlaylist != null) {
        final index = _playlists.indexWhere((p) => p.id == playlistId);
        if (index != -1) {
          _playlists[index] = updatedPlaylist;

          // Sync with player if currently playing from this playlist
          _syncPlaylistWithPlayer(updatedPlaylist);

          notifyListeners();
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Remove a song from a playlist
  Future<void> removeSongFromPlaylist(String playlistId, SongModel song) async {
    try {
      await PlaylistService.removeSongFromPlaylist(playlistId, song);

      // Reload the specific playlist
      final updatedPlaylist = await PlaylistService.getPlaylist(playlistId);
      if (updatedPlaylist != null) {
        final index = _playlists.indexWhere((p) => p.id == playlistId);
        if (index != -1) {
          _playlists[index] = updatedPlaylist;

          // Sync with player if currently playing from this playlist
          _syncPlaylistWithPlayer(updatedPlaylist);

          notifyListeners();
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Check if a song is in a specific playlist
  Future<bool> isSongInPlaylist(String playlistId, SongModel song) async {
    try {
      return await PlaylistService.isSongInPlaylist(playlistId, song);
    } catch (e) {
      return false;
    }
  }

  /// Get all playlists containing a specific song
  Future<List<PlaylistModel>> getPlaylistsWithSong(SongModel song) async {
    try {
      return await PlaylistService.getPlaylistsWithSong(song);
    } catch (e) {
      return [];
    }
  }

  /// Reorder songs in a playlist
  Future<void> reorderSongs(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    try {
      await PlaylistService.reorderSongs(playlistId, oldIndex, newIndex);

      // Reload the specific playlist
      final updatedPlaylist = await PlaylistService.getPlaylist(playlistId);
      if (updatedPlaylist != null) {
        final index = _playlists.indexWhere((p) => p.id == playlistId);
        if (index != -1) {
          _playlists[index] = updatedPlaylist;

          // Sync with player if currently playing from this playlist
          _syncPlaylistWithPlayer(updatedPlaylist);

          notifyListeners();
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Sync playlist with player if currently playing from it
  void _syncPlaylistWithPlayer(PlaylistModel playlist) {
    if (_playerProvider == null) return;

    final currentSong = _playerProvider!.currentSong;
    final currentPlaylist = _playerProvider!.currentPlaylist;

    if (currentSong == null || currentPlaylist.isEmpty) return;

    // Check if current song is in this playlist
    final isPlayingFromThisPlaylist = playlist.songs.any(
      (s) => s.encryptedMediaUrl == currentSong.encryptedMediaUrl,
    );

    if (isPlayingFromThisPlaylist) {
      // Check if first few songs match (similar to liked songs logic)
      final checkCount = currentPlaylist.length < 3
          ? currentPlaylist.length
          : 3;
      int matchCount = 0;

      for (int i = 0; i < checkCount && i < playlist.songs.length; i++) {
        if (i < currentPlaylist.length &&
            currentPlaylist[i].encryptedMediaUrl ==
                playlist.songs[i].encryptedMediaUrl) {
          matchCount++;
        }
      }

      // If playing from this playlist, update player's queue
      if (matchCount >= (checkCount >= 2 ? 2 : 1)) {
        _playerProvider!.updatePlaylist(playlist.songs);
      }
    }
  }

  /// Clear all playlists
  Future<void> clearAll() async {
    try {
      await PlaylistService.clearAll();
      _playlists.clear();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
