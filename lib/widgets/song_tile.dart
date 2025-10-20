import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/liked_songs_provider.dart';
import '../constants/app_colors.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;
  final bool showLikeButton;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.showLikeButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final likedSongsProvider = Provider.of<LikedSongsProvider>(context);
    final isLiked = likedSongsProvider.isLiked(song);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: song.image,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 56,
            height: 56,
            color: Colors.grey[900],
            child: const Icon(Icons.music_note, color: Colors.white54),
          ),
          errorWidget: (context, url, error) => Container(
            width: 56,
            height: 56,
            color: Colors.grey[900],
            child: const Icon(Icons.music_note, color: Colors.white54),
          ),
        ),
      ),
      title: Text(
        song.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.subtitle,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: showLikeButton
          ? IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? AppColors.likeColor : Colors.white70,
              ),
              onPressed: () async {
                try {
                  await likedSongsProvider.toggleLike(song);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isLiked
                              ? 'Removed from liked songs'
                              : 'Added to liked songs',
                        ),
                        duration: const Duration(seconds: 1),
                        backgroundColor: Colors.grey[900],
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            )
          : null,
      onTap: onTap,
    );
  }
}
