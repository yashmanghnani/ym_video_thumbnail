# ym_video_thumbnail

[![pub package](https://img.shields.io/pub/v/ym_video_thumbnail.svg)](https://pub.dev/packages/ym_video_thumbnail)
[![pub points](https://img.shields.io/pub/points/ym_video_thumbnail)](https://pub.dev/packages/ym_video_thumbnail/score)
[![license](https://img.shields.io/github/license/yashmanghnani/ym_video_thumbnail.svg)](https://github.com/yashmanghnani/ym_video_thumbnail/blob/main/LICENSE)

`ym_video_thumbnail` generates a still image from a local video file or a
remote video URL on Android and iOS. Use it when you need thumbnail bytes for
an image widget or a thumbnail file for upload, caching, or sharing.

## Requirements

- Flutter 3.35.0 or newer
- Dart 3.9.0 or newer
- Android API 24 or newer
- iOS 15.0 or newer

The native implementation uses Android `MediaMetadataRetriever` and iOS
`AVAssetImageGenerator`. The video must use a format supported by the target
platform.

## Install

```yaml
dependencies:
  ym_video_thumbnail: ^1.0.0
```

Then import the API:

```dart
import 'package:ym_video_thumbnail/ym_video_thumbnail.dart';
```

## Generate thumbnail bytes

```dart
final Uint8List? bytes = await VideoThumbnail.thumbnailData(
  video: '/path/to/video.mp4',
  imageFormat: ImageFormat.jpeg,
  maxWidth: 320, // height is calculated from the source aspect ratio
  quality: 80,
);

if (bytes != null) {
  final image = Image.memory(bytes);
}
```

## Generate a thumbnail file

```dart
final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
  video: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
  thumbnailPath: '/path/to/cache', // directory or a full filename
  imageFormat: ImageFormat.webp,
  maxHeight: 180,
  quality: 75,
);
```

When `thumbnailPath` is omitted, local videos are written beside the source
video and remote videos are written to the platform cache directory. A path
ending in `.jpg`, `.png`, or `.webp` is treated as a complete filename;
otherwise it is treated as a directory.

## API

### `VideoThumbnail.thumbnailData`

Returns `Future<Uint8List?>`. It accepts:

- `video`: local path, `file://` URI, or native-platform-supported URL
- `headers`: optional HTTP request headers for remote videos
- `imageFormat`: `ImageFormat.jpeg`, `ImageFormat.png`, or `ImageFormat.webp`
- `maxHeight` / `maxWidth`: maximum dimensions; use `0` to preserve that axis
- `timeMs`: frame position in milliseconds, default `0`
- `quality`: `0` to `100`; ignored for PNG, default `10`

### `VideoThumbnail.thumbnailFile`

Returns `Future<String?>` and accepts the same options plus `thumbnailPath`.

If both dimensions are non-zero, Android may use the exact requested width and
height. To preserve aspect ratio consistently, provide only one dimension.

## Migration from pre-1.0 releases

The original uppercase enum names remain available as deprecated aliases:

```dart
// Existing code continues to work.
ImageFormat.JPEG;

// New code should use:
ImageFormat.jpeg;
```

Invalid dimensions, timestamps, or quality values now fail fast with an
`ArgumentError` instead of being sent to native code.

## Development

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter pub publish --dry-run
```

The `example/` app demonstrates local file, URL, in-memory, and file-based
thumbnail generation.

## License

See [LICENSE](LICENSE).
