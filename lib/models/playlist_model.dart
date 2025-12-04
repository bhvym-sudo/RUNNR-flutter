import 'song_model.dart';

/// Playlist Model
class PlaylistModel {
  final String id;
  final String name;
  final String description;
  final List<SongModel> songs;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional: cover image (defaults to first song's image)
  final String? coverImage;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.description,
    required this.songs,
    required this.createdAt,
    required this.updatedAt,
    this.coverImage,
  });

  /// Get cover image (custom or first song's image)
  String get displayCoverImage {
    if (coverImage != null && coverImage!.isNotEmpty) {
      return coverImage!;
    }
    if (songs.isNotEmpty) {
      return songs.first.highQualityImage;
    }
    return ''; // Placeholder
  }

  /// Get playlist duration (sum of all songs)
  String get totalDuration {
    try {
      int totalSeconds = 0;
      for (var song in songs) {
        totalSeconds += int.parse(song.duration);
      }
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;

      if (hours > 0) {
        return '$hours hr ${minutes} min';
      }
      return '$minutes min';
    } catch (e) {
      return '0 min';
    }
  }

  /// Convert to JSON for Hive storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'songs': songs.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'coverImage': coverImage,
    };
  }

  /// Create from JSON
  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    return PlaylistModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      songs:
          (json['songs'] as List?)
              ?.map((s) => SongModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      coverImage: json['coverImage'],
    );
  }

  /// Copy with method
  PlaylistModel copyWith({
    String? id,
    String? name,
    String? description,
    List<SongModel>? songs,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? coverImage,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverImage: coverImage ?? this.coverImage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
