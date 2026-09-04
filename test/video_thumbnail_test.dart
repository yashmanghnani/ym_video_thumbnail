import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ym_video_thumbnail/ym_video_thumbnail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.justsoft.xyz/video_thumbnail');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          final arguments = Map<String, dynamic>.from(
            methodCall.arguments as Map<dynamic, dynamic>,
          );

          if (methodCall.method == 'data') {
            return Uint8List.fromList(<int>[1, 2, 3]);
          }
          return '${methodCall.method}=${arguments['video']}'
              ':${arguments['path']}'
              ':${arguments['format']}'
              ':${arguments['maxw']}'
              ':${arguments['quality']}';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('thumbnailFile forwards the request to the native channel', () async {
    expect(
      await VideoThumbnail.thumbnailFile(
        video: 'video',
        thumbnailPath: 'path',
        imageFormat: ImageFormat.jpeg,
        maxWidth: 123,
        maxHeight: 123,
        quality: 45,
      ),
      'file=video:path:0:123:45',
    );
  });

  test('thumbnailData forwards the request to the native channel', () async {
    expect(
      await VideoThumbnail.thumbnailData(
        video: 'video',
        imageFormat: ImageFormat.webp,
        maxHeight: 64,
        quality: 80,
      ),
      Uint8List.fromList(<int>[1, 2, 3]),
    );
  });

  test('empty video returns null without invoking the platform', () async {
    expect(await VideoThumbnail.thumbnailData(video: ''), isNull);
  });

  test('invalid options throw an argument error', () {
    expect(
      () => VideoThumbnail.thumbnailData(video: 'video', quality: 101),
      throwsArgumentError,
    );
  });
}
