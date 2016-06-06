//
//  TFUploadHandler.m
//  TFUploadAssistant
//
//  Created by Melvin on 3/23/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import "TFUploadHandler.h"

@implementation TFUploadHandler

+ (TFUploadHandler*) uploadHandlerWithToken:(NSString *)token
                                 progressBlock:(TFUpProgressHandler)progressHandler
                               completionBlock:(TFUpCompletionHandler)completionHandler
                                           tag:(NSInteger)tag {
    TFUploadHandler *handler = [TFUploadHandler new];
    handler.token = token;
    handler.progressHandler = progressHandler;
    handler.completionHandler = completionHandler;
    return handler;
}

+ (TFUploadHandler*) uploadHandlerWithToken:(NSString *)token
                                      delegate:(id<TFUploadAssistantDelegate>)delegate {
    TFUploadHandler *handler = [TFUploadHandler new];
    handler.token = token;
    handler.delegate = delegate;
    return handler;
}

@end
