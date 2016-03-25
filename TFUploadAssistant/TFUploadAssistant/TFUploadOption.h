//
//  TFUploadOption.h
//  TFUploadAssistant
//
//  Created by Melvin on 3/23/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *    上传进度回调函数
 *
 *    @param key     上传时指定的存储key
 *    @param token   上传时指定的业务token
 *    @param percent 进度百分比
 */
typedef void (^TFUpProgressHandler)(NSString *key,NSString *token ,float percent);

/**
 *    上传中途取消函数
 *
 *    @return 如果想取消，返回True, 否则返回No
 */
typedef BOOL (^TFUpCancellationSignal)(void);

@interface TFUploadOption : NSObject
/**
 *  指定mime类型
 */
@property (copy, nonatomic, readonly) NSString *mimeType;

/**
 *    是否进行md5校验
 */
@property (readonly) BOOL checkMD5;

/**
 *    进度回调函数
 */
@property (copy, readonly) TFUpProgressHandler progressHandler;

/**
 *    中途取消函数
 */
@property (copy, readonly) TFUpCancellationSignal cancellationSignal;

/**
 *    可选参数的初始化方法
 *
 *    @param mimeType     mime类型
 *    @param progress     进度函数
 *    @param check        是否进行md5检查
 *    @param cancellation 中途取消函数
 *
 *    @return 可选参数类实例
 */
- (instancetype)initWithMime:(NSString *)mimeType
             progressHandler:(TFUpProgressHandler)progress
                    checkMD5:(BOOL)check
          cancellationSignal:(TFUpCancellationSignal)cancellation;

- (instancetype)initWithProgressHandler:(TFUpProgressHandler)progress;

/**
 *    内部使用，默认的参数实例
 *
 *    @return 可选参数类实例
 */
+ (instancetype)defaultOptions;

@end
