//
//  TFConfiguration.h
//  TFUploadAssistant
//
//  Created by Melvin on 3/23/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, TFUploadType) {
    
    TFUploadTypeAliyun = 0,
   
    TFUploadTypeUCloud = 1,
    
    TFUploadTypeAmazon = 2
};


#define TFULogDebug(frmt, ...)\
if ([TFConfiguration isLogEnable]) {\
NSLog(@"[UploadAssistant Debug]: %@", [NSString stringWithFormat:(frmt), ##__VA_ARGS__]);\
}
static BOOL isEnable;
static uint32_t maxRequestCount = 5;

//图片压缩比例
static float compressionQuality = 1;

//启用压缩的阈值
static float imageDataThreshold = 2;

//是否使用WebP
static BOOL isUseWebP = NO;

@interface TFConfiguration : NSObject

@property (nonatomic ,copy) NSString *aliBucketHostId;
@property (nonatomic ,copy) NSString *aliEndPoint;
@property (nonatomic ,copy) NSString *aliBucket;
@property (nonatomic ,copy) NSString *aliAuthSTS;

@property (nonatomic ,copy) NSString *ucloudScheme;
@property (nonatomic ,copy) NSString *ucloudBucketHostId;
@property (nonatomic ,copy) NSString *ucloudBucketName;
@property (nonatomic ,copy) NSString *ucloudPublicKey;
@property (nonatomic ,copy) NSString *ucloudPrivateKey;

@property (nonatomic ,assign) TFUploadType uploadType;

+ (void)enableLog;
+ (void)disableLog;
+ (BOOL)isLogEnable;

/**
 *  设置最大并发数
 *
 *  @param count
 */
+ (void)setMaxConcurrentRequestCount:(uint32_t)count;

/**
 *  最大并发数
 *
 *  @return
 */
+ (uint32_t)maxConcurrentRequestCount;

/**
 *  设置图片压缩率
 *
 *  @param quality 压缩率 0 < q <= 1
 */
+ (void)setCompressionQuality:(float)quality;

+ (float)compressionQuality;

/**
 *  启用压缩的阈值
 *
 *  @param 比如大于1M 压缩
 */
+ (void)setImageDataThreshold:(float)threshold;

+ (float)imageDataThreshold;

/**
 *  是否使用WebP
 *
 *  @param 是否使用WebP 可设定
 */
+ (void)setIsUseWebP:(BOOL)useWebP;

+ (BOOL)isUseWebP;

@end
