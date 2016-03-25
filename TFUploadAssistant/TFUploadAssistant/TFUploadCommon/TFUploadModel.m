//
//  TFUploadModel.m
//  TFUploadAssistant
//
//  Created by Melvin on 3/24/16.
//  Copyright © 2016 TimeFace. All rights reserved.
//

#import "TFUploadModel.h"

@implementation TFUploadModel


+ (nonnull instancetype)fileModelWithObjectKey:(NSString *)key
                                   token:(NSString *)token
                              identifier:(NSString *)identifier {
    TFUploadModel *model = [TFUploadModel new];
    model.objectKey = key;
    model.token = token;
    model.identifier = identifier;
    return model;
}

@end
