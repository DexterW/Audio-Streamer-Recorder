//
//  DWAudioRecorder.h
//  DWpictionAudioRecorder
//
//  Created by Dexter Weiss on 7/11/11.
//  Copyright 2011 DWpiction, LLC. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

/*
 In most cases, you should never have to instantiate an instance of this class.
 
 DWAudioReader is a class used by DWAudioRecorder to actually read the audio from the microphone.
 Use DWAudioRecorder!
 */

@class DWAudioReader;

typedef enum {
    DWAudioReaderErrorFailedToEnableLevelMetering = 0,
    DWAudioReaderErrorFailedToAllocateAudioBuffer = 1,
    DWAudioReaderErrorFailedToEnqueueAudioBuffer = 2,
    DWAudioReaderErrorFailedToCreateAudioFile = 3,
    DWAudioReaderErrorFailedToOpenAudioReaderQueue = 4,
    DWAudioReaderErrorFailedToGetAudioLevel = 5,
} DWAudioReaderError;


@protocol DWAudioReaderDelegate <NSObject>

-(void)audioReaderDidCatpureAudioBuffer:(AudioQueueBufferRef)audioBuffer;

@optional
-(void)audioReader:(DWAudioReader *)reader didFailWithError:(NSError *)error;
-(void)audioReaderDidBeginReading:(DWAudioReader *)streamer;
-(void)audioReaderDidStopReading:(DWAudioReader *)streamer;

@end


#define kNumberOfBuffers 3

typedef struct {
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef mQueue;
    AudioQueueBufferRef mBuffers[kNumberOfBuffers];
    AudioFileID mAudioFile;
    UInt32 bufferByteSize;
    SInt64 mCurrentPacket;
    bool mIsRunning;
    bool mAudioFileIsSet;
    void *mDelegateRef;
} DWAudioRecorderState;

@interface DWAudioReader : NSObject {
    DWAudioRecorderState recorderState;
}

@property (nonatomic, getter = isRecording, readonly) BOOL recording;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, assign) id <DWAudioReaderDelegate> delegate;

-(void)record;
-(void)stop;
-(AudioQueueLevelMeterState)audioLevel;

@end