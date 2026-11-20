package xyz.justsoft.video_thumbnail;

import android.content.Context;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** Generates video thumbnails using Android's native media APIs. */
public final class VideoThumbnailPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String TAG = "VideoThumbnailPlugin";
    private static final String CHANNEL_NAME = "plugins.justsoft.xyz/video_thumbnail";

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private Context context;
    private ExecutorService executor;
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        executor = Executors.newFixedThreadPool(2);
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        if (executor != null) {
            executor.shutdownNow();
            executor = null;
        }
        context = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (!"file".equals(call.method) && !"data".equals(call.method)) {
            result.notImplemented();
            return;
        }

        if (!(call.arguments instanceof Map)) {
            result.error("invalid_arguments", "Thumbnail arguments are required.", null);
            return;
        }

        final Map<?, ?> arguments = (Map<?, ?>) call.arguments;
        final String video = stringArgument(arguments, "video");
        if (video == null || video.isEmpty()) {
            result.error("invalid_arguments", "The video path or URL is required.", null);
            return;
        }

        final Map<String, String> headers = headersArgument(arguments.get("headers"));
        final int format = intArgument(arguments, "format", 1);
        final int maxHeight = intArgument(arguments, "maxh", 0);
        final int maxWidth = intArgument(arguments, "maxw", 0);
        final long timeMs = intArgument(arguments, "timeMs", 0);
        final int quality = intArgument(arguments, "quality", 10);
        final String method = call.method;
        final String requestedPath = stringArgument(arguments, "path");

        executor.execute(() -> {
            try {
                Object thumbnail;
                if ("file".equals(method)) {
                    thumbnail = buildThumbnailFile(
                            video,
                            headers,
                            requestedPath,
                            format,
                            maxHeight,
                            maxWidth,
                            timeMs,
                            quality);
                } else {
                    thumbnail = buildThumbnailData(
                            video,
                            headers,
                            format,
                            maxHeight,
                            maxWidth,
                            timeMs,
                            quality);
                }
                postSuccess(result, thumbnail);
            } catch (Exception exception) {
                Log.e(TAG, "Unable to generate thumbnail", exception);
                postError(result, exception);
            }
        });
    }

    private byte[] buildThumbnailData(
            String video,
            Map<String, String> headers,
            int format,
            int maxHeight,
            int maxWidth,
            long timeMs,
            int quality) throws IOException {
        Bitmap bitmap = createVideoThumbnail(video, headers, maxHeight, maxWidth, timeMs);
        if (bitmap == null) {
            throw new IOException("The video frame could not be decoded.");
        }

        try (ByteArrayOutputStream stream = new ByteArrayOutputStream()) {
            if (!bitmap.compress(compressFormat(format, quality), quality, stream)) {
                throw new IOException("The thumbnail could not be encoded.");
            }
            return stream.toByteArray();
        } finally {
            bitmap.recycle();
        }
    }

    private String buildThumbnailFile(
            String video,
            Map<String, String> headers,
            String requestedPath,
            int format,
            int maxHeight,
            int maxWidth,
            long timeMs,
            int quality) throws IOException {
        final byte[] bytes = buildThumbnailData(
                video, headers, format, maxHeight, maxWidth, timeMs, quality);
        final String outputPath = resolveOutputPath(video, requestedPath, format);
        final File outputFile = new File(outputPath);
        final File parent = outputFile.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs() && !parent.isDirectory()) {
            throw new IOException("Unable to create thumbnail directory: " + parent);
        }

        try (FileOutputStream stream = new FileOutputStream(outputFile)) {
            stream.write(bytes);
        }
        return outputFile.getAbsolutePath();
    }

    private Bitmap createVideoThumbnail(
            String video,
            Map<String, String> headers,
            int targetHeight,
            int targetWidth,
            long timeMs) throws IOException {
        final MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            if (video.startsWith("/")) {
                setDataSource(video, retriever);
            } else if (video.startsWith("file://")) {
                setDataSource(Uri.parse(video).getPath(), retriever);
            } else {
                retriever.setDataSource(video, headers == null ? new HashMap<>() : headers);
            }

            final long timeUs = Math.max(0L, timeMs) * 1000L;
            if (targetHeight == 0 && targetWidth == 0) {
                return retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST);
            }

            if (android.os.Build.VERSION.SDK_INT >= 27 && targetHeight > 0 && targetWidth > 0) {
                return retriever.getScaledFrameAtTime(
                        timeUs,
                        MediaMetadataRetriever.OPTION_CLOSEST,
                        targetWidth,
                        targetHeight);
            }

            Bitmap bitmap = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST);
            if (bitmap == null) {
                return null;
            }

            final int sourceWidth = bitmap.getWidth();
            final int sourceHeight = bitmap.getHeight();
            final int width = targetWidth == 0
                    ? Math.max(1, Math.round((float) targetHeight * sourceWidth / sourceHeight))
                    : targetWidth;
            final int height = targetHeight == 0
                    ? Math.max(1, Math.round((float) targetWidth * sourceHeight / sourceWidth))
                    : targetHeight;
            final Bitmap scaled = Bitmap.createScaledBitmap(bitmap, width, height, true);
            if (scaled != bitmap) {
                bitmap.recycle();
            }
            return scaled;
        } finally {
            try {
                retriever.release();
            } catch (RuntimeException exception) {
                Log.w(TAG, "Unable to release media retriever", exception);
            }
        }
    }

    private String resolveOutputPath(String video, String requestedPath, int format) {
        final String extension = formatExtension(format);
        final boolean localVideo = video.startsWith("/") || video.startsWith("file://");
        final String localPath = video.startsWith("file://")
                ? Uri.parse(video).getPath()
                : video;
        final String sourceName;
        if (localVideo) {
            sourceName = new File(localPath).getName();
        } else {
            final String remoteName = Uri.parse(video).getLastPathSegment();
            sourceName = remoteName == null || remoteName.isEmpty() ? "thumbnail" : remoteName;
        }
        final String baseName = stripExtension(sourceName.isEmpty() ? "thumbnail" : sourceName);
        final String defaultDirectory;
        if (localVideo) {
            final File sourceFile = new File(localPath);
            defaultDirectory = sourceFile.getParent() == null
                    ? context.getCacheDir().getAbsolutePath()
                    : sourceFile.getParent();
        } else {
            defaultDirectory = context.getCacheDir().getAbsolutePath();
        }

        if (requestedPath != null && requestedPath.toLowerCase().endsWith("." + extension)) {
            return requestedPath;
        }
        final String directory = requestedPath == null || requestedPath.isEmpty()
                ? defaultDirectory
                : requestedPath;
        return new File(directory, baseName + "." + extension).getAbsolutePath();
    }

    private static Bitmap.CompressFormat compressFormat(int format, int quality) {
        if (format == 0) {
            return Bitmap.CompressFormat.JPEG;
        }
        if (format == 2 && android.os.Build.VERSION.SDK_INT >= 30) {
            return quality >= 100
                    ? Bitmap.CompressFormat.WEBP_LOSSLESS
                    : Bitmap.CompressFormat.WEBP_LOSSY;
        }
        return format == 2 ? Bitmap.CompressFormat.WEBP : Bitmap.CompressFormat.PNG;
    }

    private static String formatExtension(int format) {
        return format == 0 ? "jpg" : format == 2 ? "webp" : "png";
    }

    private static String stripExtension(String fileName) {
        final int extensionIndex = fileName.lastIndexOf('.');
        return extensionIndex > 0 ? fileName.substring(0, extensionIndex) : fileName;
    }

    private static void setDataSource(String path, MediaMetadataRetriever retriever)
            throws IOException {
        try (FileInputStream inputStream = new FileInputStream(new File(path))) {
            retriever.setDataSource(inputStream.getFD());
        }
    }

    private void postSuccess(Result result, Object value) {
        mainHandler.post(() -> result.success(value));
    }

    private void postError(Result result, Exception exception) {
        mainHandler.post(() -> result.error(
                "thumbnail_error",
                exception.getMessage() == null ? "Thumbnail generation failed." : exception.getMessage(),
                null));
    }

    private static String stringArgument(Map<?, ?> arguments, String key) {
        final Object value = arguments.get(key);
        return value instanceof String ? (String) value : null;
    }

    private static int intArgument(Map<?, ?> arguments, String key, int defaultValue) {
        final Object value = arguments.get(key);
        return value instanceof Number ? ((Number) value).intValue() : defaultValue;
    }

    private static Map<String, String> headersArgument(Object value) {
        if (!(value instanceof Map)) {
            return null;
        }
        final Map<String, String> headers = new HashMap<>();
        for (Map.Entry<?, ?> entry : ((Map<?, ?>) value).entrySet()) {
            if (entry.getKey() instanceof String && entry.getValue() instanceof String) {
                headers.put((String) entry.getKey(), (String) entry.getValue());
            }
        }
        return headers;
    }
}
