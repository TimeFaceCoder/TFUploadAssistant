//
//  TFAliOSSUpload.m
//  TFUploadAssistant
//
//  Created by Melvin on 3/23/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import "TFAliOSSUpload.h"
#import <AliyunOSSiOS/OSSService.h>
#import <AliyunOSSiOS/OSSCompat.h>
#import "TFUploadOption.h"
#import "TFConfiguration.h"
#import "TFUploadAssistant.h"
#import "TFResponseInfo.h"

@interface TFAliOSSUpload ()

@property (nonatomic, weak) NSData *data;
@property (nonatomic, strong) TFUploadOption *option;
@property (nonatomic, strong) TFConfiguration *config;
@property (nonatomic, strong) NSMutableDictionary *stats;
@property (nonatomic) int retryTimes;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) TFUpCompletionHandler complete;

@end

@implementation TFAliOSSUpload

- (instancetype) initWithData:(NSData *)data
                      withKey:(NSString *)key
                    withToken:(NSString *)token
        withCompletionHandler:(TFUpCompletionHandler)complete
                   withOption:(TFUploadOption *)option
            withConfiguration:(TFConfiguration *)config {
    if (self = [super init]) {
        _data = data;
        _key = key;
        _token = token;
        _complete = complete;
        _option = option;
        _config = config;
        _stats = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)put {
    __weak __typeof(self)weakSelf = self;
    //检测文件是否存在
    OSSClient *client = [[TFUploadAssistant sharedInstanceWithConfiguration:nil] client];
//    BOOL objectExist = [client doesObjectExistInBucket:_config.aliBucket objectKey:_key error:nil];
//    if (objectExist) {
//        return;
//    }
    
    OSSPutObjectRequest *put = [OSSPutObjectRequest new];
    put.contentType = _option.mimeType;
    put.bucketName = _config.aliBucket;
    put.objectKey = _key;
    put.uploadingData = _data;
    put.contentMd5 = [OSSUtil base64Md5ForData:put.uploadingData];
    put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        float progress = (float)totalByteSent/(float)totalBytesExpectedToSend;
        __typeof(&*weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            strongSelf.option.progressHandler(strongSelf.key,strongSelf.token,progress);
        }
    };
    OSSTask *putTask = [client putObject:put];
    [putTask continueWithBlock:^id(OSSTask *task) {
        __typeof(&*weakSelf) strongSelf = weakSelf;
        TFResponseInfo *info = nil;
        if (task.error) {
            OSSLogError(@"%@", task.error);
            info = [TFResponseInfo responseInfoWithNetError:task.error duration:0];
        }
        OSSPutObjectResult * result = task.result;
        if (result.httpResponseCode == 200) {
            //上传成功
            if (strongSelf) {
                strongSelf.complete(info,strongSelf.key,strongSelf.token,nil);
            }
        }
        NSLog(@"Result - requestId: %@, headerFields: %@",
              result.requestId,
              result.httpResponseHeaderFields);
        return nil;
    }];
}

@end
