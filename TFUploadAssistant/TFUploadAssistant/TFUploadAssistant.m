//
//  TFUploadAssistant.m
//  TFUploadAssistant
//
//  Created by Melvin on 3/23/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import "TFUploadAssistant.h"
#import "TFConfiguration.h"
#import "TFAsyncRun.h"
#import "TFFile.h"
#import "TFFileProtocol.h"
#import "TFResponseInfo.h"
#import "TFAliUploadOperation.h"
#import "TFAliOSSUpload.h"
#import "TFPHAssetFile.h"
#import "TFUploadOption.h"
#import "TFFileRecorder.h"
#import <AliyunOSSiOS/OSSService.h>
#import <AliyunOSSiOS/OSSCompat.h>
#import <AFNetworking/AFNetworking.h>
#import "TFAliUploadHandler.h"
#import <Photos/Photos.h>


NSString * const kTFUploadOperationsKey      = @"kTFUploadOperationsKey";
NSString * const kTFUploadFaildOperationsKey = @"kTFUploadFaildOperationsKey";

@interface TFUploadAssistant()<NSURLSessionDelegate>

@property (nonatomic ,strong) TFConfiguration     *configuration;
@property (nonatomic ,strong) NSMutableDictionary *uploadHandlers;
@property (nonatomic ,strong) NSMutableDictionary *uploadOperations;
@property (nonatomic ,strong) NSMutableDictionary *faildOperations;
@property (nonatomic ,strong) NSMutableDictionary *progressHandlers;
@property (nonatomic ,strong) NSOperationQueue    *operationQueue;
@property (nonatomic ,assign) float               currentprogress;

@end

@implementation TFUploadAssistant

- (instancetype)initWithConfiguration:(TFConfiguration *)config {
    if (self = [super init]) {
        _configuration = config;
        _uploadHandlers = [NSMutableDictionary dictionary];
        _progressHandlers = [NSMutableDictionary dictionary];
        _operationQueue = [[NSOperationQueue alloc] init];
        _uploadOperations = [NSMutableDictionary dictionary];
        _faildOperations = [[TFFileRecorder sharedInstance] get:kTFUploadFaildOperationsKey];
        if (!_faildOperations) {
            _faildOperations = [NSMutableDictionary dictionary];
        }
        [self initOSSService];
        
        [self checkTask];
    }
    return self;
}

+ (instancetype)sharedInstanceWithConfiguration:(TFConfiguration *)config {
    static TFUploadAssistant *sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithConfiguration:config];
    });
    
    return sharedInstance;
}

+ (BOOL)checkAndNotifyError:(NSString *)key
                      token:(NSString *)token
                      input:(NSObject *)input
                   complete:(TFUpCompletionHandler)completionHandler {
    NSString *desc = nil;
    if (completionHandler == nil) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"no completionHandler" userInfo:nil];
        return YES;
    }
    if (input == nil) {
        desc = @"no input data";
    }
    else if (token == nil || [token isEqualToString:@""]) {
        desc = @"no token";
    }
    if (desc != nil) {
        completionHandler([TFResponseInfo responseInfoWithInvalidArgument:desc], key,token, nil);
        return YES;
    }
    return NO;
}

- (void) putData:(NSData *)data
             key:(NSString *)key
           token:(NSString *)token
        progress:(TFUpProgressHandler)progressHandler
      completion:(TFUpCompletionHandler)completionHandler {
    if ([TFUploadAssistant checkAndNotifyError:key token:token input:data complete:completionHandler]) {
        return;
    }
    TFAliUploadOperation *uploadOperation = [TFAliUploadOperation uploadOperationWithData:data
                                                                                      key:key
                                                                                    token:token
                                                                                 progress:progressHandler
                                                                                 complete:completionHandler
                                                                                   config:_configuration];
    
    __weak __typeof(self)weakSelf = self;
    TFAsyncRun(^{
        __typeof(&*weakSelf) strongSelf = weakSelf;
        [strongSelf cacheOperationsByToken:token identifier:key];
        [uploadOperation start];
    });

}

- (void) putFile:(NSString *)filePath
             key:(NSString *)key
           token:(NSString *)token
        progress:(TFUpProgressHandler)progressHandler
      completion:(TFUpCompletionHandler)completionHandler {
    if ([TFUploadAssistant checkAndNotifyError:key token:token input:filePath complete:completionHandler]) {
        return;
    }
    @autoreleasepool {
        NSError *error = nil;
        __block TFFile *file = [[TFFile alloc] init:filePath error:&error];
        if (error) {
            TFAsyncRunInMain( ^{
                TFResponseInfo *info = [TFResponseInfo responseInfoWithFileError:error];
                completionHandler(info, key, token, NO);
            });
            return;
        }
        [self putFileInternal:file key:key token:token progress:progressHandler complete:completionHandler];
    }
}

- (void) putPHAssets:(NSArray *)assets
                keys:(NSArray *)keys
               token:(NSString *)token
            delegate:(id<TFUploadAssistantDelegate>)delegate {
    if (delegate) {
        [self attachListener:delegate token:token];
        [self putPHAssets:assets keys:keys token:token progress:nil completion:nil];
    }
}
- (void) putPHAssets:(NSArray *)assets
                keys:(NSArray *)keys
               token:(NSString *)token
            progress:(TFUpProgressHandler)progressHandler
          completion:(TFUpCompletionHandler)completionHandler {
    NSInteger index = 0;
    //创建进度管理
    NSMutableDictionary *progressDic = [_progressHandlers objectForKey:token];
    if (!progressDic) {
        progressDic = [NSMutableDictionary new];
        [_progressHandlers setObject:progressDic forKey:token];
    }
    for (PHAsset *asset in assets) {
        //添加默认进度0
        [progressDic setObject:[NSNumber numberWithFloat:0] forKey:[keys objectAtIndex:index]];
        [self putPHAsset:asset
                     key:[keys objectAtIndex:index]
                   token:token
                progress:progressHandler
              completion:completionHandler];
        index ++;
    }
    
}

- (void) putPHAsset:(PHAsset *)asset
                key:(NSString *)key
              token:(NSString *)token
           progress:(TFUpProgressHandler)progressHandler
         completion:(TFUpCompletionHandler)completionHandler {
    @autoreleasepool {
        NSError *error = nil;
        __block TFPHAssetFile *file = [[TFPHAssetFile alloc] init:asset error:&error];
        if (error) {
            TFAsyncRunInMain( ^{
                TFResponseInfo *info = [TFResponseInfo responseInfoWithFileError:error];
                completionHandler(info, key, token, NO);
            });
            return;
        }
        [self putFileInternal:file key:key token:token progress:progressHandler complete:completionHandler];
    }
}

- (void) attachListener:(id<TFUploadAssistantDelegate>)listener token:(NSString *)token {
    [self removeHandlerWithListener:listener];
    NSMutableArray *handlers = [self.uploadHandlers objectForKey:token];
    if (!handlers) {
        handlers = [NSMutableArray array];
    }
    TFAliUploadHandler *handler = [TFAliUploadHandler uploadHandlerWithToken:token delegate:listener];
    [handlers addObject:handler];
    [self.uploadHandlers setObject:handlers forKey:token];
}

- (void) detachListener:(id<TFUploadAssistantDelegate>)listener {
    [self removeHandlerWithListener:listener];
}

#pragma mark - Private



#pragma mark -
#pragma mark Global Blocks

void (^GlobalProgressBlock)(NSString *key,NSString *token ,float percent ,TFUploadAssistant* self) =
^(NSString *key,NSString *token ,float percent ,TFUploadAssistant* self)
{
    NSMutableArray *handlers = [self.uploadHandlers objectForKey:token];
    //Inform the handlers
    [handlers enumerateObjectsUsingBlock:^(TFAliUploadHandler *handler, NSUInteger idx, BOOL *stop) {
        if(handler.progressHandler) {
            handler.progressHandler(key, token,percent);
        }
        if([handler.delegate respondsToSelector:@selector(uploadAssistantProgressHandler:token:percent:)]) {
            [handler.delegate uploadAssistantProgressHandler:key token:token percent:percent];
        }
    }];
};
void (^GlobalCompletionBlock)(TFResponseInfo *info, NSString *key, NSString *token,BOOL success, TFUploadAssistant* self) =
^(TFResponseInfo *info, NSString *key, NSString *token,BOOL success, TFUploadAssistant* self)
{
    NSMutableArray *handlers = [self.uploadHandlers objectForKey:token];
    //Inform the handlers
    [handlers enumerateObjectsUsingBlock:^(TFAliUploadHandler *handler, NSUInteger idx, BOOL *stop) {
        if(handler.completionHandler) {
            handler.completionHandler(info,key,token,success);
        }
        if([handler.delegate respondsToSelector:@selector(uploadAssistantCompletionHandler:key:token:success:)]) {
            [handler.delegate uploadAssistantCompletionHandler:info key:key token:token success:success];
        }
    }];
    //Remove the upload handlers
    [self.uploadHandlers removeObjectForKey:token];
};


#pragma mark - 移除监听

- (void)removeHandlerWithListener:(id)listener {
    for (NSInteger i = self.uploadHandlers.allKeys.count - 1; i >= 0; i-- ) {
        id key = self.uploadHandlers.allKeys[i];
        NSMutableArray *array = [self.uploadHandlers objectForKey:key];
        for (NSInteger j = array.count - 1; j >= 0; j-- ) {
            TFAliUploadHandler *handler = array[j];
            if (handler.delegate == listener) {
                [array removeObject:handler];
            }
        }
    }
}


- (void) putFileInternal:(id<TFFileProtocol>)file
                     key:(NSString *)key
                   token:(NSString *)token
                progress:(TFUpProgressHandler)progressHandler
                complete:(TFUpCompletionHandler)completionHandler {
    TFUpCompletionHandler checkComplete = ^(TFResponseInfo *info, NSString *key, NSString * token,BOOL success)
    {
        [file close];
        completionHandler(info, key, token,success);
    };
    NSData *data = [file readAll];
    //check file
    if ([TFUploadAssistant checkAndNotifyError:key token:token input:data complete:checkComplete]) {
        return;
    }
    if ([data length] == 0) {
        //file is nil
        completionHandler([TFResponseInfo responseInfoOfZeroData:nil], key, token, nil);
        return;
    }
    if (!progressHandler) {
        progressHandler = ^(NSString *key,NSString *token ,float percent) {
            [self calculateTotalProgress:token key:key progress:percent];
        };
    }
    __weak __typeof(self)weakSelf = self;
    TFUpCompletionHandler uploadComplete = ^(TFResponseInfo *info, NSString *key, NSString *token, BOOL success){
        //remove from operations
        __typeof(&*weakSelf) strongSelf = weakSelf;
        [strongSelf removeOperationsByToken:token identifier:key];
        if (completionHandler) {
            completionHandler(info,key,token,success);
        }
        if (!success) {
            //上传失败,加入错误列表
            [strongSelf cacheFaildOperationsByToken:token objectKey:key filePath:[file path]];
        }
    };
    [self putData:data key:key token:token progress:progressHandler completion:uploadComplete];
}

#pragma mark - 计算总体进度

- (void)calculateTotalProgress:(NSString *)token key:(NSString *)key progress:(float)progress {
    NSMutableDictionary *progressEntry = [_progressHandlers objectForKey:token];
    [progressEntry setObject:[NSNumber numberWithFloat:progress] forKey:key];
    float count = [[progressEntry allKeys] count];
    float currentPorgress = 0;
    for (NSString *key in [progressEntry allKeys]) {
        currentPorgress += [[progressEntry objectForKey:key] floatValue];
    }
    float newProgress = (currentPorgress / count);
    GlobalProgressBlock(key,token,newProgress,self);
}

#pragma mark - 缓存任务列表

- (void)cacheOperationsByToken:(NSString *)token identifier:(NSString *)identifier {
    NSMutableArray *array = [_uploadOperations objectForKey:token];
    if (!array) {
        array = [NSMutableArray array];
        [_uploadOperations setObject:array forKey:token];
    }
    //添加至任务列表
    if (![array containsObject:identifier]) {
        [array addObject:identifier];
    }
    //save to disk
    [[TFFileRecorder sharedInstance] set:kTFUploadOperationsKey object:_uploadOperations];
}

- (void)removeOperationsByToken:(NSString *)token identifier:(NSString *)identifier {
    NSMutableArray *array = [_uploadOperations objectForKey:token];
    if (array) {
        [array removeObject:identifier];
        //save to disk
        [[TFFileRecorder sharedInstance] set:kTFUploadOperationsKey object:_uploadOperations];
        if ([array count] == 0) {
            //all task is over in this token
            GlobalCompletionBlock(nil,nil,token,nil,self);
        }
    }
}

- (void)cacheFaildOperationsByToken:(NSString *)token objectKey:(NSString *)objectKey filePath:(NSString *)filePath {
    NSMutableDictionary *entry = [_faildOperations objectForKey:token];
    if (!entry) {
        entry = [NSMutableDictionary dictionary];
        [_faildOperations setObject:entry forKey:token];
    }
    //添加至任务列表
    [entry setObject:filePath forKey:objectKey];
    //save to disk
    [[TFFileRecorder sharedInstance] set:kTFUploadFaildOperationsKey object:_faildOperations];
}

- (void)removeFaildOperationsByToken:(NSString *)token objectKey:(NSString *)objectKey {
    NSMutableDictionary *entry = [_faildOperations objectForKey:token];
    if (entry) {
        [entry removeObjectForKey:objectKey];
    }
    //{objectkey:filepath}
    [_faildOperations setObject:entry forKey:token];
    //save to disk
    [[TFFileRecorder sharedInstance] set:kTFUploadFaildOperationsKey object:_faildOperations];
}
#pragma mark - 检测未完成任务列表

- (void)checkTask {
    __weak __typeof(self)weakSelf = self;
    TFAsyncRun(^{
        __typeof(&*weakSelf) strongSelf = weakSelf;
        @autoreleasepool {
            NSMutableDictionary *faildOperations = [[TFFileRecorder sharedInstance] get:kTFUploadFaildOperationsKey];
            if (faildOperations) {
                for (NSString *token in [faildOperations allKeys]) {
                    NSMutableDictionary *entry = [faildOperations objectForKey:token];
                    //{objectkey:filepath}
                    if (entry) {
                        for (NSString *objectKey in entry) {
                            NSString *filePath = [entry objectForKey:objectKey];
                            //PHAsset URL
                            PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[filePath] options:nil];
                            if ([fetchResult count] > 0) {
                                PHAsset *asset = [fetchResult objectAtIndex:0];
                                [strongSelf putPHAsset:asset
                                                   key:objectKey
                                                 token:token
                                              progress:NULL completion:^(TFResponseInfo *info, NSString *key, NSString *token, BOOL success) {
                                                  if (success) {
                                                      [strongSelf removeFaildOperationsByToken:token objectKey:objectKey];
                                                  }
                                              }];
                            }
                        }
                    }
                }
            }
        }
        
    });
    
}

#pragma mark - 初始化阿里云服务

- (void)initOSSService {
    id<OSSCredentialProvider> credential = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * {
        NSURL * url = [NSURL URLWithString:_configuration.aliAuthSTS];
        NSURLRequest * request = [NSURLRequest requestWithURL:url];
        OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
        NSURLSessionConfiguration  *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession * session = [NSURLSession sessionWithConfiguration:configuration
                                                               delegate:self
                                                          delegateQueue:[NSOperationQueue mainQueue]];
        NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                    completionHandler:^(NSData *data,
                                                                        NSURLResponse *response,
                                                                        NSError *error)
                                          {
                                              if (error) {
                                                  [tcs setError:error];
                                                  return;
                                              }
                                              [tcs setResult:data];
                                          }];
        [sessionTask resume];
        [tcs.task waitUntilFinished];
        if (tcs.task.error) {
            return nil;
        } else {
            NSDictionary *object = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                                   options:kNilOptions
                                                                     error:nil];
            OSSFederationToken *token         = [OSSFederationToken new];
            token.tAccessKey                  = [object objectForKey:@"tempAK"];
            token.tSecretKey                  = [object objectForKey:@"tempSK"];
            token.tToken                      = [object objectForKey:@"token"];
            token.expirationTimeInMilliSecond = [[object objectForKey:@"expiration"] longLongValue]*1000;
            return token;
        }
    }];
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    _client = [[OSSClient alloc] initWithEndpoint:_configuration.aliEndPoint
                               credentialProvider:credential
                              clientConfiguration:conf];
}


#pragma mark - NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * __nullable credential))completionHandler {
    NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential , credential);
}


@end
