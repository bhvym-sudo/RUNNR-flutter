import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song_model.dart';
import 'jiosaavn_service.dart';

/// Repeat modes for playback
enum RepeatMode {
  off, // No repeat
  playlist, // Repeat entire playlist
  one, // Repeat current song
}

/// Main Audio Player Service - Singleton
/// Manages playback, queue, and notification
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  // Core components
  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioPlayerHandler? _audioHandler;

  // Playlist management
  List<SongModel> _playlist = [];
  List<SongModel> _originalPlaylist = [];
  int _currentIndex = 0;

  // Player state
  bool _isInitialized = false;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffleMode = false;

  // Public getters
  AudioPlayer get audioPlayer => _audioPlayer;
  List<SongModel> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  RepeatMode get repeatMode => _repeatMode;
  bool get shuffleMode => _shuffleMode;

  SongModel? get currentSong =>
      _playlist.isNotEmpty &&
          _currentIndex >= 0 &&
          _currentIndex < _playlist.length
      ? _playlist[_currentIndex]
      : null;

  // Streams for UI binding
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<bool> get playingStream => _audioPlayer.playingStream;

  // Stream for current song changes (for UI updates)
  final _currentSongController = StreamController<SongModel?>.broadcast();
  Stream<SongModel?> get currentSongStream => _currentSongController.stream;

  /// Initialize audio service with notification support
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize audio handler for background playback & notifications
      _audioHandler = await AudioService.init(
        builder: () => AudioPlayerHandler(this),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.bhavyam.runnr_flutter.audio',
          androidNotificationChannelName: 'RUNNR Music',
          androidNotificationChannelDescription: 'Music playback controls',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          androidNotificationIcon: 'drawable/ic_notification',
        ),
      );

      // Listen to playback completion for autoplay
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _handleSongCompletion();
        }
      });

      // Listen to track changes (for queue-based playback)
      _audioPlayer.currentIndexStream.listen((index) {
        if (index != null &&
            index != _currentIndex &&
            index < _playlist.length) {
          _currentIndex = index;
          _notifyUIAndUpdateNotification();
        }
      });

      _isInitialized = true;
    } catch (e) {
      // Initialization failed
    }
  }

  /// Play a song with optional playlist
  Future<void> playSong(
    SongModel song, {
    List<SongModel>? playlist,
    int? index,
  }) async {
    try {
      // Update state immediately for instant UI feedback
      if (playlist != null && playlist.isNotEmpty) {
        // CRITICAL: Create a COPY of the playlist to avoid reference issues
        // If we don't copy, modifications to the original list (like unliking songs)
        // will directly modify our _playlist, causing wrong song details to show
        _playlist = List.from(playlist);
        _originalPlaylist = List.from(playlist);
        _currentIndex = index ?? 0;
      } else {
        _playlist = [song];
        _originalPlaylist = [song];
        _currentIndex = 0;
      }

      // Notify UI immediately (before loading)
      _notifyUIAndUpdateNotification();

      // Now load and play
      if (playlist != null && playlist.isNotEmpty) {
        await _loadPlaylistAsQueue();
      } else {
        await _playSingleSong(song);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Load entire playlist as queue (enables autoplay)
  Future<void> _loadPlaylistAsQueue() async {
    try {
      final audioSources = <AudioSource>[];

      // Load stream URLs for all songs in order
      for (var i = 0; i < _playlist.length; i++) {
        final song = _playlist[i];
        final streamUrl = await JioSaavnService.getStreamUrl(
          song.encryptedMediaUrl,
        );

        if (streamUrl != null && streamUrl.isNotEmpty) {
          audioSources.add(
            AudioSource.uri(
              Uri.parse(streamUrl),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': 'https://www.jiosaavn.com/',
                'Origin': 'https://www.jiosaavn.com',
                'Accept': '*/*',
              },
              tag: song,
            ),
          );
        }
      }

      if (audioSources.isNotEmpty) {
        // Create concatenating source (queue)
        final concatenating = ConcatenatingAudioSource(children: audioSources);

        // Make sure currentIndex is valid
        final validIndex = _currentIndex.clamp(0, audioSources.length - 1);

        // Set audio source with correct initial index
        await _audioPlayer.setAudioSource(
          concatenating,
          initialIndex: validIndex,
          initialPosition: Duration.zero,
        );

        // Start playback
        await _audioPlayer.play();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Play a single song
  Future<void> _playSingleSong(SongModel song) async {
    final streamUrl = await JioSaavnService.getStreamUrl(
      song.encryptedMediaUrl,
    );

    if (streamUrl == null || streamUrl.isEmpty) {
      throw Exception('Could not get stream URL');
    }

    await _audioPlayer.setAudioSource(
      AudioSource.uri(
        Uri.parse(streamUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://www.jiosaavn.com/',
          'Origin': 'https://www.jiosaavn.com',
          'Accept': '*/*',
        },
        tag: song,
      ),
    );

    await _audioPlayer.play();
  }

  /// Handle song completion for autoplay
  Future<void> _handleSongCompletion() async {
    // RepeatOne mode - loop current song
    if (_repeatMode == RepeatMode.one) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      return;
    }

    // Check if we can play next
    if (_audioPlayer.hasNext) {
      // Let just_audio handle it automatically
      return;
    }

    // At end of queue
    if (_repeatMode == RepeatMode.playlist) {
      // Loop back to start
      await _audioPlayer.seek(Duration.zero, index: 0);
      _currentIndex = 0;
      await _audioPlayer.play();
      _notifyUIAndUpdateNotification();
    }
  }

  /// Play/Pause toggle
  Future<void> playPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  /// Play next song
  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    print(
      '⏭️ Next button pressed. Repeat: $_repeatMode, Shuffle: $_shuffleMode',
    );

    // If repeat one is enabled, just restart the current song
    if (_repeatMode == RepeatMode.one) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      return;
    }

    if (_audioPlayer.hasNext) {
      await _audioPlayer.seekToNext();
      _currentIndex = _audioPlayer.currentIndex ?? _currentIndex;
      _notifyUIAndUpdateNotification();
    } else if (_repeatMode == RepeatMode.playlist) {
      // Wrap to beginning
      await _audioPlayer.seek(Duration.zero, index: 0);
      _currentIndex = 0;
      _notifyUIAndUpdateNotification();
    }
  }

  /// Play previous song
  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    // Check current position
    final currentPosition = _audioPlayer.position;

    // If played for more than 5 seconds, restart current song
    if (currentPosition.inSeconds >= 5) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    // If played for less than 5 seconds, go to actual previous song
    if (_currentIndex > 0) {
      // There's a previous song, go to it
      _currentIndex--;
      await _audioPlayer.seek(Duration.zero, index: _currentIndex);
      _notifyUIAndUpdateNotification();
    } else {
      // At first song, wrap to last song
      final lastIndex = _playlist.length - 1;
      _currentIndex = lastIndex;
      await _audioPlayer.seek(Duration.zero, index: lastIndex);
      _notifyUIAndUpdateNotification();
    }
  }

  /// Notify UI and update notification (centralized update method)
  void _notifyUIAndUpdateNotification() {
    final song = currentSong;
    if (song != null) {
      // Update notification
      _audioHandler?.setMediaItem(song);

      // Notify UI listeners
      _currentSongController.add(song);
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
  Future<void> toggleShuffleMode() async {
    _shuffleMode = !_shuffleMode;

    // Get current song and position
    final currentSong = _playlist[_currentIndex];
    final currentPosition = _audioPlayer.position;

    if (_shuffleMode) {
      // Shuffle playlist
      final remaining = List<SongModel>.from(_playlist);
      remaining.removeAt(_currentIndex);
      remaining.shuffle();

      _playlist = [currentSong, ...remaining];
      _currentIndex = 0;
    } else {
      // Restore original order
      if (_originalPlaylist.isNotEmpty) {
        _playlist = List.from(_originalPlaylist);

        _currentIndex = _playlist.indexWhere(
          (song) => song.encryptedMediaUrl == currentSong.encryptedMediaUrl,
        );
        if (_currentIndex == -1) _currentIndex = 0;
      }
    }

    // Rebuild the queue with new order
    print(
      '🔄 Rebuilding queue in ${_shuffleMode ? "shuffled" : "original"} order...',
    );
    await _rebuildQueueFromCurrentPosition(currentPosition);
  }

  /// Rebuild the audio queue with current playlist order
  Future<void> _rebuildQueueFromCurrentPosition(Duration position) async {
    try {
      final audioSources = <AudioSource>[];

      // Load stream URLs for all songs in current order
      for (var song in _playlist) {
        final streamUrl = await JioSaavnService.getStreamUrl(
          song.encryptedMediaUrl,
        );

        if (streamUrl != null && streamUrl.isNotEmpty) {
          audioSources.add(
            AudioSource.uri(
              Uri.parse(streamUrl),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': 'https://www.jiosaavn.com/',
                'Origin': 'https://www.jiosaavn.com',
                'Accept': '*/*',
              },
              tag: song,
            ),
          );
        }
      }

      if (audioSources.isNotEmpty) {
        // Create new concatenating source with shuffled/original order
        final concatenating = ConcatenatingAudioSource(children: audioSources);

        // Set the new queue, starting at current index and position
        await _audioPlayer.setAudioSource(
          concatenating,
          initialIndex: _currentIndex,
          initialPosition: position,
        );

        // Resume playback if it was playing
        if (_audioPlayer.playing) {
          await _audioPlayer.play();
        }

        _notifyUIAndUpdateNotification();
      }
    } catch (e) {
      // Error rebuilding queue
    }
  }

  /// Update loop mode on player
  void _updateLoopMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.playlist:
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.one:
        _audioPlayer.setLoopMode(LoopMode.one);
        break;
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// Update playlist (when songs are liked/unliked)
  void updatePlaylist(List<SongModel> newPlaylist) {
    // Store the currently playing song
    final currentlyPlayingSong = currentSong;

    _playlist = newPlaylist;
    _originalPlaylist = List.from(newPlaylist);

    // Find the index of the currently playing song in the new playlist
    if (currentlyPlayingSong != null) {
      final newIndex = _playlist.indexWhere(
        (song) =>
            song.encryptedMediaUrl == currentlyPlayingSong.encryptedMediaUrl,
      );

      if (newIndex != -1) {
        // Song is still in the playlist
        _currentIndex = newIndex;
      } else {
        // Song was removed from playlist
        // Adjust current index if needed
        if (_currentIndex >= _playlist.length && _playlist.isNotEmpty) {
          _currentIndex = _playlist.length - 1;
        } else if (_playlist.isEmpty) {
          _currentIndex = 0;
        }
      }
    } else {
      // No current song, adjust index if needed
      if (_currentIndex >= _playlist.length && _playlist.isNotEmpty) {
        _currentIndex = _playlist.length - 1;
      }
    }

    // Notify UI of the update (important!)
    _notifyUIAndUpdateNotification();
  }

  /// Check if has next song
  bool get hasNext {
    if (_playlist.length <= 1) return false;
    return _audioPlayer.hasNext || _repeatMode == RepeatMode.playlist;
  }

  /// Check if has previous song
  bool get hasPrevious {
    if (_playlist.length <= 1) return false;
    return _audioPlayer.hasPrevious || _repeatMode == RepeatMode.playlist;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await _currentSongController.close();
  }
}

/// Audio Handler for background playback and notifications
class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayerService _service;

  AudioPlayerHandler(this._service) {
    // Initialize playback state
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );

    // Listen to player events and update playback state
    _service._audioPlayer.playbackEventStream.listen(_updatePlaybackState);
  }

  /// Update playback state based on player events
  void _updatePlaybackState(PlaybackEvent event) {
    final playing = _service._audioPlayer.playing;
    final processingState = _mapProcessingState(
      _service._audioPlayer.processingState,
    );

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: playing,
        updatePosition: _service._audioPlayer.position,
        bufferedPosition: _service._audioPlayer.bufferedPosition,
        speed: _service._audioPlayer.speed,
        queueIndex: _service._currentIndex,
      ),
    );
  }

  /// Map just_audio processing state to audio_service processing state
  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Update media item (notification metadata)
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

  // Override media controls
  @override
  Future<void> play() async {
    await _service._audioPlayer.play();
  }

  @override
  Future<void> pause() async {
    await _service._audioPlayer.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _service._audioPlayer.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _service.playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _service.playPrevious();
  }

  @override
  Future<void> stop() async {
    await _service._audioPlayer.stop();
    await super.stop();
  }
}
