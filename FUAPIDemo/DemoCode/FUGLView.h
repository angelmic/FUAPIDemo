//
//  FUGLView.h
//  FUAPIDemo
//
//  Created by liuyang on 16/10/20.
//  Copyright © 2016年 liuyang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface FUGLView : UIView


@property (nonatomic , assign) BOOL isFrontCamera;

- (void)setupGL;
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end
