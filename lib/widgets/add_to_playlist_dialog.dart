import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/playlist_provider.dart';
import '../screens/create_playlist_dialog.dart';

class AddToPlaylistDialog extends StatelessWidget {
  final SongModel song;

  const AddToPlaylistDialog({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final playlistProvider = Provider.of<PlaylistProvider>(context);
    final playlists = playlistProvider.playlists;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E202E),
      title: const Text(
        'Add to Playlist',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Create New Playlist Button
            ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D59A1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
              title: const Text(
                'Create New Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => const CreatePlaylistDialog(),
                );
              },
            ),
            const Divider(color: Colors.white24),
            // List of Playlists
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No playlists yet. Create one!',
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final isInPlaylist = playlist.songs.any(
                      (s) => s.encryptedMediaUrl == song.encryptedMediaUrl,
                    );

                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[800],
                        ),
                        child: playlist.displayCoverImage.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  playlist.displayCoverImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.music_note,
                                      color: Colors.white54,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.music_note,
                                color: Colors.white54,
                              ),
                      ),
                      title: Text(
                        playlist.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${playlist.songs.length} songs',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: isInPlaylist
                          ? const Icon(Icons.check, color: Color(0xFF3D59A1))
                          : null,
                      onTap: () async {
                        if (isInPlaylist) {
                          await playlistProvider.removeSongFromPlaylist(
                            playlist.id,
                            song,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Removed from "${playlist.name}"',
                                ),
                                backgroundColor: Colors.grey[800],
                              ),
                            );
                          }
                        } else {
                          await playlistProvider.addSongToPlaylist(
                            playlist.id,
                            song,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added to "${playlist.name}"'),
                                backgroundColor: const Color(0xFF3D59A1),
                              ),
                            );
                          }
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
