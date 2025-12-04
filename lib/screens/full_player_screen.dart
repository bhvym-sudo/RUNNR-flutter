import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import '../providers/player_provider.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../constants/app_colors.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  Color _dominantColor = AppColors.accentColor;
  bool _isLoadingColor = false;
  String? _lastSongId; // Track last song to detect changes

  @override
  void initState() {
    super.initState();
    _extractDominantColor();
  }

  Future<void> _extractDominantColor() async {
    if (_isLoadingColor) return;
    _isLoadingColor = true;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentSong = playerProvider.currentSong;

    if (currentSong == null) {
      _isLoadingColor = false;
      return;
    }

    // Check if this is the same song
    if (_lastSongId == currentSong.encryptedMediaUrl) {
      _isLoadingColor = false;
      return;
    }

    // Update last song ID
    _lastSongId = currentSong.encryptedMediaUrl;

    try {
      final imageProvider = CachedNetworkImageProvider(
        currentSong.highQualityImage,
      );
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
      );

      if (mounted) {
        setState(() {
          _dominantColor =
              paletteGenerator.dominantColor?.color ?? AppColors.accentColor;
          _isLoadingColor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingColor = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadSong(BuildContext context, dynamic song) async {
    // Use a ValueNotifier to update progress across the async gap
    final progressNotifier = ValueNotifier<double>(0.0);
    final isDownloadingNotifier = ValueNotifier<bool>(true);

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ValueListenableBuilder<bool>(
        valueListenable: isDownloadingNotifier,
        builder: (context, isDownloading, child) {
          return ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (context, progress, child) {
              return Dialog(
                backgroundColor: const Color(0xFF1E202E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDownloading ? Icons.download : Icons.check_circle,
                        size: 48,
                        color: isDownloading
                            ? AppColors.accentColor
                            : Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isDownloading ? 'Downloading...' : 'Download Complete!',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isDownloading) ...[
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[800],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accentColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Saved to Downloads folder',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentColor,
                          ),
                          child: const Text('OK'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    // Start download
    await DownloadService.downloadSong(
      song,
      onProgress: (p) {
        progressNotifier.value = p;
      },
      onComplete: () {
        isDownloadingNotifier.value = false;
      },
      onError: (error) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red[900]),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentSong = playerProvider.currentSong;

    if (currentSong == null) {
      Navigator.of(context).pop();
      return const SizedBox.shrink();
    }

    // Check if song changed and update background color
    if (currentSong.encryptedMediaUrl != _lastSongId) {
      // Use post frame callback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _extractDominantColor();
      });
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show options menu
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _dominantColor,
              _dominantColor.withOpacity(0.5),
              Colors.black,
              Colors.black,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Album Art
                Expanded(
                  child: Center(
                    child: Hero(
                      tag: 'album_art_${currentSong.encryptedMediaUrl}',
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 400,
                          maxHeight: 400,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: currentSong.highQualityImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[900],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[900],
                              child: const Icon(
                                Icons.music_note,
                                size: 100,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Song Info
                Column(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentSong.subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Progress Bar
                    Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withOpacity(0.3),
                            thumbColor: Colors.white,
                            overlayColor: Colors.white.withOpacity(0.3),
                          ),
                          child: Slider(
                            value: playerProvider.duration.inMilliseconds > 0
                                ? playerProvider.position.inMilliseconds
                                      .toDouble()
                                      .clamp(
                                        0,
                                        playerProvider.duration.inMilliseconds
                                            .toDouble(),
                                      )
                                : 0,
                            max: playerProvider.duration.inMilliseconds > 0
                                ? playerProvider.duration.inMilliseconds
                                      .toDouble()
                                : 1,
                            onChanged: (value) {
                              playerProvider.seek(
                                Duration(milliseconds: value.toInt()),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(playerProvider.position),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatDuration(playerProvider.duration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Previous button
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          iconSize: 48,
                          color: playerProvider.hasPrevious
                              ? Colors.white
                              : Colors.white38,
                          onPressed: playerProvider.hasPrevious
                              ? () => playerProvider.playPrevious()
                              : null,
                        ),

                        // Play/Pause button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              playerProvider.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            iconSize: 48,
                            color: Colors.black,
                            onPressed: () => playerProvider.playPause(),
                          ),
                        ),

                        // Next button
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          iconSize: 48,
                          color: playerProvider.hasNext
                              ? Colors.white
                              : Colors.white38,
                          onPressed: playerProvider.hasNext
                              ? () => playerProvider.playNext()
                              : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Additional controls (Shuffle, Repeat, Download)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Shuffle button
                        IconButton(
                          icon: Icon(
                            playerProvider.shuffleMode
                                ? Icons.shuffle_on_rounded
                                : Icons.shuffle,
                          ),
                          color: playerProvider.shuffleMode
                              ? AppColors.accentColor
                              : Colors.white70,
                          iconSize: 28,
                          onPressed: () => playerProvider.toggleShuffleMode(),
                        ),

                        // Download button
                        IconButton(
                          icon: const Icon(Icons.download),
                          color: Colors.white70,
                          iconSize: 28,
                          onPressed: () => _downloadSong(context, currentSong),
                        ),

                        // Repeat button (3 states: off, playlist, one)
                        IconButton(
                          icon: Icon(
                            playerProvider.repeatMode == RepeatMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                          ),
                          color: playerProvider.repeatMode == RepeatMode.off
                              ? Colors.white70
                              : AppColors.accentColor,
                          iconSize: 28,
                          onPressed: () => playerProvider.toggleRepeatMode(),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
