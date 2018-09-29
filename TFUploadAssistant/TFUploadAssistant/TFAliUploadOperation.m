//
//  TFAliUploadOperation.m
//  TFUploadAssistant
//
//  Created by Melvin on 3/23/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import "TFAliUploadOperation.h"
#import <AliyunOSSiOS/OSSService.h>
#import <AliyunOSSiOS/OSSCompat.h>
#import "TFConfiguration.h"
#import "TFUploadAssistant.h"
#import "TFResponseInfo.h"
#import "TFFileRecorder.h"

@interface TFAliUploadOperation()

@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) TFConfiguration *config;
@property (nonatomic, strong) NSMutableDictionary *stats;
@property (nonatomic) int retryTimes;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) TFUpProgressHandler progressHandler;
@property (nonatomic, copy) TFUpCompletionHandler completionHandler;

@property (nonatomic, strong) NSMutableArray* correctImageKeyArray;

@end

@implementation TFAliUploadOperation

- (instancetype) initWithData:(nonnull NSData *)data
                          key:(nonnull NSString *)key
                        token:(nonnull NSString *)token
                     progress:(nonnull TFUpProgressHandler)progressHandler
                     complete:(nonnull TFUpCompletionHandler)completionHandler
                       config:(nonnull TFConfiguration *)configuration {
    if (self = [super init]) {
        @synchronized (self) {
            _data = data;
            _key = key;
            _token = token;
            _progressHandler = progressHandler;
            _completionHandler = completionHandler;
            _config = configuration;
            _stats = [[NSMutableDictionary alloc] init];
            _correctImageKeyArray = [[TFFileRecorder sharedInstance] get:@"kTFALIPhotoStatus"];
            TFULogDebug(@"%@", @(_correctImageKeyArray.count));
        };
    }
    return self;
}

- (instancetype)init
{
    if (self = [super init]) {
        
    }
    return self;
}

+ (nonnull instancetype)uploadOperationWithData:(nonnull NSData *)data
                                            key:(nonnull NSString *)key
                                          token:(nonnull NSString *)token
                                       progress:(nonnull TFUpProgressHandler)progressHandler
                                       complete:(nonnull TFUpCompletionHandler)completionHandler
                                         config:(nonnull TFConfiguration *)configuration {
    
    TFAliUploadOperation *operation = [[TFAliUploadOperation alloc] initWithData:data
                                                                             key:key
                                                                           token:token
                                                                        progress:progressHandler
                                                                        complete:completionHandler
                                                                          config:configuration];
    return operation;
}

- (void)_deleteErrorData
{
    __weak __typeof__(self) weakSelf = self;
    
    OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
    delete.bucketName = _config.aliBucket;
    delete.objectKey = _key;
    //delete.objectKey = @"times/87c9153fa7bb3bdfa41542784b5acfa9.jpg";
    //delete.objectKey = @"http://img1.timeface.cn/times/87c9153fa7bb3bdfa41542784b5acfa9.jpg";
    //delete.objectKey = [NSString stringWithFormat:@"http://%@.%@/%@",_config.aliBucket,_config.aliBucketHostId,_key];
    OSSClient *client = [[TFUploadAssistant sharedInstanceWithConfiguration:_config] client];
    OSSTask * deleteTask = [client deleteObject:delete];
    
    TFULogDebug(@"%@", delete.objectKey);
    
    [deleteTask continueWithBlock:^id(OSSTask *task) {
        
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        
        if (!task.error) {
 
            [self _uploadImage];
        }
        else
        {
            TFULogDebug(@"%@", task.error);
            TFULogDebug(@"删除失败");
        }
        return nil;
    }];
}

- (void)_uploadImage
{
    __weak __typeof__(self) weakSelf = self;
    
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    
    OSSPutObjectRequest *put = [OSSPutObjectRequest new];
    put.contentType = [OSSUtil detemineMimeTypeForFilePath:nil uploadName:_key];
    put.bucketName = _config.aliBucket;
    put.objectKey = _key;
    put.uploadingData = _data;
    put.contentMd5 = [OSSUtil base64Md5ForData:put.uploadingData];
    put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        float progress = (float)totalByteSent/(float)totalBytesExpectedToSend;
        _progressHandler(_key,_token,progress);
    };
    
    OSSClient *client = [[TFUploadAssistant sharedInstanceWithConfiguration:_config] client];
    
    OSSTask *putTask = [client putObject:put];
    [putTask continueWithBlock:^id(OSSTask *task) {
        
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        
        TFResponseInfo *info = nil;
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970];
        if (task.error) {
            //                    TFULogDebug(@"%@", task.error);
            info = [TFResponseInfo responseInfoWithNetError:task.error
                                                   duration:endTime - startTime];
        }
        OSSPutObjectResult * result = task.result;
        info = [[TFResponseInfo alloc] initWithStatusCode:result.httpResponseCode
                                             withDuration:endTime - startTime
                                                 withBody:nil];
        
        if (result.httpResponseCode == 200) {
            
            [strongSelf _checkDataError];
            
            //                    if (_completionHandler) {
            //                        _completionHandler(info,_key,_token,YES);
            //                    }
        }
        else
        {
            if (_completionHandler) {
                _completionHandler(info,_key,_token,NO);
            }
        }
        TFULogDebug(@"Result - requestId: %@ ",result.requestId);
        return nil;
    }];
}

- (void)start {
    
    if([self.correctImageKeyArray containsObject:_key])
    {
        _progressHandler(_key,_token,1);
        _completionHandler(nil,_key,_token,YES);
    }
    else
    {
        __weak __typeof(self)weakSelf = self;
        
        NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
        OSSClient *client = [[TFUploadAssistant sharedInstanceWithConfiguration:_config] client];
        //检测文件是否存在
        //_key = @"times/87c9153fa7bb3bdfa41542784b5acfa9.jpg";
        [self objectExist:_key completionBlock:^(BOOL result) {
            __strong __typeof__(weakSelf) strongSelf = weakSelf;
            
            if (result) {
                //图片存在还要判断图片是否是一张好图
                //先从EGOCache中判断，如果没有再网络检查，检查完后正确，再添加到EGOCache
                if(!strongSelf.correctImageKeyArray)
                {
                    [strongSelf _checkDataError];
                }
                else
                {
                    if(![strongSelf.correctImageKeyArray containsObject:_key])
                    {
                        [strongSelf _checkDataError];
                    }
                }
            }
            else {
                
                [self _uploadImage];
            }
        }];
    }
}

- (BOOL)objectExist:(NSString *)objectKey
    completionBlock:(void (^)(BOOL result))completionBlock {
    NSString *url = [NSString stringWithFormat:@"http://%@.%@/%@",_config.aliBucket,_config.aliBucketHostId,objectKey];
    
    __block BOOL result = NO;
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSURLSessionConfiguration  *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession * session = [NSURLSession sessionWithConfiguration:configuration];
    [request setHTTPMethod:@"HEAD"];
    NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data,
                                                                    NSURLResponse *response,
                                                                    NSError *error)
                                      {
                                          NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
                                          NSInteger code = [httpResponse statusCode];
                                          if (code != 200) {
                                              completionBlock(NO);
                                          }
                                          else {
                                              completionBlock(YES);
                                          }
                                      }];
    [sessionTask resume];
    return result;
}

- (BOOL)isMedia
{
    return [_key containsString:@"mov"] || [_key containsString:@"mp4"] || [_key containsString:@"m4r"] ||
           [_key containsString:@"m4a"] || [_key containsString:@"AAC"] || [_key containsString:@"mp3"] ||
           [_key containsString:@"wav"];
}

- (void)_checkDataError
{
    if([self isMedia])
    {
        _progressHandler(_key,_token,1);
        _completionHandler(nil,_key,_token,YES);
    }
    else
    {
        __weak __typeof(self)weakSelf = self;
        
        //1.确定请求路径
        //NSURL *url = [NSURL URLWithString:@"http://img1.timeface.cn/times/7cdf1482600ae771aa33fda575f434b8.jpg"];
        NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"http://img1.timeface.cn/%@@info",_key]];
        TFULogDebug(@"%@", url.absoluteString);
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error == nil) {
                
                __strong __typeof__(weakSelf) strongSelf = weakSelf;
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
                if(dict)
                {
                    _progressHandler(_key,_token,1);
                    _completionHandler(nil,_key,_token,YES);
                }
                else
                {
                    //[strongSelf _deleteErrorData];
                    [strongSelf _uploadImage];
                }
            }
        }];
        
        [dataTask resume];
    }
}

@end
