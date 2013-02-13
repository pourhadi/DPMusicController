//
//  OCPlayer.m
//  TheQ
//
//  Created by Dan Pourhadi on 9/28/12.
//
//

#import "DPMusicPlayer.h"
#import "DPMusicItem.h"
#import "DPMusicItemSong.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#define kUnitSize sizeof(AudioUnitSampleType)
#define kBufferUnit 655360
#define kTotalBufferSize kBufferUnit * kUnitSize

#define MAIN_BUS 0
#define AUX_BUS 1

#define BUFFER_COUNT 2

static OSStatus ipodRenderCallback (
									
									void                        *inRefCon,      // A pointer to a struct containing the complete audio data
									//    to play, as well as state information such as the
									//    first sample to play on this invocation of the callback.
									AudioUnitRenderActionFlags  *ioActionFlags, // Unused here. When generating audio, use ioActionFlags to indicate silence
									//    between sounds; for silence, also memset the ioData buffers to 0.
									const AudioTimeStamp        *inTimeStamp,   // Unused here.
									UInt32                      inBusNumber,    // The mixer unit input bus that is requesting some new
									//        frames of audio data to play.
									UInt32                      inNumberFrames, // The number of frames of audio to provide to the buffer(s)
									//        pointed to by the ioData parameter.
									AudioBufferList             *ioData         // On output, the audio data to play. The callback's primary
									//        responsibility is to fill the buffer(s) in the
									//        AudioBufferList.
									);



@interface DPMusicPlayer()
{
	AudioStruct crossfadeSongStruct;
	AUNode mixerNode;
	AUNode iONode;
	AUNode eqNode;

	AUGraph processingGraph;

	NSOperationQueue *crossfadeOperationQueue;
	
	AudioStruct audioStructs[BUFFER_COUNT];
	UInt32 mainBus;
	UInt32 auxBus;
	
	AudioStreamBasicDescription     SInt16StereoStreamFormat;

	NSOperationQueue *iTunesOperationQueue;

	NSMethodSignature *incrementTrackPositionMethodSignature;
	NSInvocation *incrementTrackPositionInvocation;
	
	NSMutableArray *notes;
	
	BOOL _seeking;
	NSTimeInterval scrubStartTime;

	UInt32 framesSinceLastTimeUpdate;
	BOOL fadingIn;
	BOOL fadingOut;

	/*
	 AudioStruct currentSongStruct;
	 
	 
	 
	 
	 float currentVolume;
	 
	 BOOL fadingOut;
	 BOOL fadingIn;
	 
	 float fadeOutVol;
	 
	 
	 
	 //AudioObject *songObjects[2];
	 
	 AudioStruct audioStructs[2];
	 
	 
	 
	 
	 NSURL *url;
	 
	 NSMutableArray *notes;
	 BOOL playingBeforeInterruption;
	 
	 NSNumber *duration;
	 
	 BOOL isSpotifyTrack;
	 
	 */
	
	NSTimeInterval _duration;
	NSTimeInterval _trackPosition;
}
@property (nonatomic, strong) NSMutableData *bufferData;
@property                       AudioUnit                   mixerUnit;
@property						AudioUnit					ioUnit;
@property						AudioUnit					eqUnit;
@property (nonatomic, strong) AVAssetReader *iPodAssetReader;
@property (readwrite)           Float64                     graphSampleRate;
@property (nonatomic, strong) AVAssetReader *crossfadeAssetReader;
@property (nonatomic, strong) NSMutableArray *observingObjects;
@end

@implementation DPMusicPlayer


#pragma mark - player calls


-(void)setCurrentSong:(DPMusicItemSong*)song play:(BOOL)play
{
	if (self.song != song)
	{
		_song = song;
	}
		
	AudioStruct *audio = &audioStructs[mainBus];
	audio->playingiPod = NO;
	audio->bufferIsReady = NO;
	
	_duration = self.song.duration;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DurationChanged" object:nil];
	
	_trackPosition = 0;
	audio->currentSampleNum = 0;
	[self loadBufferAtStartTime:0 reset:YES];
	
	if (play)
	{
		audio->playingiPod = YES;
		[self startAUGraph];
	}
}

-(void)setVolume:(Float64)volume
{
	_volume = volume;
	[self setMixerOutputGain:volume];
}

/*
-(NSTimeInterval)trackPosition
{
	return audioStructs[mainBus].currentSampleNum / SInt16StereoStreamFormat.mSampleRate;
}
*/
- (void)registerObjectToReceiveTrackPositionKVO:(id)obj
{
	if (!self.observingObjects) {
		self.observingObjects = [NSMutableArray arrayWithCapacity:1];
	}
	
	[self addObserver:obj forKeyPath:@"trackPosition" options:0 context:nil];
	
	[self.observingObjects addObject:obj];
}

-(AVAsset*)asset
{
	return [AVURLAsset URLAssetWithURL:[self.song url] options:nil];
}
-(BOOL)play
{
	if (self.song)
	{
		audioStructs[mainBus].playingiPod = YES;
		
		[self startAUGraph];

		return YES;
	}
	else
		return NO;
}
-(void)pause
{
	[self stopAUGraph];
}

-(void)reset
{
	_song = nil;
	_trackPosition = 0;
	audioStructs[mainBus].currentSampleNum = 0;
	
}


-(id)init
{
	self = [super init];
	
	if (self)
	{
		self.graphSampleRate = 44100.0; // Hertz
		iTunesOperationQueue = [[NSOperationQueue alloc] init];
				
		mainBus = 0;
		auxBus = 1;
		
		_trackPosition = 0;
		
		[self setupAudioSession];
		[self setupSInt16StereoStreamFormat];
		
		[self configureAndInitializeAudioProcessingGraph];
		
		SEL incrementTrackPositionSelector = @selector(incrementTrackPosition);
		incrementTrackPositionMethodSignature = [DPMusicPlayer instanceMethodSignatureForSelector:incrementTrackPositionSelector];
		incrementTrackPositionInvocation = [NSInvocation invocationWithMethodSignature:incrementTrackPositionMethodSignature];
		[incrementTrackPositionInvocation setSelector:incrementTrackPositionSelector];
		[incrementTrackPositionInvocation setTarget:self];

		
	}
	
	return self;
}

- (void)incrementTrackPosition
{
	[self willChangeValueForKey:@"trackPosition"];
	_trackPosition = audioStructs[mainBus].currentSampleNum / SInt16StereoStreamFormat.mSampleRate;
	[self didChangeValueForKey:@"trackPosition"];
}

-(void)cleanUpBufferForBus:(UInt32)bus
{
	if (processingGraph == NULL)
		return;
	
	//TPCircularBufferCleanup(&audioStructs[mainBus].circularBuffer);
	
}

-(void)loadBufferForCrossfade:(NSURL*)assetURL
{
	
	audioStructs[auxBus].playingiPod = YES;
	if (nil != self.crossfadeAssetReader) {
        [crossfadeOperationQueue cancelAllOperations];
		
		[self cleanUpBufferForBus:1];
    }
	
	if (!crossfadeOperationQueue)
		crossfadeOperationQueue = [[NSOperationQueue alloc] init];
	
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                    [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                                    [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                    nil];
	
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    if (asset == nil) {
        DLog(@"asset is not defined!");
        return;
    }
	
    DLog(@"Total Asset Duration: %f", CMTimeGetSeconds(asset.duration));
	
    NSError *assetError = nil;
    self.crossfadeAssetReader = [AVAssetReader assetReaderWithAsset:asset error:&assetError];
    if (assetError) {
        DLog (@"error: %@", assetError);
        return;
    }
	
    AVAssetReaderOutput *readerOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:asset.tracks audioSettings:outputSettings];
	
    if (! [self.crossfadeAssetReader canAddOutput: readerOutput]) {
        DLog (@"can't add reader output... die!");
        return;
    }
	
    // add output reader to reader
    [self.crossfadeAssetReader addOutput: readerOutput];
	
    if (! [self.crossfadeAssetReader startReading]) {
        DLog(@"Unable to start reading!");
        return;
    }
	
    // Init circular buffer
	
    TPCircularBufferInit(&audioStructs[auxBus].circularBuffer, kTotalBufferSize);
	
    __block NSBlockOperation * feediPodBufferOperation = [NSBlockOperation blockOperationWithBlock:^{
		
        while (![feediPodBufferOperation isCancelled] && self.crossfadeAssetReader.status != AVAssetReaderStatusCompleted) {
            
			if (self.crossfadeAssetReader.status == AVAssetReaderStatusReading) {
				if (kTotalBufferSize - crossfadeSongStruct.circularBuffer.fillCount >= 32768) {
                    CMSampleBufferRef nextBuffer = [readerOutput copyNextSampleBuffer];
					
                    if (nextBuffer) {
						
                        AudioBufferList abl;
                        CMBlockBufferRef blockBuffer;
                        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer, NULL, &abl, sizeof(abl), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
                        UInt64 size = CMSampleBufferGetTotalSampleSize(nextBuffer);
						
                        int bytesCopied = TPCircularBufferProduceBytes(&audioStructs[auxBus].circularBuffer, abl.mBuffers[0].mData, size);
						
                        if (!audioStructs[auxBus].bufferIsReady && bytesCopied > 0) {
                            audioStructs[auxBus].bufferIsReady = YES;
                        }
						
                        CFRelease(nextBuffer);
                        CFRelease(blockBuffer);
                    }
                    else {
                        break;
                    }
                }
            }
        }
        DLog(@"iPod Buffer Reading Finished");
    }];
	
    [crossfadeOperationQueue addOperation:feediPodBufferOperation];
}

#import <objc/runtime.h>
static OSStatus ipodRenderCallback (
									
									void                        *inRefCon,      // A pointer to a struct containing the complete audio data
									//    to play, as well as state information such as the
									//    first sample to play on this invocation of the callback.
									AudioUnitRenderActionFlags  *ioActionFlags, // Unused here. When generating audio, use ioActionFlags to indicate silence
									//    between sounds; for silence, also memset the ioData buffers to 0.
									const AudioTimeStamp        *inTimeStamp,   // Unused here.
									UInt32                      inBusNumber,    // The mixer unit input bus that is requesting some new
									//        frames of audio data to play.
									UInt32                      inNumberFrames, // The number of frames of audio to provide to the buffer(s)
									//        pointed to by the ioData parameter.
									AudioBufferList             *ioData         // On output, the audio data to play. The callback's primary
									//        responsibility is to fill the buffer(s) in the
									//        AudioBufferList.
									)
{
	
	DPMusicPlayer *self = (__bridge DPMusicPlayer*)inRefCon;
	AudioStructPtr audioObject = &self->audioStructs[MAIN_BUS];
		
    AudioUnitSampleType *outSample          = (AudioUnitSampleType *)ioData->mBuffers[0].mData;
    memset(outSample, 0, inNumberFrames * kUnitSize);
	
    if (audioObject->playingiPod && audioObject->bufferIsReady) {
		
		int32_t availableBytes;
		
		AudioUnitSampleType *bufferTail     = TPCircularBufferTail(&audioObject->circularBuffer, &availableBytes);
		
        memcpy(outSample, bufferTail, MIN(availableBytes, inNumberFrames * kUnitSize) );
        TPCircularBufferConsume(&audioObject->circularBuffer, MIN(availableBytes, inNumberFrames * kUnitSize) );
        audioObject->currentSampleNum += MIN(availableBytes / (kUnitSize), inNumberFrames);
		
				if (inBusNumber == self->mainBus)
					self->framesSinceLastTimeUpdate += inNumberFrames;
		
				//8820 22050
			if (self->framesSinceLastTimeUpdate >= 22050 && inBusNumber == self->mainBus) {
		[self->incrementTrackPositionInvocation performSelectorOnMainThread:@selector(invoke)
																				 withObject:nil
																			  waitUntilDone:NO];
				self->framesSinceLastTimeUpdate = 0;
			}
		
        if (availableBytes <= inNumberFrames * kUnitSize) {
            // Buffer is running out or playback is finished
            audioObject->bufferIsReady = NO;
			audioObject->playingiPod = NO;
            audioObject->currentSampleNum = 0;
			
			
			if ([[self delegate] respondsToSelector:@selector(playbackDidFinish)]) {
				[[self delegate] performSelector:@selector(playbackDidFinish)];
			}
        }
    }
	
    return noErr;
}

- (void) setupSInt16StereoStreamFormat {
	
    // The AudioUnitSampleType data type is the recommended type for sample data in audio
    //    units. This obtains the byte size of the type for use in filling in the ASBD.
    size_t bytesPerSample = sizeof (AudioSampleType);
	
    // Fill the application audio format struct's fields to define a linear PCM,
    //        stereo, noninterleaved stream at the hardware sample rate.
    SInt16StereoStreamFormat.mFormatID          = kAudioFormatLinearPCM;
    SInt16StereoStreamFormat.mFormatFlags       = kAudioFormatFlagsCanonical;
    SInt16StereoStreamFormat.mBytesPerPacket    = 2 * bytesPerSample;   // *** kAudioFormatFlagsCanonical <- implicit interleaved data => (left sample + right sample) per Packet
    SInt16StereoStreamFormat.mFramesPerPacket   = 1;
    SInt16StereoStreamFormat.mBytesPerFrame     = SInt16StereoStreamFormat.mBytesPerPacket * SInt16StereoStreamFormat.mFramesPerPacket;
    SInt16StereoStreamFormat.mChannelsPerFrame  = 2;                    // 2 indicates stereo
    SInt16StereoStreamFormat.mBitsPerChannel    = 8 * bytesPerSample;
    SInt16StereoStreamFormat.mSampleRate        = self.graphSampleRate;
	
	//return SInt16StereoStreamFormat;
    DLog (@"The stereo stream format for the \"iPod\" mixer input bus:");
	[self printASBD: SInt16StereoStreamFormat];
}

- (void) printASBD: (AudioStreamBasicDescription) asbd {
	
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
    
    DLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    DLog (@"  Format ID:           %10s",    formatIDString);
    DLog (@"  Format Flags:        %10lX",    asbd.mFormatFlags);
    DLog (@"  Bytes per Packet:    %10ld",    asbd.mBytesPerPacket);
    DLog (@"  Frames per Packet:   %10ld",    asbd.mFramesPerPacket);
    DLog (@"  Bytes per Frame:     %10ld",    asbd.mBytesPerFrame);
    DLog (@"  Channels per Frame:  %10ld",    asbd.mChannelsPerFrame);
    DLog (@"  Bits per Channel:    %10ld",    asbd.mBitsPerChannel);
}
# pragma mark- mixer host stuff
- (void) setupAudioSession {
	
	AVAudioSession *mySession = [AVAudioSession sharedInstance];
	NSError *audioSessionError = nil;
	[mySession setCategory: AVAudioSessionCategoryPlayback
					 error: &audioSessionError];
	
	if (audioSessionError != nil) {
		
		DLog (@"Error setting audio session category.");
		return;
	}
	
	// Request the desired hardware sample rate.
	self.graphSampleRate = 44100.0;    // Hertz
	
	[mySession setPreferredSampleRate: self.graphSampleRate
								error: &audioSessionError];
	
	if (audioSessionError != nil) {
		
		DLog (@"Error setting preferred hardware sample rate.");
		return;
	}
	
	// Activate the audio session
	[mySession setActive: YES
				   error: &audioSessionError];
	
	if (audioSessionError != nil) {
		
		DLog (@"Error activating audio session during initial setup.");
		return;
	}
	
	// Obtain the actual hardware sample rate and store it for later use in the audio processing graph.
	self.graphSampleRate = [mySession sampleRate];
	
	if (!notes)
		notes = [NSMutableArray arrayWithCapacity:1];
	
	
	[notes addObject:[[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance] queue:nil usingBlock:^(NSNotification *note) {
		
		NSNumber *interruptType = [[note userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
		
		if ([interruptType intValue] == AVAudioSessionInterruptionTypeBegan)
		{
			
			
			if (self.playing)
			{
				wasPlayingBeforeSeek = YES;
				[self stopAUGraph];
			}
			
			[[NSNotificationCenter defaultCenter] postNotificationName:@"Pause" object:self];
			_playing = NO;
			
		}
		else
		{
			NSNumber* opt = [[note userInfo] objectForKey:AVAudioSessionInterruptionOptionKey];
			
			if (opt.integerValue == AVAudioSessionInterruptionOptionShouldResume)
			{
				if (wasPlayingBeforeSeek)
				{
					[self startAUGraph];
					wasPlayingBeforeSeek = NO;
					[[NSNotificationCenter defaultCenter] postNotificationName:@"Play" object:self];
					
				}
			}
		}
		
	}]];
	
	[notes addObject:[[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance] queue:nil usingBlock:^(NSNotification *note) {
		
		NSNumber *changeType = [[note userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey];
		
		if ([changeType intValue] == AVAudioSessionRouteChangeReasonOldDeviceUnavailable){
			[self pause];
		}
	}]];

}

-(void) configureAndInitializeAudioProcessingGraph {
	@autoreleasepool {
		
		
		DLog (@"Configuring and then initializing audio processing graph");
		OSStatus result = noErr;
		
		//............................................................................
		// Create a new audio processing graph.
		result = NewAUGraph (&processingGraph);
		
		if (noErr != result) {[self printErrorMessage: @"NewAUGraph" withStatus: result]; return;}
		
		
		//............................................................................
		// Specify the audio unit component descriptions for the audio units to be
		//    added to the graph.
		
		// I/O unit
		AudioComponentDescription iOUnitDescription;
		iOUnitDescription.componentType          = kAudioUnitType_Output;
		iOUnitDescription.componentSubType       = kAudioUnitSubType_RemoteIO;
		iOUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
		iOUnitDescription.componentFlags         = 0;
		iOUnitDescription.componentFlagsMask     = 0;
		
		// Multichannel mixer unit
		AudioComponentDescription MixerUnitDescription;
		MixerUnitDescription.componentType          = kAudioUnitType_Mixer;
		MixerUnitDescription.componentSubType       = kAudioUnitSubType_MultiChannelMixer;
		MixerUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
		MixerUnitDescription.componentFlags         = 0;
		MixerUnitDescription.componentFlagsMask     = 0;
		
		AudioComponentDescription EQDescription;
		EQDescription.componentType = kAudioUnitType_Effect;
		EQDescription.componentSubType = kAudioUnitSubType_AUiPodEQ;
		EQDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
		EQDescription.componentFlags = 0;
		EQDescription.componentFlagsMask = 0;
		
		//............................................................................
		// Add nodes to the audio processing graph.
		DLog (@"Adding nodes to audio processing graph");
		
		//    AUNode   iONode;         // node for I/O unit
		//    AUNode   mixerNode;      // node for Multichannel Mixer unit
		//
		// Add the nodes to the audio processing graph
		result =    AUGraphAddNode (
									processingGraph,
									&iOUnitDescription,
									&iONode);
		
		if (noErr != result) {[self printErrorMessage: @"AUGraphNewNode failed for I/O unit" withStatus: result]; return;}
		
		
		result =    AUGraphAddNode (
									processingGraph,
									&MixerUnitDescription,
									&mixerNode
									);
		
		if (noErr != result) {[self printErrorMessage: @"AUGraphNewNode failed for Mixer unit" withStatus: result]; return;}
		
		result = AUGraphAddNode(
								processingGraph,
								&EQDescription,
								&eqNode);
		
		if (noErr != result) {[self printErrorMessage: @"AUGraphNewNode failed for EQ unit" withStatus: result]; return;}
		
		
		//............................................................................
		// Open the audio processing graph
		
		// Following this call, the audio units are instantiated but not initialized
		//    (no resource allocation occurs and the audio units are not in a state to
		//    process audio).
		result = AUGraphOpen (processingGraph);
		
		if (noErr != result) {[self printErrorMessage: @"AUGraphOpen" withStatus: result]; return;}
		
		
		//............................................................................
		// Obtain the mixer unit instance from its corresponding node.
		
		result =    AUGraphNodeInfo (
									 processingGraph,
									 mixerNode,
									 NULL,
									 &_mixerUnit
									 );
		
		if (noErr != result) {[self printErrorMessage: @"AUGraphNodeInfo" withStatus: result]; return;}
		
		result =    AUGraphNodeInfo (
									 processingGraph,
									 iONode,
									 NULL,
									 &_ioUnit
									 );
		
		if (noErr != result) {[self printErrorMessage: @"AUGraphNodeInfo" withStatus: result]; return;}
		
		result =    AUGraphNodeInfo (
									 processingGraph,
									 eqNode,
									 NULL,
									 &_eqUnit
									 );
		
		if (noErr != result) {[self printErrorMessage: @"AUGraphNodeInfo" withStatus: result]; return;}
		//............................................................................
		// Multichannel Mixer unit Setup
		
		UInt32 busCount   = 1;    // bus count for mixer unit input
								  //  UInt32 mainBus  = 0;    // mixer unit bus 0 will be stereo and will take the guitar sound
								  //   UInt32 beatsBus   = 1;    // mixer unit bus 1 will be mono and will take the beats sound
		
		mainBus = 0;
		auxBus = 1;
		
		DLog (@"Setting mixer unit input bus count to: %lu", busCount);
		result = AudioUnitSetProperty (
									   _mixerUnit,
									   kAudioUnitProperty_ElementCount,
									   kAudioUnitScope_Input,
									   0,
									   &busCount,
									   sizeof (busCount)
									   );
		
		if (noErr != result) {[self printErrorMessage: @"AudioUnitSetProperty (set mixer unit bus count)" withStatus: result]; return;}
		
		
		DLog (@"Setting kAudioUnitProperty_MaximumFramesPerSlice for mixer unit global scope");
		// Increase the maximum frames per slice allows the mixer unit to accommodate the
		//    larger slice size used when the screen is locked.
		UInt32 maximumFramesPerSlice = 4096;
		
		result = AudioUnitSetProperty (
									   _mixerUnit,
									   kAudioUnitProperty_MaximumFramesPerSlice,
									   kAudioUnitScope_Global,
									   0,
									   &maximumFramesPerSlice,
									   sizeof (maximumFramesPerSlice)
									   );
		
		if (noErr != result) {[self printErrorMessage: @"AudioUnitSetProperty (set mixer unit input stream format)" withStatus: result]; return;}
		
		result = AudioUnitSetProperty (
									   _eqUnit,
									   kAudioUnitProperty_MaximumFramesPerSlice,
									   kAudioUnitScope_Global,
									   0,
									   &maximumFramesPerSlice,
									   sizeof (maximumFramesPerSlice)
									   );
		
		if (noErr != result) {[self printErrorMessage: @"AudioUnitSetProperty (set eq unit input stream format)" withStatus: result]; return;}
		
		
		// Attach the input render callback and context to each input bus
		for (UInt16 busNumber = 0; busNumber < busCount; ++busNumber) {
			
			// Setup the struture that contains the input render callback
			AURenderCallbackStruct inputCallbackStruct;
			inputCallbackStruct.inputProc        = ipodRenderCallback;
			inputCallbackStruct.inputProcRefCon  = (__bridge void*)self;
			
			DLog (@"Registering the render callback with mixer unit input bus %u", busNumber);
			// Set a callback for the specified node's specified input
			result = AUGraphSetNodeInputCallback (
												  processingGraph,
												  mixerNode,
												  busNumber,
												  &inputCallbackStruct
												  );
			
			if (noErr != result) {[self printErrorMessage: @"AUGraphSetNodeInputCallback" withStatus: result]; return;}
		}
		
		//[self addCrossfadeBus];
		
		DLog (@"Setting stereo stream format for mixer unit \"guitar\" input bus");
		result = AudioUnitSetProperty (
									   _mixerUnit,
									   kAudioUnitProperty_StreamFormat,
									   kAudioUnitScope_Input,
									   mainBus,
									   &SInt16StereoStreamFormat,
									   sizeof (SInt16StereoStreamFormat)
									   );
		
		if (noErr != result) {[self printErrorMessage: @"AudioUnitSetProperty (set mixer unit guitar input bus stream format)" withStatus: result];return;}
		
		//
		//    DLog (@"Setting mono stream format for mixer unit \"beats\" input bus");
		//    result = AudioUnitSetProperty (
		//								   mixerUnit,
		//								   kAudioUnitProperty_StreamFormat,
		//								   kAudioUnitScope_Input,
		//								   beatsBus,
		//								   &monoStreamFormat,
		//								   sizeof (monoStreamFormat)
		//								   );
		//
		//    if (noErr != result) {[self printErrorMessage: @"AudioUnitSetProperty (set mixer unit beats input bus stream format)" withStatus: result];return;}
		//
		
		DLog (@"Setting sample rate for mixer unit output scope");
		// Set the mixer unit's output sample rate format. This is the only aspect of the output stream
		//    format that must be explicitly set.
		result = AudioUnitSetProperty (
									   _mixerUnit,
									   kAudioUnitProperty_SampleRate,
									   kAudioUnitScope_Output,
									   0,
									   &_graphSampleRate,
									   sizeof (_graphSampleRate)
									   );
		
		if (noErr != result) {[self printErrorMessage: @"AudioUnitSetProperty (set mixer unit output stream format)" withStatus: result]; return;}
		
		
		//............................................................................
		// Connect the nodes of the audio processing graph
		DLog (@"Connecting the mixer output to the input of the I/O unit output element");
		
		result = AUGraphConnectNodeInput (
										  processingGraph,
										  mixerNode,         // source node
										  0,                 // source node output bus number
										  eqNode,            // destination node
										  0                  // desintation node input bus number
										  );
		
		if (noErr != result) {[self printErrorMessage: @"AUGraphConnectNodeInput mixer to eq" withStatus: result]; return;}
		
		result = AUGraphConnectNodeInput (
										  processingGraph,
										  eqNode,         // source node
										  0,                 // source node output bus number
										  iONode,            // destination node
										  0                  // desintation node input bus number
										  );
		
		if (noErr != result) {[self printErrorMessage: @"AUGraphConnectNodeInput eq to io" withStatus: result]; return;}
		
		
		DLog(@"set default eq preset");
		
		CFArrayRef mEQPresetsArray;
		UInt32 size = sizeof(mEQPresetsArray);
		result = AudioUnitGetProperty(_eqUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &mEQPresetsArray, &size);
		if (noErr != result) { printf("AudioUnitGetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }

		
		NSInteger presetVal = 0;
		
		if ([[NSUserDefaults standardUserDefaults] objectForKey:@"iPodEQPreset"])
		{
			presetVal = [[NSUserDefaults standardUserDefaults] integerForKey:@"iPodEQPreset"];
		}
		
		AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(mEQPresetsArray, presetVal);
		result = AudioUnitSetProperty(_eqUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, aPreset, sizeof(AUPreset));
		if (noErr != result) { printf("AudioUnitSetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; };
		
		CFRelease(mEQPresetsArray);
		
		
		[self enableMixerInput:mainBus isOn:1];
		[self setMixerInput:mainBus gain:1];
		[self setMixerOutputGain:1];
		
		//............................................................................
		// Initialize audio processing graph
		
		// Diagnostic code
		// Call CAShow if you want to look at the state of the audio processing
		//    graph.
		DLog (@"Audio processing graph state immediately before initializing it:");
		CAShow (processingGraph);
		
		DLog (@"Initializing the audio processing graph");
		// Initialize the audio processing graph, configure audio data stream formats for
		//    each input and output, and validate the connections between audio units.
		result = AUGraphInitialize (processingGraph);
		
		if (noErr != result) {[self printErrorMessage: @"AUGraphInitialize" withStatus: result]; return;}
		
		
		if ([[NSUserDefaults standardUserDefaults] objectForKey:@"iPodEQPreset"])
		{
			[self setEQPreset:[[NSUserDefaults standardUserDefaults] integerForKey:@"iPodEQPreset"]];
		}
		
	}
	
}

-(void)setEQPreset:(NSInteger)value
{
	@autoreleasepool {
		
		_eqPreset = value;
		OSStatus result;
		CFArrayRef mEQPresetsArray;
		UInt32 size = sizeof(mEQPresetsArray);
		result = AudioUnitGetProperty(_eqUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &mEQPresetsArray, &size);
		if (result) { printf("AudioUnitGetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
		
		/*  // this code can be used if you're interested in dumping out the preset list
		 printf("iPodEQ Factory Preset List:\n");
		 UInt8 count = CFArrayGetCount(mEQPresetsArray);
		 for (int i = 0; i < count; ++i) {
		 AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(mEQPresetsArray, i);
		 CFShow(aPreset->presetName);
		 }*/
		
		AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(mEQPresetsArray, value);
		result = AudioUnitSetProperty(_eqUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, aPreset, sizeof(AUPreset));
		if (noErr != result) { printf("AudioUnitSetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; };
		
		CFRelease(mEQPresetsArray);
	}
}

static char *FormatError(char *str, OSStatus error)
{
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    return str;
}
- (void) printErrorMessage: (NSString *) errorString withStatus: (OSStatus) result {

	char *str = (char*)[errorString UTF8String];
	
	char *new = FormatError(str, result);
	
	NSString *string = [NSString stringWithUTF8String:new];
	DLog(@"%@", string)	;
}

#pragma mark -
#pragma mark - crossfade stuff

-(void)addCrossfadeBus
{
	
	OSStatus result = noErr;
	
	UInt32 busCount   = 2;    // bus count for mixer unit input
    UInt32 crossfadeBus  = 1;    // mixer unit bus 0 will be stereo and will take the guitar sound
								 //   UInt32 beatsBus   = 1;    // mixer unit bus 1 will be mono and will take the beats sound
    
    DLog (@"Setting mixer unit input bus count to: %lu", busCount);
    result = AudioUnitSetProperty (
								   _mixerUnit,
								   kAudioUnitProperty_ElementCount,
								   kAudioUnitScope_Input,
								   0,
								   &busCount,
								   sizeof (busCount)
								   );
	
    if (noErr != result) {[self printErrorMessage: @"AudioUnitSetProperty (set mixer unit bus count)" withStatus: result]; return;}

	// Setup the struture that contains the input render callback
	AURenderCallbackStruct inputCallbackStruct;
	inputCallbackStruct.inputProc        = ipodRenderCallback;
	inputCallbackStruct.inputProcRefCon  = (__bridge void*)self;
    
	// DLog (@"Registering the render callback with mixer unit input bus %u", busNumber);
	// Set a callback for the specified node's specified input
	result = AUGraphSetNodeInputCallback (
										  processingGraph,
										  mixerNode,
										  crossfadeBus,
										  &inputCallbackStruct
										  );
	
	if (noErr != result) {[self printErrorMessage: @"AUGraphSetNodeInputCallback" withStatus: result]; return;}
	// }
	
	
    DLog (@"Setting stereo stream format for mixer unit \"guitar\" input bus");
    result = AudioUnitSetProperty (
								   _mixerUnit,
								   kAudioUnitProperty_StreamFormat,
								   kAudioUnitScope_Input,
								   crossfadeBus,
								   &SInt16StereoStreamFormat,
								   sizeof (SInt16StereoStreamFormat)
								   );
	
    if (noErr != result) {[self printErrorMessage: @"AudioUnitSetProperty (set mixer unit guitar input bus stream format)" withStatus: result];return;}
	
	[self enableMixerInput:auxBus isOn:0];
	
}


#pragma mark -
#pragma mark Playback control

// Start playback
- (void) startAUGraph  {
	
	if (!self.isPlaying)
	{

		if (self.song)
		{
			[self loadBufferAtStartTime:[self trackPosition] reset:YES];
		}
		
		DLog (@"Starting audio processing graph");
		OSStatus result = AUGraphStart (processingGraph);
		if (noErr != result) {[self printErrorMessage: @"AUGraphStart" withStatus: result]; return;}
		
		_playing = YES;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"Play" object:nil];
		
	}
}

// Stop playback
- (void) stopAUGraph {
	
    DLog (@"Stopping audio processing graph");
    Boolean isRunning = false;
    OSStatus result = AUGraphIsRunning (processingGraph, &isRunning);
    if (noErr != result) {[self printErrorMessage: @"AUGraphIsRunning" withStatus: result]; return;}
	_playing = NO;
	
    if (isRunning) {

		for (NSUInteger i = 0; i < 10 && isRunning; i++) {
			AUGraphStop(processingGraph);
			AUGraphIsRunning(processingGraph, &isRunning);
		}

		[[NSNotificationCenter defaultCenter] postNotificationName:@"Pause" object:nil];
	}
}

-(void)teardownCoreAudio {
	
	[self removeObserver:self forKeyPath:@"spPlayback.isPlaying"];
    if (processingGraph == NULL)
        return;

	[iTunesOperationQueue cancelAllOperations];
	iTunesOperationQueue = nil;
	
	audioStructs[mainBus].playingiPod = NO;
	audioStructs[mainBus].bufferIsReady = NO;
	
	TPCircularBufferCleanup(&audioStructs[mainBus].circularBuffer);
	
    AUGraphStop(processingGraph);
		
	AUGraphUninitialize(processingGraph);
	DisposeAUGraph(processingGraph);

	processingGraph = NULL;
	self.ioUnit = NULL;
	self.mixerUnit = NULL;
	self.eqUnit = NULL;
	
	for (id note in notes)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:note];
	}
}

#pragma mark -
#pragma mark Mixer unit control
// Enable or disable a specified bus
- (void) enableMixerInput: (UInt32) inputBus isOn: (AudioUnitParameterValue) isOnValue {
	
    DLog (@"Bus %d now %@", (int) inputBus, isOnValue ? @"on" : @"off");
	
    OSStatus result = AudioUnitSetParameter (
											 _mixerUnit,
											 kMultiChannelMixerParam_Enable,
											 kAudioUnitScope_Input,
											 inputBus,
											 isOnValue,
											 0
											 );
	
    if (noErr != result) {[self printErrorMessage: @"AudioUnitSetParameter (enable the mixer unit)" withStatus: result]; return;}

}


// Set the mixer unit input volume for a specified bus
- (void) setMixerInput: (UInt32) inputBus gain: (AudioUnitParameterValue) newGain {
	
	/*
	 This method does *not* ensure that sound loops stay in sync if the user has
	 moved the volume of an input channel to zero. When a channel's input
	 level goes to zero, the corresponding input render callback is no longer
	 invoked. Consequently, the sample number for that channel remains constant
	 while the sample number for the other channel continues to increment. As a
	 workaround, the view controller Nib file specifies that the minimum input
	 level is 0.01, not zero.
	 
	 The enableMixerInput:isOn: method in this class, however, does ensure that the
	 loops stay in sync when a user disables and then reenables an input bus.
	 */
    OSStatus result = AudioUnitSetParameter (
											 _mixerUnit,
											 kMultiChannelMixerParam_Volume,
											 kAudioUnitScope_Input,
											 inputBus,
											 newGain,
											 0
											 );
	
    if (noErr != result) {[self printErrorMessage: @"AudioUnitSetParameter (set mixer unit input volume)" withStatus: result]; return;}
    
}


// Set the mxer unit output volume
- (void) setMixerOutputGain: (AudioUnitParameterValue) newGain {
	
    OSStatus result = AudioUnitSetParameter (
											 _mixerUnit,
											 kMultiChannelMixerParam_Volume,
											 kAudioUnitScope_Output,
											 0,
											 newGain,
											 0
											 );
	
    if (noErr != result) {[self printErrorMessage: @"AudioUnitSetParameter (set mixer unit output volume)" withStatus: result]; return;}
    
}


-(AudioUnitParameterValue)getInputGainForBus:(UInt32)bus
{
	AudioUnitParameterValue gain;
	
	AudioUnitGetParameter(_mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, bus, &gain);
	
	return gain;
}

#pragma mark - seeking

static BOOL wasPlayingBeforeSeek = NO;
-(void)beginSeek
{
	
	_seeking = YES;

	scrubStartTime = self.trackPosition;

	audioStructs[mainBus].bufferIsReady = NO;
	audioStructs[mainBus].playingiPod = NO;

}

- (void)endSeek
{
	_seeking = NO;
    
    audioStructs[mainBus].bufferIsReady = YES;
	audioStructs[mainBus].playingiPod = YES;
}


-(void)setCurrentTime:(NSTimeInterval)time
{
	[self seekToTime:time];
}
-(void)seekToTime:(NSTimeInterval)time
{
	audioStructs[mainBus].currentSampleNum = time * SInt16StereoStreamFormat.mSampleRate;
    [self willChangeValueForKey:@"trackPosition"];
	_trackPosition = time;
    [self didChangeValueForKey:@"trackPosition"];
	[self.delegate musicPlayer:self didOutputAudioOfDuration:_trackPosition];
	
	audioStructs[mainBus].playingiPod = NO;
	audioStructs[mainBus].bufferIsReady = NO;
	
	if (!_seeking)
		[self loadBufferAtStartTime:time reset:NO];
}
-(void)loadBufferAtStartTime:(NSTimeInterval)time reset:(BOOL)reset
{

	audioStructs[mainBus].playingiPod = YES;
	
	[iTunesOperationQueue cancelAllOperations];
	[self cleanUpBufferForBus:0];
	
	_trackPosition = time;
	framesSinceLastTimeUpdate = 0;
	audioStructs[mainBus].currentSampleNum = time * SInt16StereoStreamFormat.mSampleRate;
	
	
	
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                    [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                                    [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                    nil];
	
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[self.song url] options:nil];
    if (asset == nil) {
		
        DLog(@"asset is not defined!");
        return;
    }
    NSError *assetError = nil;
    __block AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:asset error:&assetError];
    if (assetError) {
        DLog (@"error: %@", assetError);
        return;
    }
	
	if (time!= 0)
	{
		assetReader.timeRange = CMTimeRangeMake((time == 0 ? kCMTimeZero : CMTimeMakeWithSeconds(time, 1)), kCMTimePositiveInfinity);
		
	}
	
	
    __block AVAssetReaderOutput *readerOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:[asset tracksWithMediaType:AVMediaTypeAudio] audioSettings:outputSettings];
	
    if (! [assetReader canAddOutput: readerOutput]) {
        DLog (@"can't add reader output... die!");
        return;
    }
    // add output reader to reader
    [assetReader addOutput: readerOutput];
	
    if (! [assetReader startReading]) {
        DLog(@"Unable to start reading!");
        return;
    }
	
	TPCircularBufferInit(&audioStructs[mainBus].circularBuffer, kTotalBufferSize);
	__block AudioStruct *audio = &audioStructs[mainBus];
	
	__block NSBlockOperation * feediPodBufferOperation = [NSBlockOperation blockOperationWithBlock:^{
		while (![feediPodBufferOperation isCancelled] && assetReader.status != AVAssetReaderStatusCompleted) {
			if (assetReader.status == AVAssetReaderStatusReading) {

				if (kTotalBufferSize - audio->circularBuffer.fillCount >= 32768) {

                    CMSampleBufferRef nextBuffer = [readerOutput copyNextSampleBuffer];
					
                    if (nextBuffer) {

                        AudioBufferList abl;
                        CMBlockBufferRef blockBuffer;
                        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer, NULL, &abl, sizeof(abl), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
                        UInt64 size = CMSampleBufferGetTotalSampleSize(nextBuffer);

						int bytesCopied = TPCircularBufferProduceBytes(&audio->circularBuffer, abl.mBuffers[0].mData, size);
						
						if (!audio->bufferIsReady && bytesCopied > 0) {
                            audio->bufferIsReady = YES;
							audio->playingiPod = YES;
							
						}
						
                        CFRelease(nextBuffer);
                        CFRelease(blockBuffer);
                    }
                    else {
                        break;
                    }
				}
			}
        }
		
		feediPodBufferOperation = nil;
		assetReader = nil;
		DLog(@"iPod Buffer Reading Finished");
    }];
		
    [iTunesOperationQueue addOperation:feediPodBufferOperation];
}

-(void)dealloc
{
	[self teardownCoreAudio];
	
	for (id note in notes) {
		[[NSNotificationCenter defaultCenter] removeObserver:note];
	}
	
	for (id observer in self.observingObjects) {
		[self removeObserver:observer forKeyPath:@"trackPosition"];
	}
}


@end
