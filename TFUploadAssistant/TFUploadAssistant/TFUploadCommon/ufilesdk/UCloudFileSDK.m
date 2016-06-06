//
//  UCloudFileSDK.m
//  TFUploadAssistant
//
//  Created by 鲍振华 on 16/6/6.
//  Copyright © 2016年 TimeFace. All rights reserved.
//

#import "UCloudFileSDK.h"
#import <CommonCrypto/CommonHMAC.h>

@implementation UCloudFileSDK

- (nonnull instancetype)initFromKeys:(NSString * _Nonnull)publicKey
                          privateKey:(NSString * _Nonnull)privateKey
                              bucket:(NSString * _Nonnull)bucket
{
    if (self = [super init]) {
        _publicKey = publicKey;
        _privateKey = privateKey;
        _bucket = bucket;
    }
    return self;
}

- (NSString * _Nonnull)calcKey:(NSString * _Nonnull)httpMethod
                           key:(NSString * _Nonnull)key
                    contentMd5:(NSString * _Nullable)contentMd5
                   contentType:(NSString * _Nullable)contentType
{
    NSMutableString* s = [[NSMutableString alloc] initWithString:httpMethod];
    
    [s appendString:@"\n"];
    
    [s appendString:contentMd5];
    
    [s appendString:@"\n"];
    
    [s appendString:contentType];
    
    [s appendString:@"\n"];
    
    [s appendString:@"\n"];
    
    [s appendString:@""];
    
    [s appendString:[NSString stringWithFormat:@"/%@/%@", self.bucket, key]];
    
    return [self _sha1Sum:self.privateKey s:s];
}

-(NSString*)stringFromResult:(nullable const void *)result length:(NSInteger)length
{
    NSData *hash = [NSData dataWithBytes:result length:length];
    
    return [hash base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}

-(NSString*)_sha1Sum:(NSString*)key s:(NSString*)s
{
    const char *str = [s cStringUsingEncoding:NSUTF8StringEncoding];
    int strLen = (int)[s lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    const char * keyStr = [key cStringUsingEncoding:NSUTF8StringEncoding];
    int keyLen = (int)[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    uint8_t hmac[CC_SHA1_DIGEST_LENGTH] = {0};
    
    CCHmac(kCCHmacAlgSHA1,
           keyStr,
           keyLen,
           str,
           strLen,
           hmac);
    
    NSString* digest = [self stringFromResult:hmac length:(int)CC_SHA1_DIGEST_LENGTH];
    
    return [NSString stringWithFormat:@"UCloud %@:%@", self.publicKey, digest];
}

@end
