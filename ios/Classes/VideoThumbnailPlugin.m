#import "VideoThumbnailPlugin.h"

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#if __has_include("webp/encode.h")
#import "webp/encode.h"
#define YM_VIDEO_THUMBNAIL_HAS_WEBP 1
#elif __has_include(<libwebp/encode.h>)
#import <libwebp/encode.h>
#define YM_VIDEO_THUMBNAIL_HAS_WEBP 1
#else
#define YM_VIDEO_THUMBNAIL_HAS_WEBP 0
#endif

static NSString *const YMVideoThumbnailChannelName =
    @"plugins.justsoft.xyz/video_thumbnail";

@interface VideoThumbnailPlugin ()
+ (NSURL *)URLForVideoString:(NSString *)video;
+ (NSString *)outputPathForVideoURL:(NSURL *)url
                        videoString:(NSString *)video
                            request:(NSString *)request
                             format:(NSInteger)format;
+ (NSData *)generateThumbnail:(NSURL *)url
                       headers:(NSDictionary *)headers
                        format:(NSInteger)format
                    maxHeight:(NSInteger)maxHeight
                     maxWidth:(NSInteger)maxWidth
                       timeMs:(NSInteger)timeMs
                       quality:(NSInteger)quality;
+ (void)finishOnMain:(FlutterResult)result
             success:(id)value
               error:(FlutterError *)error;
@end

@implementation VideoThumbnailPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel
        methodChannelWithName:YMVideoThumbnailChannelName
              binaryMessenger:[registrar messenger]];
    VideoThumbnailPlugin *instance = [[VideoThumbnailPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (![call.method isEqualToString:@"data"] &&
        ![call.method isEqualToString:@"file"]) {
        result(FlutterMethodNotImplemented);
        return;
    }

    NSDictionary *arguments = [call.arguments isKindOfClass:[NSDictionary class]]
        ? call.arguments
        : @{};
    NSString *video = arguments[@"video"];
    if (![video isKindOfClass:[NSString class]] || video.length == 0) {
        result([FlutterError errorWithCode:@"invalid_arguments"
                                   message:@"The video path or URL is required."
                                   details:nil]);
        return;
    }

    NSDictionary *headers = [arguments[@"headers"] isKindOfClass:[NSDictionary class]]
        ? arguments[@"headers"]
        : nil;
    NSString *requestedPath = [arguments[@"path"] isKindOfClass:[NSString class]]
        ? arguments[@"path"]
        : nil;
    NSInteger format = [arguments[@"format"] integerValue];
    NSInteger maxHeight = MAX(0, [arguments[@"maxh"] integerValue]);
    NSInteger maxWidth = MAX(0, [arguments[@"maxw"] integerValue]);
    NSInteger timeMs = MAX(0, [arguments[@"timeMs"] integerValue]);
    NSInteger quality = MIN(100, MAX(0, [arguments[@"quality"] integerValue]));

    NSURL *url = [self.class URLForVideoString:video];
    if (url == nil) {
        result([FlutterError errorWithCode:@"invalid_video"
                                   message:@"The video path or URL is invalid."
                                   details:nil]);
        return;
    }

    BOOL writeToFile = [call.method isEqualToString:@"file"];
    NSString *outputPath = writeToFile
        ? [self.class outputPathForVideoURL:url
                               videoString:video
                                   request:requestedPath
                                    format:format]
        : nil;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            NSData *data = [self.class generateThumbnail:url
                                                  headers:headers
                                                   format:format
                                               maxHeight:maxHeight
                                                maxWidth:maxWidth
                                                  timeMs:timeMs
                                                 quality:quality];
            if (data == nil) {
                [self.class finishOnMain:result
                                  success:nil
                                    error:[FlutterError errorWithCode:@"thumbnail_error"
                                                               message:@"The video frame could not be decoded or encoded."
                                                               details:nil]];
                return;
            }

            if (!writeToFile) {
                [self.class finishOnMain:result success:data error:nil];
                return;
            }

            NSString *directory = [outputPath stringByDeletingLastPathComponent];
            NSError *directoryError = nil;
            BOOL directoryCreated = [[NSFileManager defaultManager]
                createDirectoryAtPath:directory
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&directoryError];
            if (!directoryCreated && directoryError != nil) {
                [self.class finishOnMain:result
                                  success:nil
                                    error:[FlutterError errorWithCode:@"io_error"
                                                               message:directoryError.localizedDescription
                                                               details:nil]];
                return;
            }

            NSError *writeError = nil;
            if (![data writeToFile:outputPath options:NSDataWritingAtomic error:&writeError]) {
                [self.class finishOnMain:result
                                  success:nil
                                    error:[FlutterError errorWithCode:@"io_error"
                                                               message:writeError.localizedDescription
                                                               details:nil]];
                return;
            }
            [self.class finishOnMain:result success:outputPath error:nil];
        }
    });
}

+ (NSURL *)URLForVideoString:(NSString *)video {
    if ([video hasPrefix:@"file://"]) {
        return [NSURL fileURLWithPath:[video substringFromIndex:7]];
    }
    if ([video hasPrefix:@"/"]) {
        return [NSURL fileURLWithPath:video];
    }
    return [NSURL URLWithString:video];
}

+ (NSString *)outputPathForVideoURL:(NSURL *)url
                        videoString:(NSString *)video
                            request:(NSString *)request
                             format:(NSInteger)format {
    NSString *extension = format == 0 ? @"jpg" : format == 1 ? @"png" : @"webp";
    BOOL isLocalFile = [video hasPrefix:@"file://"] || [video hasPrefix:@"/"];
    NSString *sourceName = url.lastPathComponent.stringByDeletingPathExtension;
    if (sourceName.length == 0) {
        sourceName = @"thumbnail";
    }
    NSString *fileName = [sourceName stringByAppendingPathExtension:extension];

    if (request.length > 0 &&
        [request.pathExtension.lowercaseString isEqualToString:extension]) {
        return request;
    }

    NSString *directory = request;
    if (directory.length == 0) {
        directory = isLocalFile
            ? url.path.stringByDeletingLastPathComponent
            : [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                    NSUserDomainMask,
                                                    YES) lastObject];
    }
    return [directory stringByAppendingPathComponent:fileName];
}

+ (NSData *)generateThumbnail:(NSURL *)url
                       headers:(NSDictionary *)headers
                        format:(NSInteger)format
                    maxHeight:(NSInteger)maxHeight
                     maxWidth:(NSInteger)maxWidth
                       timeMs:(NSInteger)timeMs
                       quality:(NSInteger)quality {
    NSDictionary *options = headers.count > 0
        ? @{ @"AVURLAssetHTTPHeaderFieldsKey" : headers }
        : nil;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:options];
    AVAssetImageGenerator *imageGenerator =
        [[AVAssetImageGenerator alloc] initWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    if (maxHeight > 0 || maxWidth > 0) {
        imageGenerator.maximumSize = CGSizeMake(
            maxWidth > 0 ? (CGFloat)maxWidth : CGFLOAT_MAX,
            maxHeight > 0 ? (CGFloat)maxHeight : CGFLOAT_MAX);
    }
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = CMTimeMake(100, 1000);

    NSError *error = nil;
    CGImageRef image = [imageGenerator copyCGImageAtTime:CMTimeMake(timeMs, 1000)
                                             actualTime:nil
                                                  error:&error];
    if (image == nil || error != nil) {
        if (image != nil) {
            CGImageRelease(image);
        }
        return nil;
    }

    if (format == 0 || format == 1) {
        UIImage *thumbnail = [UIImage imageWithCGImage:image];
        NSData *data = format == 0
            ? UIImageJPEGRepresentation(thumbnail, quality / 100.0)
            : UIImagePNGRepresentation(thumbnail);
        CGImageRelease(image);
        return data;
    }

#if YM_VIDEO_THUMBNAIL_HAS_WEBP
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    size_t bytesPerRow = width * 4;
    NSMutableData *rgbaData = [NSMutableData dataWithLength:bytesPerRow * height];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(
        rgbaData.mutableBytes,
        width,
        height,
        8,
        bytesPerRow,
        colorSpace,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if (context == NULL) {
        CGColorSpaceRelease(colorSpace);
        CGImageRelease(image);
        return nil;
    }

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    uint8_t *output = NULL;
    size_t outputSize = quality >= 100
        ? WebPEncodeLosslessRGBA(rgbaData.bytes, (int)width, (int)height,
                                 (int)bytesPerRow, &output)
        : WebPEncodeRGBA(rgbaData.bytes, (int)width, (int)height,
                         (int)bytesPerRow, (float)quality, &output);
    NSData *data = outputSize > 0
        ? [NSData dataWithBytes:output length:outputSize]
        : nil;
    if (output != NULL) {
        WebPFree(output);
    }
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(image);
    return data;
#else
    CGImageRelease(image);
    return nil;
#endif
}

+ (void)finishOnMain:(FlutterResult)result
             success:(id)value
               error:(FlutterError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        result(error == nil ? value : error);
    });
}

@end
