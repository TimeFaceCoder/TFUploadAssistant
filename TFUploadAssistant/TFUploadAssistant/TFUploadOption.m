//
//  TFUploadOption.m
//  TFUploadAssistant
//
//  Created by Melvin on 3/23/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import "TFUploadOption.h"
#import "TFUploadAssistant.h"

static NSString *mime(NSString *mimeType) {
    if (mimeType == nil || [mimeType isEqualToString:@""]) {
        return @"application/octet-stream";
    }
    return mimeType;
}


@implementation TFUploadOption

+ (NSDictionary *)filteParam:(NSDictionary *)params {
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    if (params == nil) {
        return ret;
    }
    
    [params enumerateKeysAndObjectsUsingBlock: ^(NSString *key, NSString *obj, BOOL *stop) {
        if ([key hasPrefix:@"x:"] && ![obj isEqualToString:@""]) {
            ret[key] = obj;
        }
    }];
    
    return ret;
}

- (instancetype)initWithProgessHandler:(TFUpProgressHandler)progress {
    return [self initWithMime:nil progressHandler:progress checkMD5:NO cancellationSignal:nil];
}

- (instancetype)initWithProgressHandler:(TFUpProgressHandler)progress {
    return [self initWithMime:nil progressHandler:progress checkMD5:NO cancellationSignal:nil];
}

- (instancetype)initWithMime:(NSString *)mimeType
             progressHandler:(TFUpProgressHandler)progress
                    checkMD5:(BOOL)check
          cancellationSignal:(TFUpCancellationSignal)cancellation {
    if (self = [super init]) {
        _mimeType = mime(mimeType);
        _progressHandler = progress != nil ? progress : ^(NSString *key, NSString *token,float percent) {
        };
        _checkMD5 = check;
        _cancellationSignal = cancellation != nil ? cancellation : ^BOOL () {
            return NO;
        };
    }
    
    return self;
}

+ (instancetype)defaultOptions {
    return [[TFUploadOption alloc] initWithMime:nil progressHandler:nil checkMD5:NO cancellationSignal:nil];
}


@end
