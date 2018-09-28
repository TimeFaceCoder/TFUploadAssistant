#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "TFUCloudFileSDK.h"
#import "UCloudFileSDK.h"
#import "UFileAPI.h"
#import "UFileAPIUtils.h"
#import "UFileHttpManager.h"
#import "version.h"

FOUNDATION_EXPORT double TFUCloudFileSDKVersionNumber;
FOUNDATION_EXPORT const unsigned char TFUCloudFileSDKVersionString[];

