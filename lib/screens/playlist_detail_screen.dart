import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../models/playlist_model.dart';
import '../widgets/song_tile.dart';
import '../widgets/screen_with_mini_player.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  PlaylistModel? _playlist;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    final playlistProvider = Provider.of<PlaylistProvider>(
      context,
      listen: false,
    );
    final playlist = await playlistProvider.getPlaylist(widget.playlistId);

    if (mounted) {
      setState(() {
        _playlist = playlist;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ScreenWithMiniPlayer(
        appBar: AppBar(backgroundColor: const Color(0xFF0A0A0D)),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF3D59A1)),
        ),
      );
    }

    if (_playlist == null) {
      return ScreenWithMiniPlayer(
        appBar: AppBar(backgroundColor: const Color(0xFF0A0A0D)),
        child: const Center(
          child: Text(
            'Playlist not found',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final playerProvider = Provider.of<PlayerProvider>(context);
    final playlistProvider = Provider.of<PlaylistProvider>(context);

    return ScreenWithMiniPlayer(
      child: CustomScrollView(
        slivers: [
          // App Bar with Playlist Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0D),
            flexibleSpace: FlexibleSpaceBar(background: _buildPlaylistHeader()),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) =>
                    _handleMenuAction(value, playlistProvider),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Edit Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Delete Playlist',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Playlist Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Play All Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _playlist!.songs.isEmpty
                          ? null
                          : () {
                              playerProvider.playSong(
                                _playlist!.songs.first,
                                playlist: _playlist!.songs,
                                index: 0,
                              );
                            },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D59A1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Shuffle Button
                  ElevatedButton.icon(
                    onPressed: _playlist!.songs.isEmpty
                        ? null
                        : () async {
                            // Enable shuffle and play
                            if (!playerProvider.shuffleMode) {
                              await playerProvider.toggleShuffleMode();
                            }
                            playerProvider.playSong(
                              _playlist!.songs.first,
                              playlist: _playlist!.songs,
                              index: 0,
                            );
                          },
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Shuffle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E202E),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Songs List
          _playlist!.songs.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.music_note,
                          size: 80,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No songs in this playlist',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            // Navigate to search to add songs
                            Navigator.pop(context);
                          },
                          child: const Text('Add songs from search'),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.only(bottom: 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final song = _playlist!.songs[index];
                      return Dismissible(
                        key: Key(song.encryptedMediaUrl),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) async {
                          await playlistProvider.removeSongFromPlaylist(
                            widget.playlistId,
                            song,
                          );
                          await _loadPlaylist(); // Reload

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Removed "${song.title}"'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    await playlistProvider.addSongToPlaylist(
                                      widget.playlistId,
                                      song,
                                    );
                                    await _loadPlaylist();
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        child: SongTile(
                          song: song,
                          onTap: () {
                            playerProvider.playSong(
                              song,
                              playlist: _playlist!.songs,
                              index: index,
                            );
                          },
                        ),
                      );
                    }, childCount: _playlist!.songs.length),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPlaylistHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF3D59A1).withOpacity(0.5),
            const Color(0xFF0A0A0D),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playlist Cover
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _playlist!.displayCoverImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _playlist!.displayCoverImage,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              _buildPlaceholderCover(),
                        )
                      : _buildPlaceholderCover(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Playlist Info
            Text(
              _playlist!.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_playlist!.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _playlist!.description,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${_playlist!.songs.length} songs • ${_playlist!.totalDuration}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3D59A1).withOpacity(0.6),
            const Color(0xFF1E202E),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note, size: 60, color: Colors.white54),
      ),
    );
  }

  void _handleMenuAction(String action, PlaylistProvider playlistProvider) {
    switch (action) {
      case 'edit':
        _showEditDialog();
        break;
      case 'delete':
        _showDeleteConfirmation(playlistProvider);
        break;
    }
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: _playlist!.name);
    final descriptionController = TextEditingController(
      text: _playlist!.description,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202E),
        title: const Text(
          'Edit Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Playlist Name',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.white54),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final playlistProvider = Provider.of<PlaylistProvider>(
                context,
                listen: false,
              );
              final updated = _playlist!.copyWith(
                name: nameController.text.trim(),
                description: descriptionController.text.trim(),
              );

              await playlistProvider.updatePlaylist(updated);
              await _loadPlaylist();

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFF3D59A1)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(PlaylistProvider playlistProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202E),
        title: const Text(
          'Delete Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${_playlist!.name}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              await playlistProvider.deletePlaylist(widget.playlistId);

              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to playlists screen

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Playlist deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
