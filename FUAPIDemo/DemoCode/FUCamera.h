//
//  FUCamera.h
//  FUAPIDemo
//
//  Created by liuyang on 2016/12/26.
//  Copyright © 2016年 liuyang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol FUCameraDelegate <NSObject>

- (void)didOutputVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@interface FUCamera : NSObject
@property (nonatomic, assign) id<FUCameraDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isFrontCamera;
@property (copy  , nonatomic) dispatch_queue_t  captureQueue;//录制的队列
@property (assign, nonatomic) AVCaptureDevicePosition cameraPosition;

- (void)startUp;

- (void)startCapture;

- (void)stopCapture;

- (void)changeCameraInputDeviceisFront:(BOOL)isFront;
@end
