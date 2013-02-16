//
//  DPMusicPlayer.h
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TPCircularBuffer+AudioBufferList.h"
#import "TPCircularBuffer.h"
#import <AVFoundation/AVFoundation.h>

@class DPMusicItem;
@class DPMusicItemSong;
@protocol DPMusicPlayerDelegate;

typedef struct {
	TPCircularBuffer circularBuffer;
	BOOL playingiPod;
	BOOL bufferIsReady;
	NSInteger currentSampleNum;
	BOOL seeking;
	
} AudioStruct, *AudioStructPtr;

@interface DPMusicPlayer : NSObject<AVAudioSessionDelegate>

@property (nonatomic, weak) id<DPMusicPlayerDelegate> delegate;

@property (nonatomic) Float64 volume;

@property (nonatomic) BOOL interruptedDuringPlayback;

@property (nonatomic, strong, readonly) DPMusicItemSong *song;	// current song; use -setCurrentSong:play: to change
-(void)setCurrentSong:(DPMusicItemSong*)song play:(BOOL)play;

@property (getter = isPlaying, readonly) BOOL playing;
-(BOOL)play;
-(void)pause;

@property (nonatomic, readonly) NSTimeInterval trackPosition;			// current position of playhead in seconds
- (void)registerObjectToReceiveTrackPositionKVO:(id)obj;				// register to monitor track position (i.e., for sliders)
- (void)seekToTime:(NSTimeInterval)time;

@property (nonatomic, readonly) NSTimeInterval duration;	// duration of current song in seconds
@property (nonatomic, strong, readonly) AVAsset *asset;		// AVAsset of current track

// if seeking / scrubbing using something other than a UISlider, be sure to call these when the seek begins and the seek ends
- (void)beginSeek;
- (void)endSeek;

@property (nonatomic) NSInteger eqPreset;


- (void)teardownCoreAudio;

@end

@protocol DPMusicPlayerDelegate <NSObject>

-(void)playbackDidFinish;
@end
