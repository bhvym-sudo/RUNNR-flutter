import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../services/audio_player_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  PlayerProvider() {
    _init();
  }

  void _init() {
    _audioService.initialize();

    // Listen to player state changes
    _audioService.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    _audioService.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

    _audioService.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    // Listen to current song changes
    _audioService.currentSongStream.listen((song) {
      // Notify listeners when song changes (for UI updates like background color)
      notifyListeners();
    });
  }

  // Getters
  SongModel? get currentSong => _audioService.currentSong;
  List<SongModel> get currentPlaylist => _audioService.playlist;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get hasNext => _audioService.hasNext;
  bool get hasPrevious => _audioService.hasPrevious;
  int get currentIndex => _audioService.currentIndex;
  RepeatMode get repeatMode => _audioService.repeatMode;
  bool get shuffleMode => _audioService.shuffleMode;

  /// Play a song
  Future<void> playSong(
    SongModel song, {
    List<SongModel>? playlist,
    int? index,
  }) async {
    try {
      await _audioService.playSong(song, playlist: playlist, index: index);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Play or pause
  Future<void> playPause() async {
    await _audioService.playPause();
  }

  /// Play next song
  Future<void> playNext() async {
    await _audioService.playNext();
    notifyListeners();
  }

  /// Play previous song
  Future<void> playPrevious() async {
    await _audioService.playPrevious();
    notifyListeners();
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioService.stop();
    notifyListeners();
  }

  /// Update playlist when songs are liked/unliked
  void updatePlaylist(List<SongModel> newPlaylist) {
    _audioService.updatePlaylist(newPlaylist);
    notifyListeners();
  }

  /// Toggle repeat mode
  void toggleRepeatMode() {
    _audioService.toggleRepeatMode();
    notifyListeners();
  }

  /// Toggle shuffle mode
  Future<void> toggleShuffleMode() async {
    await _audioService.toggleShuffleMode();
    notifyListeners();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
