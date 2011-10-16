//
//  DWVoiceRecorder.h
//  DWpictionAudioRecorder
//
//  Created by Dexter Weiss on 7/12/11.
//  Copyright 2011 Dexter Weiss. All rights reserved.
//

#import "DWAudioReader.h"
#import "DWAudioStreamer.h"
#import <Foundation/Foundation.h>

/*
 DWAudioRecorder is designed to allow simultaneous streaming and writing of audio from the microphone.
 
 It is also capable of doing one or the other.  To only write to a file, set the local destination url.
 To only stream to a remote host, set the remote destination url and remote destination port.  With all 
 of them set, the recorder can both save to a file and stream to a remote host.
 
 This piece requires the AudioToolbox and CFNetwork frameworks to function.
 
 Release Notes:
 
 v1.0:
 Only allows recording using the iLBC codec.  This is an 8kHz voice-optimized codec that has a footprint
 light enough for 3g conditions.
 
 To stream audio down from the remote host using an http live streaming enabled player, use AVPlayer from
 the AVFoundation framework.  NOTE: AVAudioPlayer will not work with remote hosts.  It *must* be AVPlayer.
 */

@class DWAudioRecorder;

@protocol DWAudioRecorderDelegate <NSObject>

-(void)audioRecorder:(DWAudioRecorder *)recorder didEncounterError:(NSError *)error;

@end

@interface DWAudioRecorder : NSObject <DWAudioReaderDelegate, DWAudioStreamerDelegate> {
@private
    DWAudioReader *_voiceReader;
    DWAudioStreamer *_voiceStreamer;
    BOOL _isPreparedForRecording;
}

/*
 The audio recorder delegate captures all errors originating from this tool.
 It is highly recommended that the delegate is set.
 */
@property (assign) id<DWAudioRecorderDelegate>delegate;

/*
 The local destination url should be set if you want the recorder to keep all recorded audio on disk.
 */
@property (nonatomic, retain) NSURL *localDestinationURL;

/*
 The remote destination url should be set if you want to stream the audio via a socket to a remote destination.
 */
@property (nonatomic, retain) NSURL *remoteDestinationURL;

/*
 The remote destination port should be specified along with the remote destination url.

 In the future, this property will be merged with remoteDestinationURL, as NSURL has ports built in.
 
 This is a leaky abstraction - CFStreamCreatePairWithSocketToCFHost() requires a port number as an argument
 so it is semantically separated here.
 */
@property (nonatomic) NSUInteger remoteDestinationPort;

/*
 The header data is an optional chunk of data that can be sent to the remote destination before audio data is streamed.
 This is often used to tell the destination what type of data it is getting, or how to associate the streamed data with other data in an application.
 */
@property (nonatomic, retain) NSData *headerData;


/*
 -prepareForRecording MUST be called before audio recording can begin.
 When this method is called, local destination, remote destination, and the port are LOCKED.
 
 If you don't call this method explicitly, it is called when -record is called.
 For optimum performance, call this method as soon as possible.
 */
-(void)prepareForRecording;

/*
 -record begins the actual flow of audio data from the microphone to the recorder.
 */
-(IBAction)record;

/*
 -stop halts all data coming from the microphone.
 It also closes the connection with the remote destination.
 */
-(IBAction)stop;

-(AudioQueueLevelMeterState)audioLevel;

-(BOOL)isRecording;

@end
