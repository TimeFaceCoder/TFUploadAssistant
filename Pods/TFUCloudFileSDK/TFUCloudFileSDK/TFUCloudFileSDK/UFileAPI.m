//
//  UFileAPI+Private.m
//  ufilesdk
//
//  Created by wu shauk on 12/11/15.
//  Copyright © 2015 ucloud. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CommonCrypto/CommonDigest.h>
#import "UFileAPI.h"
#import "UFileHttpManager.h"

static NSString * const kUFileRespHeaderEtag = @"ETag";
static NSString * const kUFileRespRetCode = @"RetCode";

NSString * const kUFileRespErrMsg = @"ErrMsg";
NSString * const kUFileRespXSession = @"x-session";
NSString * const kUFileRespHttpStatusCode = @"StatusCode";

#pragma -- Error domain define
NSString * const kUFileSDKAPIErrorDomain = @"UFile_SDK_API_ERROR";
NSString * const kUFileSDKHttpErrorDomain = @"UFile_SDK_HTTP_ERROR";


#pragma -- SDK options
NSString * const kUFileSDKOptionFileType = @"filetype";
NSString * const kUFileSDKOptionRange = @"range";
NSString * const kUFileSDKOptionModifiedSince = @"If-Modified-Since";
NSString * const kUFileSDKOptionMD5 = @"md5";


#pragma -- SDK resp
NSString * const kUFileRespFileType = @"filetype";
NSString * const kUFileRespETag = @"etag";
NSString * const kUFileRespLength = @"length";
NSString* const kUFileRespUploadId = @"UploadId";
NSString* const kUFileRespBlockSize = @"BlkSize";
NSString* const kUFileRespBucketName = @"Bucket";
NSString* const kUFileRespKeyName = @"Key";


@interface UFileAPI ()

@property (nonatomic, readwrite) UFileHttpManager* fileMgr;
@property (nonatomic, readwrite) NSURL * baseURL;
@property (nonatomic, readwrite) NSUInteger multipartRetryTimeLimit;
@property (nonatomic, readwrite) NSUInteger multipartRetryInterval;

@end


@implementation UFileAPI


- (instancetype) initWithBucket:(NSString* _Nonnull)bucket
{
    NSString * url = [NSString stringWithFormat:@"https://%@.ufilesec.ucloud.cn", bucket];
    return [self initWithBucket:bucket urlWithBucket:url];
}

- (instancetype)initWithBucket:(NSString *)bucket url:(NSString *)url
{
    NSArray * arr = [url componentsSeparatedByString:@"://"];
    assert(arr.count == 2);
    return [self initWithBucket:bucket
                  urlWithBucket:[NSString stringWithFormat:@"%@://%@.%@", arr[0], bucket, arr[1]]];
}

-(instancetype)initWithBucket:(NSString *)bucket urlWithBucket:(NSString *)url
{
    
    self.baseURL = [NSURL URLWithString:url];
    self.fileMgr = [[UFileHttpManager alloc] init];
    self.multipartRetryInterval = 5000;
    self.multipartRetryTimeLimit = 3;
    return self;
}

- (NSURL*)fileUrl:(NSString*)fileName params:(NSDictionary*)params
{
    NSMutableString* url = [NSMutableString stringWithString:UFilePercentEscapedStringFromString(fileName)];
    if (params != nil) {
        [url appendString:@"?"];
        BOOL first = YES;
        for (NSString* key in params) {
            if (first != YES) {
                [url appendString:@"&"];
            }
            first = NO;
            NSString* value = [params objectForKey:key];
            if (value.length == 0) {
                [url appendFormat:key];
            } else {
                [url appendFormat:@"%@=%@",
                 UFilePercentEscapedStringFromString(key),
                 UFilePercentEscapedStringFromString(value)];
            }
        }
    }
    return [NSURL URLWithString:url relativeToURL:self.baseURL];
}

- (void) putFile:(NSString*)fileName
   authorization:(NSString*)authorization
          option:(NSDictionary*)option
            data:(NSData*)data
        progress:(UFileProgressCallback)uploadProgress
         success:(UFileUploadDoneCallback)success
         failure:(UFileOpFailCallback)failure
{
    NSArray* headers = [self headersForPutFile:authorization options:option length:[data length]];
    [self.fileMgr Put:[self fileUrl:fileName params:nil]
         headerParams:headers
                 body:data
             progress:uploadProgress
              success:^(NSURLSessionDataTask * task, id responseObject) {
                  NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                  NSError * error = [[self class] _checkHttpRespError:resp body:responseObject];
                  if (error) {
                      failure(error);
                      return;
                  }
                  NSMutableDictionary* ret = [NSMutableDictionary new];
                  if (resp.allHeaderFields[kUFileRespHeaderEtag]) {
                      ret[kUFileRespETag] = resp.allHeaderFields[kUFileRespHeaderEtag];
                  }
                  success(ret);
              }
              failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                  failure(error);
              }];
}

- (void) getFile:(NSString *)fileName
   authorization:(NSString *)authorization
          option:(NSDictionary *)option
        progress:(UFileProgressCallback)downloadProgress
         success:(UFileDownloadDoneCallback)success
         failure:(UFileOpFailCallback)failure
{
    NSArray* headers = [self headersForGetFile:authorization options:option];
    [self.fileMgr Get:[self fileUrl:fileName params:nil]
         headerParams:headers
              queries:nil
             progress:downloadProgress
              success:^(NSURLSessionDataTask * task, id responseObject) {
                  NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                  NSError * error = [[self class] _checkHttpRespError:resp body:responseObject];
                  if (error) {
                      failure(error);
                      return;
                  }
                  NSMutableDictionary* ret = [NSMutableDictionary new];
                  if (resp.allHeaderFields[kUFileRespHeaderEtag]) {
                      ret[kUFileRespHeaderEtag] = resp.allHeaderFields[kUFileRespHeaderEtag];
                  }
                  success(ret, responseObject);
              }
              failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                  failure(error);
              }];
    
}

-(void) uploadHit:(NSString *)fileName
    authorization:(NSString *)authorization
         fileSize:(NSInteger)fileSize
         fileHash:(NSString *)fileHash
          success:(UFileUploadDoneCallback)success
          failure:(UFileOpFailCallback)failure
{
    [self.fileMgr Post:[self fileUrl:@"uploadhit" params:@{@"Hash":fileHash, @"FileName":fileName, @"FileSize":[@(fileSize) stringValue]}]
          headerParams: @[@[@"Authorization", authorization]]
                  body:nil
              progress: nil
               success:^(NSURLSessionDataTask * task, id responseObject) {
                   NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                   NSError * error = [[self class] _checkHttpRespError:resp body:responseObject];
                   if (error) {
                       failure(error);
                       return;
                   }
                   NSMutableDictionary* ret = [NSMutableDictionary new];
                   success(ret);
               }
               failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                   failure(error);
               }];
}

- (void) headFile:(NSString *)fileName
    authorization:(NSString *)authorization
          success:(UFileUploadDoneCallback)success
          failure:(UFileOpFailCallback)failure
{
    [self.fileMgr Head:[self fileUrl:fileName params:nil]
          headerParams:@[@[@"Authorization", authorization]]
               success:^(NSURLSessionDataTask * task, id responseObject) {
                   NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                   NSError * error = [[self class] _checkHttpRespError:resp body:responseObject];
                   if (error) {
                       failure(error);
                       return;
                   }
                   NSDictionary * ret = @{
                                          kUFileRespFileType: resp.allHeaderFields[@"Content-Type"],
                                          kUFileRespLength:
                                              resp.allHeaderFields[@"Content-Length"],
                                          kUFileRespETag:
                                              resp.allHeaderFields[@"ETag"]
                                          };
                   success(ret);
               }
               failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                   failure(error);
               }];
}

- (void) deleteFile:(NSString *)fileName
      authorization:(NSString *)authorization
            success:(UFileOpDoneCallback)success
            failure:(UFileOpFailCallback)failure
{
    [self.fileMgr Delete:[self fileUrl:fileName params:nil]
            headerParams:@[@[@"Authorization", authorization]]
                 success:^(NSURLSessionDataTask * task, id responseObject) {
                     NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                     NSError * error = [[self class] _checkHttpRespError:resp body:responseObject];
                     if (error) {
                         failure(error);
                         return;
                     }
                     NSMutableDictionary* ret = [NSMutableDictionary new];
                     success(ret);
                 }
                 failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                     failure(error);
                 }];
}

- (void) multipartUploadSetRetryOpt:(NSUInteger)retryTimeLimit
                  retryTimeInterval:(NSUInteger)retryInterval
{
    self.multipartRetryInterval = retryInterval;
    self.multipartRetryTimeLimit = retryTimeLimit;
}


- (void) multipartUploadStart:(NSString* _Nonnull)fileName
                authorization:(NSString* _Nonnull)authorization
                      success:(UFileOpDoneCallback _Nonnull)success
                      failure:(UFileOpFailCallback _Nonnull)failure
{
    [self.fileMgr Post:[self fileUrl:fileName params:@{@"uploads": @""}]
          headerParams: @[@[@"Authorization", authorization]]
                  body:nil
              progress: nil
               success:^(NSURLSessionDataTask * task, id responseObject) {
                   NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                   NSError * error = [[self class] _checkHttpRespError:resp body:responseObject];
                   if (error) {
                       failure(error);
                       return;
                   }
                   NSError * jsonErr = nil;
                   id respObj = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:&jsonErr];
                   if (jsonErr) {
                       failure([NSError errorWithDomain:kUFileSDKAPIErrorDomain
                                                   code:-1
                                               userInfo:@{@"ErrMsg": @"Invalid response"}]);
                       return;
                   }
                   success(@{
                             kUFileRespUploadId: respObj[kUFileRespUploadId],
                             kUFileRespBlockSize: respObj[kUFileRespBlockSize],
                             kUFileRespBucketName: respObj[kUFileRespBucketName],
                             kUFileRespKeyName: respObj[kUFileRespKeyName]
                             });
               }
               failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                   failure(error);
               }];
    
}

- (void) _doMultipartUploadPart:(NSString* _Nonnull)fileName
                       uploadId:(NSString* _Nonnull)uploadId
                     partNumber:(NSInteger)partNumber
                    contentType:(NSString* _Nonnull)contentType
                           data:(NSData* _Nonnull)data
                  authorization:(NSString* _Nonnull)authorization
                       progress:(UFileProgressCallback _Nullable)uploadProgress
                        success:(UFileUploadDoneCallback _Nonnull)success
                        failure:(UFileOpFailCallback)failure
                 leftRetryTimes:(NSUInteger)leftRetryTimes
{
    NSArray * headers = @[
                          @[@"Authorization", authorization],
                          @[@"Content-Length", [NSString stringWithFormat:@"%lu", (unsigned long)[data length]]],
                          @[@"Content-Type", contentType]
                          ];
    
    [self.fileMgr Put:[self fileUrl:fileName params:@{@"uploadId":uploadId, @"partNumber":[@(partNumber) stringValue]}]
         headerParams:headers
                 body:data
             progress:uploadProgress
              success:^(NSURLSessionDataTask * task, id responseObject) {
                  NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                  NSError * error = [[self class] _checkHttpRespError:resp body:responseObject];
                  if (error) {
                      if (leftRetryTimes > 0) {
                          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.multipartRetryInterval*1000),
                                         dispatch_get_main_queue(), ^{
                                             [self _doMultipartUploadPart:fileName
                                                                 uploadId:uploadId
                                                               partNumber:partNumber
                                                              contentType:contentType
                                                                     data:data
                                                            authorization:authorization
                                                                 progress:uploadProgress
                                                                  success:success
                                                                  failure:failure
                                                           leftRetryTimes:leftRetryTimes-1];
                                         });
                      } else {
                          failure(error);
                      }
                      return;
                  }
                  NSMutableDictionary* ret = [NSMutableDictionary new];
                  if (resp.allHeaderFields[kUFileRespHeaderEtag]) {
                      ret[kUFileRespETag] = resp.allHeaderFields[kUFileRespHeaderEtag];
                  }
                  success(ret);
              }
              failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                  if (leftRetryTimes > 0) {
                      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.multipartRetryInterval*1000),
                                     dispatch_get_main_queue(), ^{
                                         [self _doMultipartUploadPart:fileName
                                                             uploadId:uploadId
                                                           partNumber:partNumber
                                                          contentType:contentType
                                                                 data:data
                                                        authorization:authorization
                                                             progress:uploadProgress
                                                              success:success
                                                              failure:failure
                                                       leftRetryTimes:leftRetryTimes-1];
                                     });
                  } else {
                      failure(error);
                  }
              }];
    
}



- (void) multipartUploadPart:(NSString* _Nonnull)fileName
                    uploadId:(NSString* _Nonnull)uploadId
                  partNumber:(NSInteger)partNumber
                 contentType:(NSString* _Nonnull)contentType
                        data:(NSData* _Nonnull)data
               authorization:(NSString* _Nonnull)authorization
                    progress:(UFileProgressCallback _Nullable)uploadProgress
                     success:(UFileUploadDoneCallback _Nonnull)success
                     failure:(UFileOpFailCallback _Nonnull)failure
{
    
    
    [self _doMultipartUploadPart:fileName
                        uploadId:uploadId
                      partNumber:partNumber
                     contentType:contentType
                            data:data
                   authorization:authorization
                        progress:uploadProgress
                         success:success
                         failure:failure
                  leftRetryTimes:self.multipartRetryTimeLimit
     ];
    
}

-(void) _doMultipartUploadFinish:(NSString *)fileName
                        uploadId:(NSString *)uploadId
                          newKey:(NSString *)newKey
                           etags:(NSArray *)etags
                     contentType:(NSString* _Nonnull)contentType
                   authorization:(NSString* _Nonnull)authorization
                         success:(UFileUploadDoneCallback)success
                         failure:(UFileOpFailCallback)failure
                  leftRetryTimes:(NSUInteger)leftRetryTimes
{
    NSData * body = [[etags componentsJoinedByString:@","] dataUsingEncoding:NSUTF8StringEncoding];
    UFileOpFailCallback theFailCb = ^(NSError* error) {
        if (leftRetryTimes > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.multipartRetryInterval*1000),
                           dispatch_get_main_queue(), ^{
                               [self _doMultipartUploadFinish:fileName
                                                     uploadId:uploadId
                                                       newKey:newKey
                                                        etags:etags
                                                  contentType:contentType
                                                authorization:authorization
                                                      success:success
                                                      failure:failure
                                               leftRetryTimes:leftRetryTimes-1];
                           });
            
        } else {
            failure(error);
        }
    };
    
    [self.fileMgr Post:[self fileUrl:fileName params:@{@"uploadId":uploadId, @"newKey":newKey}]
          headerParams: @[@[@"Authorization", authorization],
                          @[@"Content-type", contentType],
                          @[@"Content-Length", [NSString stringWithFormat:@"%lu", (unsigned long)body.length]]]
                  body:body
              progress: nil
               success:^(NSURLSessionDataTask * task, id responseObject) {
                   NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                   NSError * error = [[self class] _checkHttpRespError:resp body:responseObject];
                   if (error) {
                       theFailCb(error);
                       return;
                   }
                   NSError* jsonErr;
                   id respObj = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:&jsonErr];
                   if (jsonErr) {
                       NSLog(@"json error: %@", jsonErr);
                       theFailCb([NSError errorWithDomain:kUFileSDKAPIErrorDomain
                                                     code:-1
                                                 userInfo:@{@"ErrMsg": @"Invalid response "}]);
                       return;
                   }
                   success(@{
                             kUFileRespLength: respObj[@"FileSize"],
                             kUFileRespBucketName: respObj[kUFileRespBucketName],
                             kUFileRespKeyName: respObj[kUFileRespKeyName]
                             });
               }
               failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                   theFailCb(error);
               }];
    
}

- (void) multipartUploadFinish:(NSString* _Nonnull)key
                      uploadId:(NSString* _Nonnull)uploadId
                        newKey:(NSString* _Nonnull)newKey
                         etags:(NSArray* _Nonnull)etags
                   contentType:(NSString* _Nonnull)contentType
                 authorization:(NSString* _Nonnull)authorization
                       success:(UFileUploadDoneCallback _Nonnull)success
                       failure:(UFileOpFailCallback _Nonnull)failure
{
    [self _doMultipartUploadFinish:key
                          uploadId:uploadId
                            newKey:newKey
                             etags:etags
                       contentType:contentType
                     authorization:authorization
                           success:success
                           failure:failure
                    leftRetryTimes:self.multipartRetryInterval];
}

-(void)multipartUploadAbort:(NSString *)fileName
                   uploadId:(NSString *)uploadId
              authorization:(NSString* _Nonnull)authorization
                    success:(UFileUploadDoneCallback)success
                    failure:(UFileOpFailCallback)failure
{
    [self.fileMgr Delete:[self fileUrl:fileName params:@{@"uploadId":uploadId}]
            headerParams:@[@[@"Authorization", authorization]]
                 success:^(NSURLSessionDataTask * task, id responseObject) {
                     NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                     NSError * error = [[self class] _checkHttpRespError:resp body:responseObject];
                     if (error) {
                         failure(error);
                         return;
                     }
                     NSMutableDictionary* ret = [NSMutableDictionary new];
                     success(ret);
                 }
                 failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                     failure(error);
                 }];
    
}


- (NSString*) _caclMd5:(NSData*)data
{
    const void * pointer = data.bytes;
    
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(pointer, (CC_LONG)strlen(pointer), md5Buffer);
    
    NSMutableString *string = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [string appendFormat:@"%02x",md5Buffer[i]];
    return string;
}


+ (NSError*) _checkHttpRespError:(NSHTTPURLResponse*)response body:(NSData*)body
{
    if (response.statusCode/100 != 2) {
        NSError * jsonErr = nil;
        id respObj = nil;
        if (body) {
            respObj = [NSJSONSerialization JSONObjectWithData:body options:0 error:&jsonErr];
        }
        NSInteger retCode = 0;
        NSDictionary * userInfo = nil;
        if (![respObj isKindOfClass:[NSDictionary class]] ||
            !respObj[kUFileRespRetCode] ||
            ![respObj[kUFileRespRetCode] isKindOfClass:[NSNumber class]]){
            retCode = -1;
            userInfo = @{
                         kUFileRespHttpStatusCode: [NSNumber numberWithLong:response.statusCode]
                         };
        } else {
            userInfo = @{
                         kUFileRespHttpStatusCode: [NSNumber numberWithLong:response.statusCode],
                         kUFileRespErrMsg: respObj[kUFileRespErrMsg],
                         kUFileRespXSession: response.allHeaderFields[@"X-SessionId"]
                         };
            retCode =  [respObj[kUFileRespRetCode] integerValue];
        }
        NSError* error =
        [NSError errorWithDomain:kUFileSDKAPIErrorDomain
                            code:retCode
                        userInfo:userInfo];
        return error;
    }
    return nil;
}

- (void) putFile:(NSString *)key
        fromFile:(NSString *)fileName
   authorization:(NSString *)authorization
          option:(NSDictionary *)option
        progress:(UFileProgressCallback)uploadProgress
         success:(UFileUploadDoneCallback)success
         failure:(UFileOpFailCallback)failure
{
    NSMutableURLRequest* rqst =
    [NSMutableURLRequest requestWithURL:[self fileUrl:key params:nil]];
    rqst.HTTPMethod = @"PUT";
    
    NSArray* headers =
    [self headersForPutFile:authorization options:option length:10];
    for (NSArray* item in headers) {
        [rqst addValue:item[1] forHTTPHeaderField:item[0]];
    }
    
    __block NSURLSessionUploadTask* task =
    [self.fileMgr uploadTaskWithRequest:rqst
                               fromFile:[NSURL fileURLWithPath:fileName]
                               progress:uploadProgress
                      completionHandler:^(NSURLResponse *response, id responseObject, NSError * _Nullable error) {
                          if (error) {
                              failure(error);
                              return;
                          }
                          NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                          NSError * respErr = [[self class] _checkHttpRespError:resp body:responseObject];
                          if (respErr) {
                              failure(respErr);
                              return;
                          }
                          NSMutableDictionary* ret = [NSMutableDictionary new];
                          if (resp.allHeaderFields[kUFileRespHeaderEtag]) {
                              ret[kUFileRespETag] = resp.allHeaderFields[kUFileRespHeaderEtag];
                          }
                          success(ret);
                      }];
    [task resume];
    
}

- (void) getFile:(NSString *)key
          toFile:(NSString *)fileName
   authorization:(NSString *)authorization
          option:(NSDictionary *)option
        progress:(UFileProgressCallback)uploadProgress
         success:(UFileDownloadDoneCallback)success
         failure:(UFileOpFailCallback)failure
{
    NSMutableURLRequest* rqst =
    [NSMutableURLRequest requestWithURL:[self fileUrl:key params:nil]];
    rqst.HTTPMethod = @"GET";
    NSArray* headers = [self headersForGetFile:authorization options:option];
    for (NSArray* item in headers) {
        [rqst addValue:item[1] forHTTPHeaderField:item[0]];
    }
    __block NSURLSessionDownloadTask* task =
    [self.fileMgr downloadTaskWithRequest:rqst
                                 progress:uploadProgress
                              destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
                                  return [NSURL fileURLWithPath:fileName];
                              }
                        completionHandler:^(NSURLResponse *response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                            if (error) {
                                failure(error);
                                return;
                            }
                            NSHTTPURLResponse* resp = (NSHTTPURLResponse*)task.response;
                            NSError * respErr = [[self class] _checkHttpRespError:resp body:nil];
                            if (respErr) {
                                failure(respErr);
                                return;
                            }
                            NSMutableDictionary* ret = [NSMutableDictionary new];
                            if (resp.allHeaderFields[kUFileRespHeaderEtag]) {
                                ret[kUFileRespHeaderEtag] = resp.allHeaderFields[kUFileRespHeaderEtag];
                            }
                            success(ret, filePath);
                            
                        }];
    [task resume];
}

- (NSArray*) headersForGetFile:(NSString*)authorization
                       options:(NSDictionary*)options
{
    NSMutableArray * headers = [NSMutableArray new];
    [headers addObject:@[@"Authorization", authorization]];
    if (options) {
        if (options[kUFileSDKOptionRange]) {
            [headers addObject:@[@"Range", [@"bytes=" stringByAppendingString:options[kUFileSDKOptionRange]]]];
        }
        if (options[kUFileSDKOptionModifiedSince]) {
            [headers addObject:@[@"If-Modified-Since", options[kUFileSDKOptionModifiedSince]]];
        }
    }
    return headers;
}

- (NSArray*) headersForPutFile:(NSString*)authorization
                       options:(NSDictionary*)options
                        length:(NSUInteger)length
{
    NSMutableArray * headers = [NSMutableArray new];
    [headers addObjectsFromArray:@[
                                   @[@"Authorization", authorization],
                                   @[@"Content-Length", [NSString stringWithFormat:@"%lu", (unsigned long)length]]
                                   ]];
    if (options) {
        if (options[kUFileSDKOptionFileType]) {
            [headers addObject:@[@"Content-Type", options[kUFileSDKOptionFileType]]];
        }
        if (options[kUFileSDKOptionMD5]) {
            [headers addObject:@[@"Content-MD5", options[kUFileSDKOptionMD5]]];
        }
    }
    return headers;
}

@end

