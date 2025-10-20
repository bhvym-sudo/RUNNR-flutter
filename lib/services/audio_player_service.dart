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
      print('🎵 Initializing Audio Service...');

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
          print('🎵 Song completed, triggering autoplay...');
          _handleSongCompletion();
        }
      });

      // Listen to track changes (for queue-based playback)
      _audioPlayer.currentIndexStream.listen((index) {
        if (index != null &&
            index != _currentIndex &&
            index < _playlist.length) {
          print('🎵 Track changed to index: $index');
          _currentIndex = index;
          _notifyUIAndUpdateNotification();
        }
      });

      _isInitialized = true;
      print('✅ Audio Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing audio service: $e');
    }
  }

  /// Play a song with optional playlist
  Future<void> playSong(
    SongModel song, {
    List<SongModel>? playlist,
    int? index,
  }) async {
    try {
      print('🎵 Playing song: ${song.title}');

      if (playlist != null && playlist.isNotEmpty) {
        // Playing with queue
        _playlist = playlist;
        _originalPlaylist = List.from(playlist);
        _currentIndex = index ?? 0;

        await _loadPlaylistAsQueue();
      } else {
        // Single song playback
        _playlist = [song];
        _originalPlaylist = [song];
        _currentIndex = 0;

        await _playSingleSong(song);
      }

      _notifyUIAndUpdateNotification();
    } catch (e) {
      print('❌ Error playing song: $e');
      rethrow;
    }
  }

  /// Load entire playlist as queue (enables autoplay)
  Future<void> _loadPlaylistAsQueue() async {
    try {
      print('🎵 Loading playlist with ${_playlist.length} songs...');
      final audioSources = <AudioSource>[];

      // Load stream URLs for all songs
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
              tag: song, // Attach song metadata
            ),
          );
        }
      }

      if (audioSources.isNotEmpty) {
        // Create concatenating source (queue)
        final concatenating = ConcatenatingAudioSource(children: audioSources);

        // Set audio source with initial index
        await _audioPlayer.setAudioSource(
          concatenating,
          initialIndex: _currentIndex,
          initialPosition: Duration.zero,
        );

        // Start playback
        await _audioPlayer.play();

        print('✅ Playlist loaded and playing');
      }
    } catch (e) {
      print('❌ Error loading playlist: $e');
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
    print(
      '🎵 Handling song completion. Current index: $_currentIndex, Playlist length: ${_playlist.length}',
    );

    // RepeatOne mode - loop current song
    if (_repeatMode == RepeatMode.one) {
      print('🔁 Repeat One: Looping current song');
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      return;
    }

    // Check if we can play next
    if (_audioPlayer.hasNext) {
      // Let just_audio handle it automatically
      print('⏭️ Auto-playing next song in queue');
      return;
    }

    // At end of queue
    if (_repeatMode == RepeatMode.playlist) {
      // Loop back to start
      print('🔁 Repeat Playlist: Looping to start');
      await _audioPlayer.seek(Duration.zero, index: 0);
      _currentIndex = 0;
      await _audioPlayer.play();
      _notifyUIAndUpdateNotification();
    } else {
      print('⏹️ Playlist ended');
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

    print('⏭️ Next button pressed');

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

    print('⏮️ Previous button pressed');

    if (_audioPlayer.hasPrevious) {
      await _audioPlayer.seekToPrevious();
      _currentIndex = _audioPlayer.currentIndex ?? _currentIndex;
      _notifyUIAndUpdateNotification();
    } else if (_repeatMode == RepeatMode.playlist) {
      // Wrap to end
      final lastIndex = _playlist.length - 1;
      await _audioPlayer.seek(Duration.zero, index: lastIndex);
      _currentIndex = lastIndex;
      _notifyUIAndUpdateNotification();
    }
  }

  /// Notify UI and update notification (centralized update method)
  void _notifyUIAndUpdateNotification() {
    final song = currentSong;
    if (song != null) {
      print('🔄 Updating UI and notification for: ${song.title}');

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
    print('🔁 Repeat mode changed to: $_repeatMode');
  }

  /// Toggle shuffle mode
  Future<void> toggleShuffleMode() async {
    _shuffleMode = !_shuffleMode;
    print('🔀 Shuffle mode: $_shuffleMode');

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
        print('✅ Queue rebuilt successfully');
      }
    } catch (e) {
      print('❌ Error rebuilding queue: $e');
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
    _playlist = newPlaylist;
    _originalPlaylist = List.from(newPlaylist);

    if (_currentIndex >= _playlist.length && _playlist.isNotEmpty) {
      _currentIndex = _playlist.length - 1;
    }
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
    print('🎵 AudioPlayerHandler created');

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
    print('🔔 Updating notification: ${song.title}');
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
    print('🎵 Notification: Play');
    await _service._audioPlayer.play();
  }

  @override
  Future<void> pause() async {
    print('⏸️ Notification: Pause');
    await _service._audioPlayer.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    print('⏩ Notification: Seek to $position');
    await _service._audioPlayer.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    print('⏭️ Notification: Skip to next');
    await _service.playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    print('⏮️ Notification: Skip to previous');
    await _service.playPrevious();
  }

  @override
  Future<void> stop() async {
    print('⏹️ Notification: Stop');
    await _service._audioPlayer.stop();
    await super.stop();
  }
}
