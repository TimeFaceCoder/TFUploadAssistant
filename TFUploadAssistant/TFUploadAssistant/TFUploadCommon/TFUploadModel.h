//
//  TFUploadModel.h
//  TFUploadAssistant
//  上传文件属性
//  Created by Melvin on 3/24/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TFUploadModel : NSObject

+ (nonnull instancetype)fileModelWithObjectKey:(nonnull NSString *)key
                                   token:(nonnull NSString *)token
                              identifier:(nonnull NSString *)identifier;

@property (nonatomic ,copy ,nonnull) NSString *objectKey;
@property (nonatomic ,copy ,nonnull) NSString *objectKeyPath;
@property (nonatomic ,copy ,nonnull) NSString *token;
@property (nonatomic ,copy ,nonnull) NSString *md5;
/**
 *  唯一标示，可以是文件绝对路径，也可以是PHAsset localidentifier
 */
@property (nonatomic ,copy ,nonnull) NSString *identifier;
@end
