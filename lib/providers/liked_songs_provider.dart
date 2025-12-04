import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../services/liked_songs_service_hive.dart';
import 'player_provider.dart';

class LikedSongsProvider extends ChangeNotifier {
  List<SongModel> _likedSongs = [];
  bool _isLoading = false;
  PlayerProvider? _playerProvider;

  /// Set player provider reference for playlist synchronization
  void setPlayerProvider(PlayerProvider playerProvider) {
    _playerProvider = playerProvider;
  }

  /// Check if currently playing from liked songs playlist
  bool _isPlayingFromLikedSongs() {
    if (_playerProvider == null) return false;

    final currentSong = _playerProvider!.currentSong;
    final currentPlaylist = _playerProvider!.currentPlaylist;

    if (currentSong == null || currentPlaylist.isEmpty || _likedSongs.isEmpty) {
      return false;
    }

    // If current song is not in liked songs, definitely not playing from liked songs
    if (!_likedSongs.any(
      (s) => s.encryptedMediaUrl == currentSong.encryptedMediaUrl,
    )) {
      return false;
    }

    // Check if the playlists have similar structure (first few songs match)
    // This handles cases where user is playing from liked songs
    final checkCount = currentPlaylist.length < 3 ? currentPlaylist.length : 3;
    int matchCount = 0;

    for (int i = 0; i < checkCount && i < _likedSongs.length; i++) {
      if (currentPlaylist[i].encryptedMediaUrl ==
          _likedSongs[i].encryptedMediaUrl) {
        matchCount++;
      }
    }

    // If at least 2 out of first 3 songs match, consider it the same playlist
    return matchCount >= (checkCount >= 2 ? 2 : 1);
  }

  /// Update player's playlist if currently playing from liked songs
  void _syncWithPlayer() {
    if (_playerProvider != null && _isPlayingFromLikedSongs()) {
      _playerProvider!.updatePlaylist(_likedSongs);
    }
  }

  List<SongModel> get likedSongs => _likedSongs;
  bool get isLoading => _isLoading;
  int get count => _likedSongs.length;

  /// Load liked songs from storage
  Future<void> loadLikedSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      _likedSongs = await LikedSongsServiceHive.getLikedSongs();
    } catch (e) {
      // Failed to load liked songs
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if a song is liked
  bool isLiked(SongModel song) {
    return _likedSongs.any(
      (s) => s.encryptedMediaUrl == song.encryptedMediaUrl,
    );
  }

  /// Toggle like status of a song
  Future<bool> toggleLike(SongModel song) async {
    try {
      final isCurrentlyLiked = isLiked(song);

      if (isCurrentlyLiked) {
        await LikedSongsServiceHive.removeLikedSong(song);
        _likedSongs.removeWhere(
          (s) => s.encryptedMediaUrl == song.encryptedMediaUrl,
        );
      } else {
        await LikedSongsServiceHive.addLikedSong(song);
        _likedSongs.add(song);
      }

      // Sync with player if playing from liked songs
      _syncWithPlayer();

      notifyListeners();
      return !isCurrentlyLiked; // Return new like status
    } catch (e) {
      rethrow;
    }
  }

  /// Add a song to liked songs
  Future<void> addSong(SongModel song) async {
    if (!isLiked(song)) {
      try {
        await LikedSongsServiceHive.addLikedSong(song);
        _likedSongs.add(song);

        // Sync with player if playing from liked songs
        _syncWithPlayer();

        notifyListeners();
      } catch (e) {
        rethrow;
      }
    }
  }

  /// Remove a song from liked songs
  Future<void> removeSong(SongModel song) async {
    try {
      await LikedSongsServiceHive.removeLikedSong(song);
      _likedSongs.removeWhere(
        (s) => s.encryptedMediaUrl == song.encryptedMediaUrl,
      );

      // Sync with player if playing from liked songs
      _syncWithPlayer();

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all liked songs
  Future<void> clearAll() async {
    try {
      await LikedSongsServiceHive.clearAll();
      _likedSongs.clear();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
