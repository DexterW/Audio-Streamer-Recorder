//
//  DWVoiceStreamSender.m
//  DWpictionAudioRecorder
//
//  Created by Dexter Weiss on 7/12/11.
//  Copyright 2011 Dexter Weiss, LLC. All rights reserved.
//

#import "DWAudioStreamer.h"

NSString * const kDWAudioStreamerErrorDomain = @"DWAudioStreamer";

NSString * const kFailedToReachHost = @"Audio streamer could not reach the specified host.";

NSString * const kFailedToOpenConnection = @"Audio streamer could not open a connection with the specified host.";

NSString * const kStreamIsBlockedFromAcceptingBytes = @"Audio streamer could not write bytes to the specified host because the connection is blocked.";

NSString * const kFailedToSendHeaderData = @"Audio streamer could not write header data to the specified host.";

NSString * const kFailedToSendBytes = @"Audio streamer could not write audio bytes to the specified host.";

NSString * const kFailedToScheduleWithRunLoop = @"Audio streamer could not register with a runloop.";

NSString * const kFailedToRegisterCallbackClient = @"Audio streamer could not register a callback client for the connection.";

static NSError * errorForAudioErrorCode(DWAudioStreamerError errorCode) {
    NSString *errorDescription;
    switch (errorCode) {
        case DWAudioStreamerErrorFailedToReachHost:
            errorDescription = kFailedToReachHost;
            break;
        case DWAudioStreamerErrorFailedToOpenConnectionWithHost:
            errorDescription = kFailedToOpenConnection;
            break;
        case DWAudioStreamerErrorStreamIsBlockedFromAcceptingBytes:
            errorDescription = kStreamIsBlockedFromAcceptingBytes;
            break;
        case DWAudioStreamerErrorFailedToSendHeaderData:
            errorDescription = kFailedToSendHeaderData;
            break;
        case DWAudioStreamerErrorFailedToSendBytes:
            errorDescription = kFailedToSendBytes;
            break;
        case DWAudioStreamerErrorFailedToScheduleWithRunLoop:
            errorDescription = kFailedToScheduleWithRunLoop;
            break;
        case DWAudioStreamerErrorFailedToRegisterCallbackClient:
            errorDescription = kFailedToRegisterCallbackClient;
            break;
    }
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorDescription forKey:NSLocalizedDescriptionKey];
    NSError *error = [NSError errorWithDomain:kDWAudioStreamerErrorDomain code:errorCode userInfo:userInfo];
    return error;
}

static void streamEventCallback(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
    DWAudioStreamer *sender = (DWAudioStreamer *)clientCallBackInfo;
    if (type == kCFStreamEventCanAcceptBytes) {
        if ([sender headerData]) {
            CFIndex bytesWritten = CFWriteStreamWrite(stream, [[sender headerData] bytes], [[sender headerData] length]);
            
            if (bytesWritten != [[sender headerData] length]) {
                if ([[sender delegate] respondsToSelector:@selector(audioStreamer:didFailWithError:)]) {
                    [[sender delegate] audioStreamer:sender didFailWithError:errorForAudioErrorCode(DWAudioStreamerErrorFailedToSendHeaderData)];
                }
            }
            else {
                if ([[sender delegate] respondsToSelector:@selector(audioStreamerDidSendHeaderData:)]) {
                    [[sender delegate] audioStreamerDidSendHeaderData:sender];
                }
            }
            
            [sender setHeaderData:nil];
        }
    }
    else if (type == kCFStreamEventOpenCompleted) {
        if ([[sender delegate] respondsToSelector:@selector(audioStreamerDidOpenConnection:)]) {
            [[sender delegate] audioStreamerDidOpenConnection:sender];
        }
    }
}

@implementation DWAudioStreamer
@synthesize url;
@synthesize portNumber;
@synthesize headerData;
@synthesize delegate;

-(void)dealloc {
    [self setHeaderData:nil];
    CFRelease(_outputStream);
    [super dealloc];
}


-(void)sendAudioDataFromBuffer:(AudioQueueBufferRef)bufferRef {
    if (CFWriteStreamCanAcceptBytes(_outputStream)) {
        CFIndex bytesWritten = CFWriteStreamWrite(_outputStream, bufferRef->mAudioData, bufferRef->mAudioDataByteSize);
        if (bytesWritten != bufferRef->mAudioDataByteSize && [delegate respondsToSelector:@selector(audioStreamer:didFailWithError:)]) {
            [[self delegate] audioStreamer:self didFailWithError:errorForAudioErrorCode(DWAudioStreamerErrorFailedToSendBytes)];
        }
        else if ([[self delegate] respondsToSelector:@selector(audioStreamer:didWriteDataToStream:)]) {
            [[self delegate] audioStreamer:self didWriteDataToStream:[NSData dataWithBytes:bufferRef->mAudioData length:bufferRef->mAudioDataByteSize]];
        }
    }
    else {
        if ([[self delegate] respondsToSelector:@selector(audioStreamer:didFailWithError:)]) {
            [[self delegate] audioStreamer:self didFailWithError:errorForAudioErrorCode(DWAudioStreamerErrorStreamIsBlockedFromAcceptingBytes)];
        }
    }
}

-(void)prepareForSending {
    CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorSystemDefault, (CFStringRef)[[self url] path]);
    CFStreamCreatePairWithSocketToCFHost(kCFAllocatorSystemDefault, hostRef, [self portNumber], NULL, &_outputStream);
    CFRelease(hostRef);
    CFStreamStatus status = CFWriteStreamGetStatus(_outputStream);
    if (status == kCFStreamStatusError) {
        if ([delegate respondsToSelector:@selector(audioStreamer:didFailWithError:)]) {
            [delegate audioStreamer:self didFailWithError:DWAudioStreamerErrorFailedToReachHost];
            return;
        }
    }
    CFWriteStreamScheduleWithRunLoop(_outputStream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    status = CFWriteStreamGetStatus(_outputStream);
    if (status == kCFStreamStatusError) {
        if ([delegate respondsToSelector:@selector(audioStreamer:didFailWithError:)]) {
            [delegate audioStreamer:self didFailWithError:errorForAudioErrorCode(DWAudioStreamerErrorFailedToScheduleWithRunLoop)];
            return;
        }
    }
    
    CFStreamClientContext context;
    context.version = 0;
    context.copyDescription = nil;
    context.info = self;
    context.retain = nil;
    context.release = nil;
    
    if (!CFWriteStreamSetClient(_outputStream, kCFStreamEventOpenCompleted | kCFStreamEventErrorOccurred | kCFStreamEventCanAcceptBytes, streamEventCallback, &context)) {
        if ([delegate respondsToSelector:@selector(audioStreamer:didFailWithError:)]) {
            [delegate audioStreamer:self didFailWithError:errorForAudioErrorCode(DWAudioStreamerErrorFailedToRegisterCallbackClient)];
            return;
        }
    }
    
    if (!CFWriteStreamOpen(_outputStream)) {
        if ([delegate respondsToSelector:@selector(audioStreamer:didFailWithError:)]) {
            [delegate audioStreamer:self didFailWithError:errorForAudioErrorCode(DWAudioStreamerErrorFailedToOpenConnectionWithHost)];
            return;
        }
    }
}

-(void)closeConnection {
    if (_outputStream) {
        CFWriteStreamClose(_outputStream);
        if ([[self delegate] respondsToSelector:@selector(audioStreamerDidCloseConnection:)]) {
            [[self delegate] audioStreamerDidCloseConnection:self];
        }
    }
}

@end