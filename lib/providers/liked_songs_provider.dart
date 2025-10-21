import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../services/liked_songs_service.dart';

class LikedSongsProvider extends ChangeNotifier {
  List<SongModel> _likedSongs = [];
  bool _isLoading = false;

  List<SongModel> get likedSongs => _likedSongs;
  bool get isLoading => _isLoading;
  int get count => _likedSongs.length;

  /// Load liked songs from storage
  Future<void> loadLikedSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      _likedSongs = await LikedSongsService.getLikedSongs();
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
        await LikedSongsService.removeSong(song);
        _likedSongs.removeWhere(
          (s) => s.encryptedMediaUrl == song.encryptedMediaUrl,
        );
      } else {
        await LikedSongsService.addSong(song);
        _likedSongs.add(song);
      }

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
        await LikedSongsService.addSong(song);
        _likedSongs.add(song);
        notifyListeners();
      } catch (e) {
        rethrow;
      }
    }
  }

  /// Remove a song from liked songs
  Future<void> removeSong(SongModel song) async {
    try {
      await LikedSongsService.removeSong(song);
      _likedSongs.removeWhere(
        (s) => s.encryptedMediaUrl == song.encryptedMediaUrl,
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all liked songs
  Future<void> clearAll() async {
    try {
      await LikedSongsService.clearAll();
      _likedSongs.clear();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
