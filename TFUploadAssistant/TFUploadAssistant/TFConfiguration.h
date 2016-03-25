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

@interface TFConfiguration : NSObject

@property (nonatomic ,copy) NSString *aliBucketHostId;
@property (nonatomic ,copy) NSString *aliEndPoint;
@property (nonatomic ,copy) NSString *aliBucket;
@property (nonatomic ,copy) NSString *aliAuthSTS;

+ (void)enableLog;
+ (void)disableLog;
+ (BOOL)isLogEnable;

@end
