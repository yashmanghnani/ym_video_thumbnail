// ignore_for_file: constant_identifier_names

/// The Flutter plugin for creating thumbnails from video files and URLs.
///
/// To use, import `package:ym_video_thumbnail/ym_video_thumbnail.dart`.
library;

import 'package:flutter/services.dart';

/// Image formats supported by the native thumbnail encoders.
enum ImageFormat {
  jpeg,
  png,
  webp;

  // Keep the original names source-compatible for existing applications.
  @Deprecated('Use ImageFormat.jpeg instead.')
  static const ImageFormat JPEG = ImageFormat.jpeg;
  @Deprecated('Use ImageFormat.png instead.')
  static const ImageFormat PNG = ImageFormat.png;
  @Deprecated('Use ImageFormat.webp instead.')
  static const ImageFormat WEBP = ImageFormat.webp;
}

/// Generates image thumbnails from local videos and supported video URLs.
class VideoThumbnail {
  static const MethodChannel _channel = MethodChannel(
    'plugins.justsoft.xyz/video_thumbnail',
  );

  /// Generates and writes a thumbnail file.
  ///
  /// [video] may be a local path, a `file://` URI, or a URL supported by the
  /// platform's native video decoder. If [thumbnailPath] is omitted, local
  /// videos are written beside the source and remote videos are written to the
  /// platform cache directory. A path ending in the expected extension is
  /// treated as a file; all other paths are treated as directories.
  ///
  /// Set either dimension to zero to preserve the source aspect ratio. Quality
  /// is an integer from 0 to 100 and is ignored for PNG output.
  static Future<String?> thumbnailFile({
    required String video,
    Map<String, String>? headers,
    String? thumbnailPath,
    ImageFormat imageFormat = ImageFormat.png,
    int maxHeight = 0,
    int maxWidth = 0,
    int timeMs = 0,
    int quality = 10,
  }) async {
    if (video.isEmpty) {
      return null;
    }
    _validateOptions(
      maxHeight: maxHeight,
      maxWidth: maxWidth,
      timeMs: timeMs,
      quality: quality,
    );

    return _channel.invokeMethod<String>('file', <String, dynamic>{
      ..._requestArguments(
        video: video,
        headers: headers,
        imageFormat: imageFormat,
        maxHeight: maxHeight,
        maxWidth: maxWidth,
        timeMs: timeMs,
        quality: quality,
      ),
      'path': thumbnailPath,
    });
  }

  /// Generates thumbnail bytes in memory for use with `Image.memory`.
  ///
  /// [video] accepts the same local paths and URLs as [thumbnailFile]. Set
  /// either dimension to zero to preserve the source aspect ratio.
  static Future<Uint8List?> thumbnailData({
    required String video,
    Map<String, String>? headers,
    ImageFormat imageFormat = ImageFormat.png,
    int maxHeight = 0,
    int maxWidth = 0,
    int timeMs = 0,
    int quality = 10,
  }) async {
    if (video.isEmpty) {
      return null;
    }
    _validateOptions(
      maxHeight: maxHeight,
      maxWidth: maxWidth,
      timeMs: timeMs,
      quality: quality,
    );

    return _channel.invokeMethod<Uint8List>(
      'data',
      _requestArguments(
        video: video,
        headers: headers,
        imageFormat: imageFormat,
        maxHeight: maxHeight,
        maxWidth: maxWidth,
        timeMs: timeMs,
        quality: quality,
      ),
    );
  }

  static Map<String, dynamic> _requestArguments({
    required String video,
    required Map<String, String>? headers,
    required ImageFormat imageFormat,
    required int maxHeight,
    required int maxWidth,
    required int timeMs,
    required int quality,
  }) {
    return <String, dynamic>{
      'video': video,
      'headers': headers,
      'format': imageFormat.index,
      'maxh': maxHeight,
      'maxw': maxWidth,
      'timeMs': timeMs,
      'quality': quality,
    };
  }

  static void _validateOptions({
    required int maxHeight,
    required int maxWidth,
    required int timeMs,
    required int quality,
  }) {
    if (maxHeight < 0) {
      throw ArgumentError.value(
        maxHeight,
        'maxHeight',
        'must be zero or greater',
      );
    }
    if (maxWidth < 0) {
      throw ArgumentError.value(
        maxWidth,
        'maxWidth',
        'must be zero or greater',
      );
    }
    if (timeMs < 0) {
      throw ArgumentError.value(timeMs, 'timeMs', 'must be zero or greater');
    }
    if (quality < 0 || quality > 100) {
      throw ArgumentError.value(
        quality,
        'quality',
        'must be between 0 and 100',
      );
    }
  }
}
