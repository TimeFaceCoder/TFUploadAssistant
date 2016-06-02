//
//  TFUcloudUploadOperation.m
//  TFUploadAssistant
//
//  Created by 鲍振华 on 16/5/27.
//  Copyright © 2016年 TimeFace. All rights reserved.
//

#import "TFUcloudUploadOperation.h"
#import "TFConfiguration.h"
#import "TFUploadAssistant-Swift.h"
#import "UFileAPIUtils.h"

@interface TFUcloudUploadOperation ()

@property (nonatomic, strong) TFConfiguration *config;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSMutableDictionary *stats;
@property (nonatomic) int retryTimes;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) TFUpProgressHandler progressHandler;
@property (nonatomic, copy) TFUpCompletionHandler completionHandler;

@property (nonatomic ,strong) UFileSDK* uFileSDK;

@end

@implementation TFUcloudUploadOperation

- (instancetype) initWithData:(nonnull NSData *)data
                          key:(nonnull NSString *)key
                        token:(nonnull NSString *)token
                     progress:(nonnull TFUpProgressHandler)progressHandler
                     complete:(nonnull TFUpCompletionHandler)completionHandler
                       config:(nonnull TFConfiguration *)configuration {
    if (self = [super init]) {
        _data = data;
        _key = key;
        _token = token;
        _progressHandler = progressHandler;
        _completionHandler = completionHandler;
        _config = configuration;
        _stats = [[NSMutableDictionary alloc] init];
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
    
    TFUcloudUploadOperation *operation = [[TFUcloudUploadOperation alloc] initWithData:data
                                                                             key:key
                                                                           token:token
                                                                        progress:progressHandler
                                                                        complete:completionHandler
                                                                          config:configuration];
    return operation;
}

-(UFileSDK*)uFileSDK
{
    if(!_uFileSDK)
    {
        _uFileSDK = [[UFileSDK alloc] initFromKeys:_config.ucloudPublicKey
                                        privateKey:_config.ucloudPrivateKey
                                            bucket:_config.ucloudBucketName];
    }
    return _uFileSDK;
}

- (void)start
{
    [self objectExist:_key completionBlock:^(BOOL result) {
        if (result) {
            _progressHandler(_key,_token,1);
            _completionHandler(nil,_key,_token,YES);
            NSLog(@"object :%@ exist",_key);
            return;
        }else{
        
            NSString* url = @"http://ufile.ucloud.cn";
            UFileAPI* uFileAPI = [[UFileAPI alloc] initWithBucket:_config.ucloudBucketName url:url];
            
            NSString* itMd5 = [UFileAPIUtils calcMD5ForData:_data];
            NSDictionary* option = @{kUFileSDKOptionMD5: itMd5, kUFileSDKOptionFileType: @"image/jpeg"};
            NSString* authorization = [self.uFileSDK calcKey:@"POST"
                                                         key:_key
                                                  contentMd5:itMd5
                                                 contentType:@"image/jpeg"];
            
            [uFileAPI putFile:_key
                authorization:authorization
                       option:option
                         data:_data
                     progress:^(NSProgress * process){
                         _progressHandler(_key, _token, process.fractionCompleted);
                      }
                      success:^(NSDictionary* _Nonnull response){
                          
                          NSLog(@"%@", response);
                          
                          _completionHandler(nil,_key,_token,YES);
                      }
                      failure:^(NSError * _Nonnull error){
                          
                          _completionHandler(nil,_key,_token, NO);
                      }];
        }
     }];
}

- (BOOL)objectExist:(NSString *)objectKey
    completionBlock:(void (^)(BOOL result))completionBlock {
    NSString *url = [NSString stringWithFormat:@"http://%@.%@/%@",_config.ucloudBucketName, _config.ucloudBucketHostId,objectKey];
    NSLog(@"%@", url);
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

@end
