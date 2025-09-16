import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:io';

import 'package:ym_video_thumbnail/video_thumbnail.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Main entry point of the application.
void main() => runApp(const MyApp());

/// Root widget of the application.
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DemoHome(),
    );
  }
}

/// Data class representing a thumbnail generation request.
class ThumbnailRequest {
  final String video;
  final String? thumbnailPath; // Made nullable for data generation
  final ImageFormat imageFormat;
  final int maxHeight;
  final int maxWidth;
  final int timeMs;
  final int quality;

  const ThumbnailRequest({
    required this.video,
    this.thumbnailPath,
    required this.imageFormat,
    required this.maxHeight,
    required this.maxWidth,
    required this.timeMs,
    required this.quality,
  });

  /// Validates the request parameters.
  bool get isValid => video.isNotEmpty && maxHeight >= 0 && maxWidth >= 0 && timeMs >= 0 && quality >= 0 && quality <= 100;
}

/// Data class representing the result of thumbnail generation.
class ThumbnailResult {
  final Image image;
  final int dataSize;
  final int height;
  final int width;

  const ThumbnailResult({
    required this.image,
    required this.dataSize,
    required this.height,
    required this.width,
  });
}

/// Service class to handle thumbnail generation logic.
class ThumbnailService {
  /// Generates a thumbnail based on the request.
  /// Handles both file and data generation with proper error handling.
  static Future<ThumbnailResult> generateThumbnail(ThumbnailRequest request) async {
    if (!request.isValid) {
      throw ArgumentError('Invalid thumbnail request parameters');
    }

    Uint8List bytes;

    try {
      if (request.thumbnailPath != null) {
        // Generate file thumbnail with unique name
        final uniquePath = _generateUniqueFilePath(request.thumbnailPath!, request.imageFormat);
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: request.video,
          headers: const {
            "USERHEADER1": "user defined header1",
            "USERHEADER2": "user defined header2",
          },
          thumbnailPath: uniquePath,
          imageFormat: request.imageFormat,
          maxHeight: request.maxHeight,
          maxWidth: request.maxWidth,
          timeMs: request.timeMs,
          quality: request.quality,
        );

        if (thumbnailPath == null) {
          throw Exception('Failed to generate thumbnail file');
        }

        debugPrint("Thumbnail file generated at: $thumbnailPath");

        final file = File(thumbnailPath);
        if (!await file.exists()) {
          throw FileSystemException('Generated file does not exist', thumbnailPath);
        }

        bytes = await file.readAsBytes();
      } else {
        // Generate data thumbnail
        bytes = await VideoThumbnail.thumbnailData(
              video: request.video,
              headers: const {
                "USERHEADER1": "user defined header1",
                "USERHEADER2": "user defined header2",
              },
              imageFormat: request.imageFormat,
              maxHeight: request.maxHeight,
              maxWidth: request.maxWidth,
              timeMs: request.timeMs,
              quality: request.quality,
            ) ??
            (throw Exception('Failed to generate thumbnail data'));
      }

      final imageDataSize = bytes.length;
      debugPrint("Image data size: $imageDataSize bytes");

      final image = Image.memory(bytes);
      final completer = Completer<ThumbnailResult>();

      image.image.resolve(ImageConfiguration()).addListener(
        ImageStreamListener((ImageInfo info, bool _) {
          completer.complete(ThumbnailResult(
            image: image,
            dataSize: imageDataSize,
            height: info.image.height,
            width: info.image.width,
          ));
        }),
      );

      return completer.future;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      rethrow;
    }
  }

  /// Generates a unique file path for thumbnail files.
  static String _generateUniqueFilePath(String directory, ImageFormat format) {
    final extension = format == ImageFormat.JPEG
        ? 'jpg'
        : format == ImageFormat.PNG
            ? 'png'
            : 'webp';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(10000);
    return path.join(directory, 'thumbnail_${timestamp}_$random.$extension');
  }
}

/// Widget to display the generated thumbnail with loading and error states.
class ThumbnailDisplay extends StatefulWidget {
  final ThumbnailRequest? thumbnailRequest;

  const ThumbnailDisplay({Key? key, this.thumbnailRequest}) : super(key: key);

  @override
  State<ThumbnailDisplay> createState() => _ThumbnailDisplayState();
}

class _ThumbnailDisplayState extends State<ThumbnailDisplay> {
  @override
  Widget build(BuildContext context) {
    if (widget.thumbnailRequest == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<ThumbnailResult>(
      future: ThumbnailService.generateThumbnail(widget.thumbnailRequest!),
      builder: (BuildContext context, AsyncSnapshot<ThumbnailResult> snapshot) {
        if (snapshot.hasData) {
          final data = snapshot.data!;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                "Image ${widget.thumbnailRequest!.thumbnailPath == null ? 'data' : 'file'} size: ${data.dataSize} bytes, width: ${data.width}, height: ${data.height}",
                textAlign: TextAlign.center,
              ),
              const Divider(color: Colors.grey, thickness: 1.0),
              data.image,
            ],
          );
        } else if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.red.shade100,
            child: Text(
              "Error generating thumbnail:\n${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        } else {
          return const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text("Generating thumbnail..."),
              SizedBox(height: 10.0),
              CircularProgressIndicator(),
            ],
          );
        }
      },
    );
  }
}

/// Main demo home screen widget.
class DemoHome extends StatefulWidget {
  const DemoHome({Key? key}) : super(key: key);

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  final FocusNode _editNode = FocusNode();
  final TextEditingController _videoController = TextEditingController(
    text: "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4",
  );
  ImageFormat _format = ImageFormat.JPEG;
  int _quality = 50;
  int _sizeH = 0;
  int _sizeW = 0;
  int _timeMs = 0;

  ThumbnailRequest? _currentRequest;
  String? _tempDir;

  @override
  void initState() {
    super.initState();
    _initializeTempDir();
  }

  @override
  void dispose() {
    _editNode.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _initializeTempDir() async {
    try {
      final dir = await getTemporaryDirectory();
      setState(() {
        _tempDir = dir.path;
      });
    } catch (e) {
      debugPrint('Error getting temporary directory: $e');
      // Fallback to null, user will see error
    }
  }

  void _unfocusAndUpdate() {
    _editNode.unfocus();
    setState(() {});
  }

  void _generateDataThumbnail() {
    setState(() {
      _currentRequest = ThumbnailRequest(
        video: _videoController.text.trim(),
        thumbnailPath: null,
        imageFormat: _format,
        maxHeight: _sizeH,
        maxWidth: _sizeW,
        timeMs: _timeMs,
        quality: _quality,
      );
    });
  }

  void _generateFileThumbnail() {
    if (_tempDir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temporary directory not available')),
      );
      return;
    }

    setState(() {
      _currentRequest = ThumbnailRequest(
        video: _videoController.text.trim(),
        thumbnailPath: _tempDir!,
        imageFormat: _format,
        maxHeight: _sizeH,
        maxWidth: _sizeW,
        timeMs: _timeMs,
        quality: _quality,
      );
    });
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await ImagePicker().pickVideo(source: source);
      if (video != null) {
        setState(() {
          _videoController.text = video.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    }
  }

  List<Widget> _buildSettings() {
    return [
      // Height Slider
      Slider(
        value: _sizeH.toDouble(),
        onChanged: (v) => setState(() {
          _sizeH = v.toInt();
          _unfocusAndUpdate();
        }),
        max: 256.0,
        divisions: 256,
        label: "$_sizeH",
      ),
      Center(
        child: Text(
          _sizeH == 0
              ? "Original video height or scaled by aspect ratio"
              : "Max height: $_sizeH px",
        ),
      ),

      // Width Slider
      Slider(
        value: _sizeW.toDouble(),
        onChanged: (v) => setState(() {
          _sizeW = v.toInt();
          _unfocusAndUpdate();
        }),
        max: 256.0,
        divisions: 256,
        label: "$_sizeW",
      ),
      Center(
        child: Text(
          _sizeW == 0
              ? "Original video width or scaled by aspect ratio"
              : "Max width: $_sizeW px",
        ),
      ),

      // Time Slider
      Slider(
        value: _timeMs.toDouble(),
        onChanged: (v) => setState(() {
          _timeMs = v.toInt();
          _unfocusAndUpdate();
        }),
        max: 10.0 * 1000,
        divisions: 1000,
        label: "$_timeMs",
      ),
      Center(
        child: Text(
          _timeMs == 0
              ? "Beginning of the video"
              : "Frame at $_timeMs ms",
        ),
      ),

      // Quality Slider
      Slider(
        value: _quality.toDouble(),
        onChanged: (v) => setState(() {
          _quality = v.toInt();
          _unfocusAndUpdate();
        }),
        max: 100.0,
        divisions: 100,
        label: "$_quality",
      ),
      Center(child: Text("Quality: $_quality")),

      // Format Selection
      Padding(
        padding: const EdgeInsets.fromLTRB(2.0, 10.0, 2.0, 8.0),
        child: InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            filled: true,
            isDense: true,
            labelText: "Thumbnail Format",
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              for (final format in [ImageFormat.JPEG, ImageFormat.PNG, ImageFormat.WEBP])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<ImageFormat>(
                      groupValue: _format,
                      value: format,
                      onChanged: (v) => setState(() {
                        _format = v!;
                        _unfocusAndUpdate();
                      }),
                    ),
                    Text(format == ImageFormat.JPEG
                        ? "JPEG"
                        : format == ImageFormat.PNG
                            ? "PNG"
                            : "WebP"),
                  ],
                ),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final settings = _buildSettings();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thumbnail Plugin Example'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Video URI Input
          Padding(
            padding: const EdgeInsets.fromLTRB(2.0, 10.0, 2.0, 8.0),
            child: TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                isDense: true,
                labelText: "Video URI",
              ),
              maxLines: null,
              controller: _videoController,
              focusNode: _editNode,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onEditingComplete: _unfocusAndUpdate,
            ),
          ),

          // Settings Widgets
          ...settings,

          // Thumbnail Display Area
          Expanded(
            child: Container(
              color: Colors.grey[300],
              child: Scrollbar(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    ThumbnailDisplay(thumbnailRequest: _currentRequest),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Drawer for settings
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            AppBar(
              title: const Text("Settings"),
              automaticallyImplyLeading: false,
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            ...settings,
          ],
        ),
      ),

      // Floating Action Buttons
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FloatingActionButton(
            onPressed: () => _pickVideo(ImageSource.camera),
            tooltip: "Capture a video",
            child: const Icon(Icons.videocam),
          ),
          const SizedBox(width: 5.0),
          FloatingActionButton(
            onPressed: () => _pickVideo(ImageSource.gallery),
            tooltip: "Pick a video",
            child: const Icon(Icons.local_movies),
          ),
          const SizedBox(width: 20.0),
          FloatingActionButton(
            tooltip: "Generate data thumbnail",
            onPressed: _generateDataThumbnail,
            child: const Text("Data"),
          ),
          const SizedBox(width: 5.0),
          FloatingActionButton(
            tooltip: "Generate file thumbnail",
            onPressed: _generateFileThumbnail,
            child: const Text("File"),
          ),
        ],
      ),
    );
  }
}
