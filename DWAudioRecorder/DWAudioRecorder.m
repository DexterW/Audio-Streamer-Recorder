//
//  DWVoiceRecorder.m
//  DWpictionAudioRecorder
//
//  Created by Dexter Weiss on 7/12/11.
//  Copyright 2011 Dexter Weiss. All rights reserved.
//

#import "DWAudioRecorder.h"

@implementation DWAudioRecorder

- (id)init {
    self = [super init];
    if (self) {
        _voiceReader = [[DWAudioReader alloc] init];
        [_voiceReader setDelegate:self];
        _voiceStreamer = [[DWAudioStreamer alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self setDelegate:nil];
    [self setLocalDestinationURL:nil];
    [self setRemoteDestinationURL:nil];
    [self setHeaderData:nil];
}

-(void)setAudioCodec:(DWAudioReaderCodec)audioCodec {
    if ([self isRecording]) {
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:NSLocalizedString(@"You cannot change the codec while recording", nil) userInfo:nil] raise];
    }
    [self willChangeValueForKey:@"audioCodec"];
    _audioCodec = audioCodec;
    [self didChangeValueForKey:@"audioCodec"];
    [_voiceReader setCodec:audioCodec];
}

-(void)setLocalDestinationURL:(NSURL *)url {
    if ([self isRecording]) {
        [[NSException exceptionWithName:NSGenericException reason:@"Cannot change the local destination URL while recording audio" userInfo:nil] raise];
    }
    [self willChangeValueForKey:@"localDestinationURL"];
    _localDestinationURL = url;
    [self didChangeValueForKey:@"localDestinationURL"];
}

-(void)setRemoteDestinationURL:(NSURL *)url {
    if ([self isRecording]) {
        [[NSException exceptionWithName:NSGenericException reason:@"Cannot change the remote destination URL while recording audio" userInfo:nil] raise];
    }
    [self willChangeValueForKey:@"remoteDestinationURL"];
    [_voiceStreamer setUrl:url];
    _remoteDestinationURL = url;
    [self didChangeValueForKey:@"remoteDestinationURL"];
}

-(void)setRemoteDestinationPort:(NSUInteger)port {
    if ([self isRecording]) {
        [[NSException exceptionWithName:NSGenericException reason:@"Cannot change the remote destination port while recording audio" userInfo:nil] raise];
    }
    [self willChangeValueForKey:@"remoteDestinationPort"];
    _remoteDestinationPort = port;
    [_voiceStreamer setPortNumber:(SInt32)port];
    [self didChangeValueForKey:@"remoteDestinationPort"];
}

-(void)prepareForRecording {
    if ([self isRecording]) {
        [[NSException exceptionWithName:NSGenericException reason:@"Cannot prepare for recording while the audio recorder is already recording" userInfo:nil] raise];
    }
    if ([self remoteDestinationURL]) {
        if ([self headerData]) {
            [_voiceStreamer setHeaderData:[self headerData]];
        }
        [_voiceStreamer prepareForSending];
    }
    if ([self localDestinationURL]) {
        [_voiceReader setFileURL:[self localDestinationURL]];
    }
    _isPreparedForRecording = YES;
}

-(void)record {
    if ([self isRecording]) {
        return;
    }
    if (!_isPreparedForRecording) {
        [self prepareForRecording];
    }
    [_voiceReader record];
}

-(void)stop {
    if (![self isRecording]) {
        return;
    }
    [_voiceReader stop];
    [_voiceStreamer closeConnection];
}

-(AudioQueueLevelMeterState)audioLevel {
    return [_voiceReader audioLevel];
}

-(BOOL)isRecording {
    return [_voiceReader isRecording];
}

#pragma mark -
#pragma mark Reader Delegate

-(void)audioReaderDidCatpureAudioBuffer:(AudioQueueBufferRef)audioBuffer {
    if ([self remoteDestinationURL]) {
        [_voiceStreamer sendAudioDataFromBuffer:audioBuffer];
    }
}

-(void)audioReader:(DWAudioReader *)reader didFailWithError:(NSError *)error {
    [[self delegate] audioRecorder:self didEncounterError:error];
}


#pragma mark -
#pragma mark Sender Delegate

-(void)audioStreamer:(DWAudioStreamer *)sender didFailWithError:(NSError *)error {
    [[self delegate] audioRecorder:self didEncounterError:error];
}

@end
