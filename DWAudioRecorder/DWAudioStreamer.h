//
//  DWVoiceStreamSender.h
//  DWpictionAudioRecorder
//
//  Created by Dexter Weiss on 7/12/11.
//  Copyright 2011 Dexter Weiss, LLC. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

/*
 In most cases, you should never have to instantiate an instance of this class.
 
 DWAudioReader is a class used by DWAudioRecorder to actually read the audio from the microphone.
 Use DWAudioRecorder!
 */

@class DWAudioStreamer;

typedef enum {
    DWAudioStreamerErrorFailedToReachHost = 0,
    DWAudioStreamerErrorFailedToOpenConnectionWithHost = 1,
    DWAudioStreamerErrorStreamIsBlockedFromAcceptingBytes = 2,
    DWAudioStreamerErrorFailedToSendHeaderData = 3,
    DWAudioStreamerErrorFailedToSendBytes = 4,
    DWAudioStreamerErrorFailedToScheduleWithRunLoop = 5,
    DWAudioStreamerErrorFailedToRegisterCallbackClient = 6,
} DWAudioStreamerError;

@protocol DWAudioStreamerDelegate <NSObject>

@optional
-(void)audioStreamerDidOpenConnection:(DWAudioStreamer *)sender;
-(void)audioStreamerDidCloseConnection:(DWAudioStreamer *)sender;
-(void)audioStreamer:(DWAudioStreamer *)sender didFailWithError:(NSError *)error;
-(void)audioStreamerDidSendHeaderData:(DWAudioStreamer *)sender;
-(void)audioStreamer:(DWAudioStreamer *)sender didWriteDataToStream:(NSData *)data;

@end

@interface DWAudioStreamer : NSObject {
    @private
    CFWriteStreamRef _outputStream;
    CFHostRef _host;
}

@property (nonatomic, retain) NSURL *url;
@property (nonatomic) SInt32 portNumber;
@property (nonatomic, retain) NSData *headerData;
@property (assign) id <DWAudioStreamerDelegate> delegate;

-(void)prepareForSending;
-(void)sendAudioDataFromBuffer:(AudioQueueBufferRef)bufferRef;
-(void)closeConnection;

@end
