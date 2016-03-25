//
//  TFZoomingScrollView.h
//  TFPhotoBrowser
//
//  Created by Melvin on 9/1/15.
//  Copyright © 2015 TimeFace. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TFPhotoProtocol.h"

@class TFPhotoBrowser,TFPhoto,TFPhotoCaptionView;
@interface TFZoomingScrollView : UIScrollView

@property () NSUInteger index;
@property (nonatomic) id <TFPhoto> photo;
@property (nonatomic, weak) TFPhotoCaptionView *captionView;
@property (nonatomic, weak) UIButton *selectedButton;
@property (nonatomic, weak) UIButton *playButton;

- (id)initWithPhotoBrowser:(TFPhotoBrowser *)browser;
- (void)displayImage;
- (void)displayImageFailure;
- (void)setMaxMinZoomScalesForCurrentBounds;
- (void)prepareForReuse;
- (BOOL)displayingVideo;
- (void)setImageHidden:(BOOL)hidden;

@end
