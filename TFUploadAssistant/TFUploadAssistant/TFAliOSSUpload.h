//
//  TFAliOSSUpload.h
//  TFUploadAssistant
//
//  Created by Melvin on 3/23/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TFUploadAssistant.h"

@interface TFAliOSSUpload : NSObject

- (instancetype) initWithData:(NSData *)data
                      withKey:(NSString *)key
                    withToken:(NSString *)token
        withCompletionHandler:(TFUpCompletionHandler)block
                   withOption:(TFUploadOption *)option
            withConfiguration:(TFConfiguration *)config;

- (void)put;

@end
