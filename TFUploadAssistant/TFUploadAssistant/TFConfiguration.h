//
//  TFConfiguration.h
//  TFUploadAssistant
//
//  Created by Melvin on 3/23/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>

#define TFULogDebug(frmt, ...)\
if ([TFConfiguration isLogEnable]) {\
NSLog(@"[UploadAssistant Debug]: %@", [NSString stringWithFormat:(frmt), ##__VA_ARGS__]);\
}
static BOOL isEnable;
static uint32_t maxRequestCount = 5;

@interface TFConfiguration : NSObject

@property (nonatomic ,copy) NSString *aliBucketHostId;
@property (nonatomic ,copy) NSString *aliEndPoint;
@property (nonatomic ,copy) NSString *aliBucket;
@property (nonatomic ,copy) NSString *aliAuthSTS;

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
@end
