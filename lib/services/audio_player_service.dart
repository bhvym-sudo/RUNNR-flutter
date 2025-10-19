import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song_model.dart';
import 'jiosaavn_service.dart';

enum RepeatMode {
  off, // No repeat
  playlist, // Repeat entire playlist
  one, // Repeat current song
}

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioPlayerHandler? _audioHandler;

  List<SongModel> _playlist = [];
  List<SongModel> _originalPlaylist = []; // For shuffle
  int _currentIndex = 0;
  bool _isInitialized = false;

  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffleMode = false;

  AudioPlayer get audioPlayer => _audioPlayer;
  List<SongModel> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  RepeatMode get repeatMode => _repeatMode;
  bool get shuffleMode => _shuffleMode;

  SongModel? get currentSong =>
      _playlist.isNotEmpty && _currentIndex < _playlist.length
      ? _playlist[_currentIndex]
      : null;

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<bool> get playingStream => _audioPlayer.playingStream;

  /// Initialize the audio service with notification support
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize audio handler for notifications
      _audioHandler = await AudioService.init(
        builder: () => AudioPlayerHandler(this),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.bhavyam.runnr_flutter.audio',
          androidNotificationChannelName: 'RUNNR Music',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );

      // Listen to player completion
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _onSongComplete();
        }
      });

      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }

  /// Play a song
  Future<void> playSong(
    SongModel song, {
    List<SongModel>? playlist,
    int? index,
  }) async {
    try {
      // Update playlist if provided
      if (playlist != null) {
        _playlist = playlist;
        _originalPlaylist = List.from(playlist);
        _currentIndex = index ?? 0;
      } else {
        // Single song playback
        _playlist = [song];
        _originalPlaylist = [song];
        _currentIndex = 0;
      }

      // Get stream URL
      final streamUrl = await JioSaavnService.getStreamUrl(
        song.encryptedMediaUrl,
      );

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('Could not get stream URL');
      }

      // Set audio source with headers (CRITICAL for JioSaavn)
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138 Safari/537.36',
            'Referer': 'https://www.jiosaavn.com/',
            'Origin': 'https://www.jiosaavn.com',
            'Accept': '*/*',
          },
        ),
      );

      // Update notification
      _updateNotification(song);

      await _audioPlayer.play();
    } catch (e) {
      print('Error playing song: $e');
      rethrow;
    }
  }

  /// Play or pause
  Future<void> playPause() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      print('Error toggling play/pause: $e');
    }
  }

  /// Play next song
  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await playSong(_playlist[_currentIndex]);
    } else if (_repeatMode == RepeatMode.playlist) {
      _currentIndex = 0;
      await playSong(_playlist[_currentIndex]);
    }
  }

  /// Play previous song
  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
      await playSong(_playlist[_currentIndex]);
    } else if (_repeatMode == RepeatMode.playlist) {
      _currentIndex = _playlist.length - 1;
      await playSong(_playlist[_currentIndex]);
    }
  }

  /// Handle song completion
  Future<void> _onSongComplete() async {
    if (_repeatMode == RepeatMode.one) {
      // Repeat current song
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } else {
      // Play next song (handles repeat playlist automatically)
      await playNext();
    }
  }

  /// Toggle repeat mode
  void toggleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.playlist;
        break;
      case RepeatMode.playlist:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
        break;
    }
    _updateLoopMode();
  }

  /// Toggle shuffle mode
  void toggleShuffleMode() {
    _shuffleMode = !_shuffleMode;

    if (_shuffleMode) {
      // Get current song
      final currentSong = _playlist[_currentIndex];

      // Shuffle remaining songs
      final remaining = List<SongModel>.from(_playlist);
      remaining.removeAt(_currentIndex);
      remaining.shuffle();

      // Rebuild playlist with current song first
      _playlist = [currentSong, ...remaining];
      _currentIndex = 0;
    } else {
      // Restore original order
      if (_originalPlaylist.isNotEmpty) {
        final currentSong = _playlist[_currentIndex];
        _playlist = List.from(_originalPlaylist);

        // Find current song in original playlist
        _currentIndex = _playlist.indexWhere(
          (song) => song.encryptedMediaUrl == currentSong.encryptedMediaUrl,
        );
        if (_currentIndex == -1) _currentIndex = 0;
      }
    }
  }

  /// Update loop mode on player
  void _updateLoopMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.playlist:
        _audioPlayer.setLoopMode(LoopMode.off); // Handled manually
        break;
      case RepeatMode.one:
        _audioPlayer.setLoopMode(LoopMode.one);
        break;
    }
  }

  /// Update notification metadata
  void _updateNotification(SongModel song) {
    _audioHandler?.setMediaItem(song);
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      print('Error seeking: $e');
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }

  /// Update playlist (useful when songs are liked/unliked)
  void updatePlaylist(List<SongModel> newPlaylist) {
    _playlist = newPlaylist;
    _originalPlaylist = List.from(newPlaylist);
    // Adjust current index if necessary
    if (_currentIndex >= _playlist.length && _playlist.isNotEmpty) {
      _currentIndex = _playlist.length - 1;
    }
  }

  /// Check if has next song
  bool get hasNext =>
      _playlist.isNotEmpty && _currentIndex < _playlist.length - 1;

  /// Check if has previous song
  bool get hasPrevious => _playlist.isNotEmpty && _currentIndex > 0;
}

/// Audio handler for background playback and notifications
class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayerService _service;

  AudioPlayerHandler(this._service) {
    // Listen to player state changes
    _service._audioPlayer.playbackEventStream.listen((event) {
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            _service._audioPlayer.playing
                ? MediaControl.pause
                : MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {MediaAction.seek},
          androidCompactActionIndices: const [0, 1, 2],
          playing: _service._audioPlayer.playing,
          updatePosition: _service._audioPlayer.position,
          bufferedPosition: _service._audioPlayer.bufferedPosition,
          speed: _service._audioPlayer.speed,
          queueIndex: 0,
        ),
      );
    });
  }

  void setMediaItem(SongModel song) {
    mediaItem.add(
      MediaItem(
        id: song.encryptedMediaUrl,
        title: song.title,
        artist: song.subtitle,
        artUri: Uri.parse(song.highQualityImage),
        duration: Duration(seconds: int.tryParse(song.duration) ?? 0),
      ),
    );
  }

  @override
  Future<void> play() => _service._audioPlayer.play();

  @override
  Future<void> pause() => _service._audioPlayer.pause();

  @override
  Future<void> seek(Duration position) => _service._audioPlayer.seek(position);

  @override
  Future<void> skipToNext() => _service.playNext();

  @override
  Future<void> skipToPrevious() => _service.playPrevious();

  @override
  Future<void> stop() async {
    await _service._audioPlayer.stop();
    await super.stop();
  }
}
