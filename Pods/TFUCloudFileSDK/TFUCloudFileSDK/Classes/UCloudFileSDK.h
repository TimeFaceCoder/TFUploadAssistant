//
//  UCloudFileSDK.h
//  TFUploadAssistant
//
//  Created by 鲍振华 on 16/6/6.
//  Copyright © 2016年 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UFileAPI.h"

@interface UCloudFileSDK : NSObject

@property (nonatomic, copy) NSString * _Nullable bucket;
@property (nonatomic, copy) NSString * _Nullable publicKey;
@property (nonatomic, copy) NSString * _Nullable privateKey;

- (nonnull instancetype)initFromKeys:(NSString * _Nonnull)publicKey
                          privateKey:(NSString * _Nonnull)privateKey
                              bucket:(NSString * _Nonnull)bucket;

- (NSString * _Nonnull)calcKey:(NSString * _Nonnull)httpMethod
                           key:(NSString * _Nonnull)key
                    contentMd5:(NSString * _Nullable)contentMd5
                   contentType:(NSString * _Nullable)contentType;

@end
