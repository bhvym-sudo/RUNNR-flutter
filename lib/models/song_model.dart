class SongModel {
  final String title;
  final String subtitle;
  final String image;
  final String duration;
  final String encryptedMediaUrl;

  SongModel({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.duration,
    required this.encryptedMediaUrl,
  });

  // Create from JSON
  factory SongModel.fromJson(Map<String, dynamic> json) {
    final moreInfo = json['more_info'] ?? {};
    return SongModel(
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? json['description'] ?? '',
      image: json['image'] ?? '',
      duration: moreInfo['duration'] ?? json['duration'] ?? '0',
      encryptedMediaUrl:
          moreInfo['encrypted_media_url'] ?? json['encrypted_media_url'] ?? '',
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'image': image,
      'duration': duration,
      'encrypted_media_url': encryptedMediaUrl,
    };
  }

  // Equality check based on encrypted URL
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel &&
          runtimeType == other.runtimeType &&
          encryptedMediaUrl == other.encryptedMediaUrl;

  @override
  int get hashCode => encryptedMediaUrl.hashCode;

  // Format duration from seconds to mm:ss
  String get formattedDuration {
    try {
      final seconds = int.parse(duration);
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return duration;
    }
  }

  // Get high quality image
  String get highQualityImage {
    return image.replaceAll('150x150', '500x500');
  }

  // Copy with method
  SongModel copyWith({
    String? title,
    String? subtitle,
    String? image,
    String? duration,
    String? encryptedMediaUrl,
  }) {
    return SongModel(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      image: image ?? this.image,
      duration: duration ?? this.duration,
      encryptedMediaUrl: encryptedMediaUrl ?? this.encryptedMediaUrl,
    );
  }
}
