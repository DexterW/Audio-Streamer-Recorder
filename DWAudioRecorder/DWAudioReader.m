//
//  DWAudioRecorder.m
//  DWpictionAudioRecorder
//
//  Created by Dexter Weiss on 7/11/11.
//  Copyright 2011 Dexter Weiss, LLC. All rights reserved.
//

#import "DWAudioReader.h"

NSString * const kDWAudioReaderErrorDomain = @"DWAudioReader";

NSString * const kFailedToEnableLevelMeteringDescription = @"Audio reader failed to enable audio meter levels.";

NSString * const kFailedToAllocateAudioBufferDescription = @"Audio reader failed to allocate audio buffers.";

NSString * const kFailedToEnqueueAudioBufferDescription = @"Audio reader failed to enqueue audio buffers.";

NSString * const kFailedToCreateAudioFileDescription = @"Audio reader failed to create the audio file at the designated URL.";

NSString * const kFailedToOpenAudioReaderQueueDescription = @"Audio reader failed to open the audio cDWture queue.";

NSString * const kFailedToGetAudioLevelDescription = @"Audio reader failed to get audio levels.";

static NSError * errorForAudioErrorCode(DWAudioReaderError errorCode) {
    NSString *errorDescription;
    switch (errorCode) {
        case DWAudioReaderErrorFailedToEnableLevelMetering:
            errorDescription = kFailedToEnableLevelMeteringDescription;
            break;
        case DWAudioReaderErrorFailedToAllocateAudioBuffer:
            errorDescription = kFailedToAllocateAudioBufferDescription;
            break;
        case DWAudioReaderErrorFailedToEnqueueAudioBuffer:
            errorDescription = kFailedToEnqueueAudioBufferDescription;
            break;
        case DWAudioReaderErrorFailedToCreateAudioFile:
            errorDescription = kFailedToCreateAudioFileDescription;
            break;
        case DWAudioReaderErrorFailedToOpenAudioReaderQueue:
            errorDescription = kFailedToOpenAudioReaderQueueDescription;
            break;
        case DWAudioReaderErrorFailedToGetAudioLevel:
            errorDescription = kFailedToGetAudioLevelDescription;
            break;
    }
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorDescription forKey:NSLocalizedDescriptionKey];
    NSError *error = [NSError errorWithDomain:kDWAudioReaderErrorDomain code:errorCode userInfo:userInfo];
    return error;
}

// A detailed explaination of the following code can be found at:
// http://developer.DWple.com/library/mac/#documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html

static void DeriveBufferSize (AudioQueueRef audioQueue, AudioStreamBasicDescription *streamDescription, Float64 seconds, UInt32 *outBufferSize) {
    static const int maxBufferSize = 2000;
    int maxPacketSize = streamDescription->mBytesPerPacket;
    if (maxPacketSize == 0) {
        UInt32 maxVariableBitRatePacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty(audioQueue, kAudioConverterPropertyMaximumOutputPacketSize, &maxPacketSize, &maxVariableBitRatePacketSize);
    }
    Float64 numberOfBytesForTime = streamDescription->mSampleRate * maxPacketSize * seconds;
    *outBufferSize = (UInt32) numberOfBytesForTime < maxBufferSize ? numberOfBytesForTime : maxBufferSize;
}

static OSStatus setMagicCookieForFile (AudioQueueRef audioQueue, AudioFileID inFile) {
    OSStatus result = noErr;
    UInt32 cookieSize;
    if (AudioQueueGetPropertySize(audioQueue, kAudioQueueProperty_MagicCookie, &cookieSize) == noErr) {
        char *magicCookie = (char *)malloc(cookieSize);
        if (AudioQueueGetProperty(audioQueue, kAudioQueueProperty_MagicCookie, magicCookie, &cookieSize) == noErr) {
            result = AudioFileSetProperty(inFile, kAudioFilePropertyMagicCookieData, cookieSize, magicCookie);
        }
        free(magicCookie);
    }
    return result;
}

static void HandleInputBuffer (void *aqData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime, UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc) {
    DWAudioRecorderState *pAqData = (DWAudioRecorderState *) aqData;
    if (inNumPackets == 0 && pAqData->mDataFormat.mBytesPerPacket != 0) {
        inNumPackets = inBuffer->mAudioDataByteSize / pAqData->mDataFormat.mBytesPerPacket;
    }
    
    
    if (pAqData->mAudioFileIsSet && AudioFileWritePackets(pAqData->mAudioFile, false, inBuffer->mAudioDataByteSize, inPacketDesc, pAqData->mCurrentPacket, &inNumPackets, inBuffer->mAudioData) == noErr) {
        pAqData->mCurrentPacket += inNumPackets;
    }
    
    id <DWAudioReaderDelegate> delegate = pAqData->mDelegateRef;
    
    if (pAqData->mIsRunning) {
        [delegate audioReaderDidCatpureAudioBuffer:inBuffer];
        AudioQueueEnqueueBuffer(pAqData->mQueue, inBuffer, 0, NULL);
    }
}

@implementation DWAudioReader

@synthesize recording;
@synthesize fileURL;
@synthesize delegate;

- (id)init {
    self = [super init];
    if (self) {
        memset(&recorderState.mDataFormat, 0, sizeof(recorderState.mDataFormat));
        
        recorderState.mDataFormat.mFormatID = kAudioFormatiLBC;
        recorderState.mDataFormat.mSampleRate = 8000.0;
        recorderState.mDataFormat.mChannelsPerFrame = 1;
        recorderState.mDataFormat.mBitsPerChannel = 0;
        recorderState.mDataFormat.mBytesPerPacket = 38;
        recorderState.mDataFormat.mBytesPerFrame = 0;
        recorderState.mDataFormat.mFramesPerPacket = 160;
        recorderState.mDataFormat.mFormatFlags = 0;
        
        recorderState.mAudioFileIsSet = false;
        
        OSStatus status = AudioQueueNewInput(&recorderState.mDataFormat, HandleInputBuffer, &recorderState, NULL, kCFRunLoopCommonModes, 0, &recorderState.mQueue);
        
        SInt16 metering = 1;
        AudioQueueSetProperty(recorderState.mQueue, kAudioQueueProperty_EnableLevelMetering, &metering, sizeof(metering));
        
        if (status != noErr) {
            if ([[self delegate] respondsToSelector:@selector(audioReaderDidFailWithError:)]) {
                [[self delegate] audioReader:self didFailWithError:errorForAudioErrorCode(DWAudioReaderErrorFailedToEnableLevelMetering)];
            }
            return nil;
        }
        
        UInt32 dataFormatSize = sizeof(recorderState.mDataFormat);
        AudioQueueGetProperty(recorderState.mQueue, kAudioConverterCurrentOutputStreamDescription, &recorderState.mDataFormat, &dataFormatSize);
        
        DeriveBufferSize(recorderState.mQueue, &recorderState.mDataFormat, 0.5, &recorderState.bufferByteSize);
        
        for (int i = 0; i < kNumberOfBuffers; ++i) {
            status = AudioQueueAllocateBuffer(recorderState.mQueue, recorderState.bufferByteSize, &recorderState.mBuffers[i]);
            if (status != noErr) {
                if ([[self delegate] respondsToSelector:@selector(audioReaderDidFailWithError:)]) {
                    [[self delegate] audioReader:self didFailWithError:errorForAudioErrorCode(DWAudioReaderErrorFailedToAllocateAudioBuffer)];
                }
                return nil;
            }            
            status = AudioQueueEnqueueBuffer(recorderState.mQueue, recorderState.mBuffers[i], 0, NULL);
            if (status != noErr) {
                if ([[self delegate] respondsToSelector:@selector(audioReaderDidFailWithError:)]) {
                    [[self delegate] audioReader:self didFailWithError:errorForAudioErrorCode(DWAudioReaderErrorFailedToEnqueueAudioBuffer)];
                }
                return nil;
            }
        }
    }
    
    return self;
}

-(void)setDelegate:(id<DWAudioReaderDelegate>)delegateRef {
    delegate = delegateRef;
    recorderState.mDelegateRef = delegate;
}

-(void)setFileURL:(NSURL *)url {
    AudioFileTypeID fileType = kAudioFileCAFType;
    OSStatus status = AudioFileCreateWithURL((CFURLRef)url, fileType, &recorderState.mDataFormat, kAudioFileFlags_EraseFile, &recorderState.mAudioFile);
    if (status != noErr) {
        if ([[self delegate] respondsToSelector:@selector(audioReaderDidFailWithError:)]) {
            [[self delegate] audioReader:self didFailWithError:errorForAudioErrorCode(DWAudioReaderErrorFailedToCreateAudioFile)];
        }
        return;
    }
    recorderState.mAudioFileIsSet = true;
}

-(void)record {
    recorderState.mCurrentPacket = 0;
    recorderState.mIsRunning = true;
    OSStatus status = AudioQueueStart(recorderState.mQueue, NULL);
    if (status != noErr) {
        if ([[self delegate] respondsToSelector:@selector(audioReaderDidFailWithError:)]) {
            [[self delegate] audioReader:self didFailWithError:errorForAudioErrorCode(DWAudioReaderErrorFailedToOpenAudioReaderQueue)];
        }
        return;
    }
    else {
        if ([[self delegate] respondsToSelector:@selector(voiceStreamerDidBeginReading:)]) {
            [[self delegate] audioReaderDidBeginReading:self];
        }
    }
}

-(BOOL)isRecording {
    return recorderState.mIsRunning;
}

-(AudioQueueLevelMeterState)audioLevel {
    AudioQueueLevelMeterState levels[1]; 
    UInt32 dataSize = sizeof(AudioQueueLevelMeterState);
    OSStatus status = AudioQueueGetProperty(recorderState.mQueue, kAudioQueueProperty_CurrentLevelMeter, levels, &dataSize);
    if (status != noErr) {
        if ([[self delegate] respondsToSelector:@selector(audioReaderDidFailWithError:)]) {
            [[self delegate] audioReader:self didFailWithError:errorForAudioErrorCode(DWAudioReaderErrorFailedToGetAudioLevel)];
        }
    }
    return levels[0];
}

-(void)stop {
    AudioQueueStop(recorderState.mQueue, true);
    recorderState.mIsRunning = false;
    if ([[self delegate] respondsToSelector:@selector(audioReaderDidStopReading:)]) {
        [[self delegate] audioReaderDidStopReading:self];
    }
}

@end
