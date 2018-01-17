//
//  TFPHAssetFile.m
//  TFUploadAssistant
//
//  Created by Melvin on 3/23/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import "TFPHAssetFile.h"
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import "TFConfiguration.h"

enum {
    kAMASSETMETADATA_PENDINGREADS = 1,
    kAMASSETMETADATA_ALLFINISHED = 0
};

@interface TFPHAssetFile () {
    BOOL _hasGotInfo;
}

@property (nonatomic) PHAsset * phAsset;

@property (readonly) int64_t fileSize;


@property (readonly) int64_t fileModifyTime;
@property (readonly ) int64_t      fileCreatedTime;

@property (nonatomic, strong) NSData *assetData;

@property (nonatomic, strong) NSURL *assetURL;

@property (nonatomic, strong) NSDictionary *metadata;

@property (nonatomic, assign) UIImageOrientation imageOrientation;

@end

@implementation TFPHAssetFile

- (instancetype)init:(PHAsset *)phAsset error:(NSError *__autoreleasing *)error
{
    if (self = [super init]) {
        NSDate *createTime = phAsset.creationDate;
        NSDate *modifyTime = phAsset.modificationDate;
        
        int64_t t = 0;
        if (createTime != nil) {
            t = [createTime timeIntervalSince1970];
        }
        _fileCreatedTime = t;
        
        if (modifyTime != nil) {
            t = [modifyTime timeIntervalSince1970];
        }
        _fileModifyTime = t;
        
        _phAsset = phAsset;
        [self getInfo];
        
    }
    return self;
}

- (NSData *)read:(long)offset size:(long)size
{
    NSRange subRange = NSMakeRange(offset, size);
    if (!self.assetData) {
        self.assetData = [self fetchDataFromAsset:self.phAsset];
    }
    NSData *subData = [self.assetData subdataWithRange:subRange];
    
    return subData;
}

- (NSData *)readAll {
    if (!self.assetData) {
        self.assetData = [self fetchDataFromAsset:self.phAsset];
    }
    return self.assetData;
    return [self read:0 size:(long)_fileSize];
}

- (void)close {
}

-(NSString *)path {
    return self.assetURL.path;
}

- (NSString *)fileExtension {
    NSString *fileExtension = @"jpg";
    NSString * filename = [self.phAsset valueForKey:@"filename"];
    if (filename.length) {
        fileExtension = [filename pathExtension];
    }
    return fileExtension;
}
- (int64_t)modifyTime {
    return _fileModifyTime;
}

- (int64_t)createdTime {
    return _fileCreatedTime;
}


- (NSString *)mimeType {
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                            (__bridge CFStringRef)self.fileExtension, NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    
    NSString *mimeType = (__bridge NSString *)MIMEType;
    CFRelease(MIMEType);
    return mimeType;
}

- (int64_t)size {
    return _fileSize;
}


- (UIImageOrientation)orientation {
    return _imageOrientation;
}

- (void)getInfo
{
    if (!_hasGotInfo) {
        _hasGotInfo = YES;
        
        if (PHAssetMediaTypeImage == self.phAsset.mediaType) {
            PHImageRequestOptions *request = [PHImageRequestOptions new];
            request.version = PHImageRequestOptionsVersionCurrent;
            request.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            request.resizeMode = PHImageRequestOptionsResizeModeNone;
            request.networkAccessAllowed = YES;
            request.synchronous = YES;
            
            [[PHImageManager defaultManager] requestImageDataForAsset:self.phAsset
                                                              options:request
                                                        resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                                                            _imageOrientation = orientation;
                                                            _fileSize = imageData.length;
                                                            _assetURL = [NSURL URLWithString:self.phAsset.localIdentifier];
                                                        }
             ];
        }
        else if (PHAssetMediaTypeVideo == self.phAsset.mediaType) {
            PHVideoRequestOptions *request = [PHVideoRequestOptions new];
            request.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
            request.version = PHVideoRequestOptionsVersionCurrent;
            
            NSConditionLock* assetReadLock = [[NSConditionLock alloc] initWithCondition:kAMASSETMETADATA_PENDINGREADS];
            [[PHImageManager defaultManager] requestPlayerItemForVideo:self.phAsset options:request resultHandler:^(AVPlayerItem *playerItem, NSDictionary *info) {
                AVURLAsset *urlAsset = (AVURLAsset *)playerItem.asset;
                NSNumber *fileSize = nil;
                [urlAsset.URL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
                _fileSize = [fileSize unsignedLongLongValue];
                _assetURL = urlAsset.URL;
                
                [assetReadLock lock];
                [assetReadLock unlockWithCondition:kAMASSETMETADATA_ALLFINISHED];
            }];
            [assetReadLock lockWhenCondition:kAMASSETMETADATA_ALLFINISHED];
            [assetReadLock unlock];
            assetReadLock = nil;
        }
    }
    
}

- (NSData *)fetchDataFromAsset:(PHAsset *)asset
{
    __block NSData *tmpData = [NSData data];
    
    // Image
    if (asset.mediaType == PHAssetMediaTypeImage) {
        PHImageRequestOptions *request = [PHImageRequestOptions new];
        request.version = PHImageRequestOptionsVersionCurrent;
        request.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        request.resizeMode = PHImageRequestOptionsResizeModeNone;
        request.networkAccessAllowed = YES;
        request.synchronous = YES;
        
        
        [[PHImageManager defaultManager] requestImageDataForAsset:asset
                                                          options:request
                                                    resultHandler:
         ^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
             
             
             NSString *filename = [[asset valueForKey:@"filename"] lowercaseString];
             
             //BOOL isHEIF = [dataUTI isEqualToString:@"public.heic"] || [dataUTI isEqualToString:@"public.heif"];
             
             BOOL isHEIF = [filename containsString:@"heic"] || [filename containsString:@"heif"];
             
             // 将heic格式转成jpg
             CIImage *ciImage = [CIImage imageWithData:imageData];
             
             if (isHEIF) {
                 CIContext *context = [CIContext context];
                 tmpData = [context JPEGRepresentationOfImage:ciImage colorSpace:ciImage.colorSpace options:@{}];
             }
             else
             {
                 //CIImage *ciimage = [CIImage imageWithData:imageData];
                 NSDictionary *metaData = [[NSDictionary alloc] initWithDictionary:ciImage.properties];
                 
                 BOOL shotFromIphone = [self _isShotFromIphone:metaData];
                 
                 if (asset.pixelWidth <= 4096 * 4 &&
                     asset.pixelHeight <= 4096 * 4 &&
                     imageData.length <= 1024 * 1024 * [TFConfiguration imageDataThreshold]) {
                     
                     if(shotFromIphone)
                     {
                         tmpData = [self enhanceImage:imageData orientation:orientation phasset:asset];
                     }
                     else
                     {
                         tmpData = imageData;
                     }
                 }
                 else {
                     
                     @autoreleasepool {
                         
                         if(shotFromIphone)
                         {
                             //tmpData = [self enhanceAndCompress:imageData orientation:orientation phasset:asset];
                             tmpData = [self compressAndEnhance:imageData orientation:orientation phasset:asset];
                         }
                         else
                         {
                             tmpData = [self compressImage:imageData orientation:orientation phasset:asset];
                         }
                     };
                 }
             }
             
         }];
    }
    // Video
    else  {
        
        PHVideoRequestOptions *request = [PHVideoRequestOptions new];
        request.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
        request.version = PHVideoRequestOptionsVersionCurrent;
        
        NSConditionLock *assetReadLock = [[NSConditionLock alloc] initWithCondition:kAMASSETMETADATA_PENDINGREADS];
        
        
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset
                                                        options:request
                                                  resultHandler:
         ^(AVAsset* asset, AVAudioMix* audioMix, NSDictionary* info) {
             AVURLAsset *urlAsset = (AVURLAsset *)asset;
             NSData *videoData = [NSData dataWithContentsOfURL:urlAsset.URL];
             tmpData = [NSData dataWithData:videoData];
             
             [assetReadLock lock];
             [assetReadLock unlockWithCondition:kAMASSETMETADATA_ALLFINISHED];
         }];
        
        [assetReadLock lockWhenCondition:kAMASSETMETADATA_ALLFINISHED];
        [assetReadLock unlock];
        assetReadLock = nil;
    }
    
    return tmpData;
}

/**
 *  判断图片是否是iphone手机拍摄  没有经过处理
 *
 *  @param metaData 元数据
 *
 *  @return BOOL
 */
- (BOOL)_isShotFromIphone:(NSDictionary *)metaData
{
    NSArray* keyArray = [metaData allKeys];
    NSDictionary* tiff = [metaData objectForKey:@"{TIFF}"];
    NSString* make = [tiff objectForKey:@"Make"];
    NSString* model = [tiff objectForKey:@"Model"];
    
    if([make isEqualToString:@"Apple"] || [model containsString:@"iPhone"])
    {
        return YES;
    }
    
    return NO;
}

/**
 *  先压缩
 *
 *  @param imageData
 *  @param orientation
 *  @param asset
 *
 *  @return NSData
 */
- (NSData *)compressImage:(NSData *)imageData orientation:(UIImageOrientation)orientation phasset:(PHAsset *)asset
{
    //压缩
    CIImage *ciimage = [CIImage imageWithData:imageData];
    
    NSDictionary *metaData = [[NSDictionary alloc] initWithDictionary:ciimage.properties];
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData,  NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    NSData* tmpData = [self dataFromImage:imageRef
                                 metadata:metaData
                                 mimetype:self.mimeType
                                  phAsset:asset
                                 compress:YES];
    CFRelease(imageRef);
    CFRelease(imageSource);
    
    return tmpData;
}

/**
 *  小于1M的图片 只增强
 *
 *  @param data
 *  @param orientation
 *  @param asset
 *
 *  @return NSData
 */
- (NSData *)enhanceImage:(NSData *)data orientation:(UIImageOrientation)orientation phasset:(PHAsset *)asset
{
    
    NSData* tmpData = data;
    
    CIImage *enhanceImage = [CIImage imageWithData:tmpData];
    NSDictionary *metaData = [[NSDictionary alloc] initWithDictionary:enhanceImage.properties];
    
    NSDictionary *options = @{ CIDetectorImageOrientation : @([self CGImagePropertyOrientation:orientation])};
    NSArray *adjustments = [enhanceImage autoAdjustmentFiltersWithOptions:options];
    for (CIFilter *filter in adjustments) {
        [filter setValue:enhanceImage forKey:kCIInputImageKey];
        enhanceImage = filter.outputImage;
    }
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:enhanceImage fromRect:enhanceImage.extent];
    
    //这里主要是从CGImageRef获取NSData
    tmpData = [self dataFromImage:cgImage
                         metadata:metaData
                         mimetype:self.mimeType
                          phAsset:asset
                         compress:NO];
    
    CGImageRelease(cgImage);
    
    return tmpData;
}

/**
 *  先增强再压缩
 *
 *  @param imageData
 *  @param orientation
 *  @param asset
 *
 *  @return NSData
 */
- (NSData *)enhanceAndCompress:(NSData *)imageData orientation:(UIImageOrientation)orientation phasset:(PHAsset *)asset
{
    CIImage *ciimage = [CIImage imageWithData:imageData];
    
    NSDictionary *options = @{ CIDetectorImageOrientation : @([self CGImagePropertyOrientation:orientation])};;
    NSArray *adjustments = [ciimage autoAdjustmentFiltersWithOptions:options];
    for (CIFilter *filter in adjustments) {
        [filter setValue:ciimage forKey:kCIInputImageKey];
        ciimage = filter.outputImage;
    }
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:ciimage fromRect:ciimage.extent];
    
    NSDictionary *metaData = [[NSDictionary alloc] initWithDictionary:ciimage.properties];
    NSData* tmpData = [self dataFromImage:cgImage metadata:metaData mimetype:self.mimeType phAsset:asset compress:YES];
    CFRelease(cgImage);
    
    return tmpData;
}

/**
 *  先压缩再增强
 *
 *  @param imageData
 *  @param orientation
 *  @param asset
 *
 *  @return NSData
 */
- (NSData *)compressAndEnhance:(NSData *)imageData orientation:(UIImageOrientation)orientation phasset:(PHAsset *)asset
{
    //压缩
    CIImage *ciimage = [CIImage imageWithData:imageData];
    
    NSDictionary *metaData = [[NSDictionary alloc] initWithDictionary:ciimage.properties];
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData,  NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    NSData* tmpData = [self dataFromImage:imageRef
                                 metadata:metaData
                                 mimetype:self.mimeType
                                  phAsset:asset
                                 compress:YES];
    CFRelease(imageRef);
    CFRelease(imageSource);
    
    //增强
    CIImage *enhanceImage = [CIImage imageWithData:tmpData];
    NSDictionary *options = @{ CIDetectorImageOrientation : @([self CGImagePropertyOrientation:orientation])};
    NSArray *adjustments = [enhanceImage autoAdjustmentFiltersWithOptions:options];
    for (CIFilter *filter in adjustments) {
        [filter setValue:enhanceImage forKey:kCIInputImageKey];
        enhanceImage = filter.outputImage;
    }
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:enhanceImage fromRect:enhanceImage.extent];
    
    //这里主要是从CGImageRef获取NSData
    tmpData = [self dataFromImage:cgImage
                         metadata:metaData
                         mimetype:self.mimeType
                          phAsset:asset
                         compress:NO];
    
    CGImageRelease(cgImage);
    
    return tmpData;
}

- (CGImagePropertyOrientation)CGImagePropertyOrientation:(UIImageOrientation)imageOrientation
{
    switch (imageOrientation) {
        case UIImageOrientationUp:
            return kCGImagePropertyOrientationUp;
        case UIImageOrientationUpMirrored:
            return kCGImagePropertyOrientationUpMirrored;
        case UIImageOrientationDown:
            return kCGImagePropertyOrientationDown;
        case UIImageOrientationDownMirrored:
            return kCGImagePropertyOrientationDownMirrored;
        case UIImageOrientationLeftMirrored:
            return kCGImagePropertyOrientationLeftMirrored;
        case UIImageOrientationRight:
            return kCGImagePropertyOrientationRight;
        case UIImageOrientationRightMirrored:
            return kCGImagePropertyOrientationRightMirrored;
        case UIImageOrientationLeft:
            return kCGImagePropertyOrientationLeft;
    }
}

- (NSData *)dataFromImage:(CGImageRef)imageRef
                 metadata:(NSDictionary *)metadata
                 mimetype:(NSString *)mimetype
                  phAsset:(PHAsset *)asset
                 compress:(BOOL)compress
{
    @autoreleasepool {
        
        NSMutableData *imageData = [NSMutableData data];
        
        CFMutableDictionaryRef properties = CFDictionaryCreateMutable(nil, 0,
                                                                      &kCFTypeDictionaryKeyCallBacks,  &kCFTypeDictionaryValueCallBacks);
        
        
        
        for (NSString *key in metadata) {
            CFDictionarySetValue(properties, (__bridge const void *)key,
                                 (__bridge const void *)[metadata objectForKey:key]);
        }
        
        if(asset.pixelWidth > 4096 * 4 || asset.pixelHeight > 4096 * 4)
        {
            CFDictionarySetValue(properties, kCGImageDestinationImageMaxPixelSize,
                                 (__bridge const void *)(@(4096 * 4)));
        }
        
        if(compress)
        {
            CFDictionarySetValue(properties, kCGImageDestinationLossyCompressionQuality,
                                 (__bridge const void *)([NSNumber numberWithFloat:[TFConfiguration compressionQuality]]));
        }
        
        
        CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)mimetype, NULL);
        CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, uti, 1, NULL);
        
        if (imageDestination == NULL) {
            TFULogDebug(@"Failed to create image destination");
            imageData = nil;
        }
        else {
            CGImageDestinationAddImage(imageDestination, imageRef, properties);
            if (CGImageDestinationFinalize(imageDestination) == NO) {
                TFULogDebug(@"Failed to finalise");
                imageData = nil;
            }
        }
        CFRelease(properties);
        CFRelease(imageDestination);
        CFRelease(uti);
        return imageData;
    };
}

@end

