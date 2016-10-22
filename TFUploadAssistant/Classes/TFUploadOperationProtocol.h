//
//  TFUploadOperationProtocol.h
//  TFUploadAssistant
//
//  Created by 鲍振华 on 16/5/27.
//  Copyright © 2016年 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TFResponseInfo;
@class TFUploadOption;
@class TFConfiguration;
@class PHAsset;
@class OSSClient;
/**
 *    上传完成后的回调函数
 *
 *    @param info 上下文信息，包括状态码，错误值
 *    @param key  上传时指定的key，原样返回
 *    @param token  上传时指定的token，原样返回
 *    @param success 上传是否成功
 */
typedef void (^TFUpCompletionHandler)(TFResponseInfo * _Nullable info, NSString * _Nullable key, NSString * _Nullable token,BOOL success);

/**
 *  上传进度
 *
 *  @param key     上传时指定的key，原样返回
 *  @param token   上传时指定的token，原样返回
 *  @param percent 上传百分比
 */
typedef void (^TFUpProgressHandler)(NSString * _Nullable key,NSString * _Nullable token ,float percent);

@protocol TFUploadOperationProtocol <NSObject>

- (nonnull instancetype) initWithData:(nonnull NSData *)data
                                  key:(nonnull NSString *)key
                                token:(nonnull NSString *)token
                             progress:(nonnull TFUpProgressHandler)progressHandler
                             complete:(nonnull TFUpCompletionHandler)completionHandler
                               config:(nonnull TFConfiguration *)configuration;

+ (nonnull instancetype)uploadOperationWithData:(nonnull NSData *)data
                                            key:(nonnull NSString *)key
                                          token:(nonnull NSString *)token
                                       progress:(nonnull TFUpProgressHandler)progressHandler
                                       complete:(nonnull TFUpCompletionHandler)completionHandler
                                         config:(nonnull TFConfiguration *)configuration;

- (void)start;

@end
