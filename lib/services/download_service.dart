import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import 'jiosaavn_service.dart';

class DownloadService {
  static final Dio _dio = Dio();

  /// Download a song to the public Downloads folder
  static Future<void> downloadSong(
    SongModel song, {
    required Function(double) onProgress,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    try {
      // Get stream URL
      final streamUrl = await JioSaavnService.getStreamUrl(
        song.encryptedMediaUrl,
      );

      if (streamUrl == null || streamUrl.isEmpty) {
        onError('Could not get download URL');
        return;
      }

      // Use public Downloads directory that's visible to the user
      Directory? directory;
      if (Platform.isAndroid) {
        // Try standard Downloads folder first
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          // Fallback to /storage/emulated/0/Downloads (with 's')
          directory = Directory('/storage/emulated/0/Downloads');
          if (!await directory.exists()) {
            // Final fallback to app's external storage
            final baseDir = await getExternalStorageDirectory();
            directory = baseDir;
          }
        }
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        onError('Could not access Downloads folder');
        return;
      }

      // Clean filename
      final fileName = _sanitizeFileName(
        '${song.title} - ${song.subtitle}.mp3',
      );
      final filePath = '${directory.path}/$fileName';

      // Download with progress (use exact same headers as JioSaavn service)
      await _dio.download(
        streamUrl,
        filePath,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138 Safari/537.36',
            'Referer': 'https://www.jiosaavn.com/',
            'Origin': 'https://www.jiosaavn.com',
            'Accept': 'application/json',
            'Connection': 'keep-alive',
          },
          followRedirects: true,
          maxRedirects: 5,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
          } else {
            // If total is unknown, show progress based on received bytes
            final estimatedTotal = 5 * 1024 * 1024; // 5MB
            final progress = (received / estimatedTotal).clamp(0.0, 0.99);
            onProgress(progress);
          }
        },
      );

      onComplete();
    } catch (e) {
      onError('Download failed: $e');
    }
  }

  /// Sanitize filename for safe file system usage
  static String _sanitizeFileName(String fileName) {
    // Remove invalid characters
    String sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    // Limit length
    if (sanitized.length > 200) {
      sanitized = sanitized.substring(0, 200);
    }
    return sanitized;
  }
}
