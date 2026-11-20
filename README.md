# ym_video_thumbnail

[![pub package](https://img.shields.io/pub/v/ym_video_thumbnail.svg)](https://pub.dev/packages/ym_video_thumbnail)
[![pub points](https://img.shields.io/pub/points/ym_video_thumbnail)](https://pub.dev/packages/ym_video_thumbnail/score)
[![license](https://img.shields.io/github/license/yashmanghnani/ym_video_thumbnail.svg)](https://github.com/yashmanghnani/ym_video_thumbnail/blob/main/LICENSE)

`ym_video_thumbnail` generates a still image from a local video file or a
remote video URL on Android and iOS. Use it when you need thumbnail bytes for
an image widget or a thumbnail file for upload, caching, or sharing.

## Requirements

- Flutter 3.50.1 or newer
- Dart 3.14.0 or newer
- Android API 24 or newer
- iOS 15.0 or newer

The native implementation uses Android `MediaMetadataRetriever` and iOS
`AVAssetImageGenerator`. The video must use a format supported by the target
platform. The Android example builds with AGP 9.3.1, Gradle 9.5.0, and
Android SDK 36. The iOS plugin uses CocoaPods. The example uses the UIScene
lifecycle.

## Install

```yaml
dependencies:
  ym_video_thumbnail: ^2.0.0
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
video and remote videos are written to the platform cache directory. An output
path is treated as a complete filename when its extension matches the selected
format (`.jpg`, `.png`, or `.webp`). Other paths are treated as directories.

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

## Migration

Version 2 requires Flutter 3.50.1 and Dart 3.14.0 or newer. Use the 1.x
constraint for projects that need an older SDK. Existing thumbnail calls
require no source changes.

### From pre-1.0 releases

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
