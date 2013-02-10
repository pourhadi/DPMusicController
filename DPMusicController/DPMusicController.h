//
//  DPMusicController.h
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DPMusicPlayer.h"
#import "DPMusicConstants.h"
#import "DPMusicItemIndexSection.h"
#import "DPMusicItemSong.h"
#import "DPMusicItemArtist.h"
#import "DPMusicItemAlbum.h"

@class DPMusicLibraryManager;


typedef NS_ENUM(NSUInteger, DPMusicIndexType) {
	DPMusicIndexTypePlaylistIndex,				// equivalent to index of object in array
	DPMusicIndexTypeIndexRelativeToPlayhead,	// 0 = playhead, 1 = playhead + 1, etc.
};


@interface DPMusicController : NSObject <DPMusicPlayerDelegate>

+ (DPMusicController*)sharedController;

//*****
//
// library controls
//
//****

@property (nonatomic, strong, readonly) DPMusicLibraryManager *libraryManager;

- (BOOL)libraryLoaded;

@property (nonatomic, readonly) NSArray *songs;
@property (nonatomic, readonly) NSArray *indexedSongs;

@property (nonatomic, readonly) NSArray *artists;
@property (nonatomic, readonly) NSArray *indexedArtists;

@property (nonatomic, readonly) NSArray *albums;
@property (nonatomic, readonly) NSArray *indexedAlbums;

//*****
//
// playlist / queue controls
//
//****

- (DPMusicItemSong*)currentSong;
- (void)setCurrentSong:(DPMusicItemSong *)currentSong play:(BOOL)play;

@property (nonatomic, readonly) BOOL isPlaying;

- (BOOL)play;
- (void)pause;

- (void)nextWithCrossfade:(BOOL)crossfade;
- (void)previousWithCrossfade:(BOOL)crossfade;

@property (nonatomic, readonly, strong) NSArray *playlist; // the current queue / playlist, an array of DPMusicItems
- (void)setPlaylist:(NSArray *)playlist withPlayheadAtIndex:(NSInteger)index play:(BOOL)play;

// the playhead represents the index of the currently-playing song in the playlist array
@property (nonatomic, readonly) NSInteger playhead;
- (void)setPlayhead:(NSInteger)playhead play:(BOOL)play;

- (BOOL)addSong:(DPMusicItemSong*)song; // adds to end of the playlist; returns NO if song already exists in playlist
- (BOOL)insertSong:(DPMusicItemSong*)song atIndex:(NSInteger)index indexType:(DPMusicIndexType)type; // returns NO if index is beyond playlist bounds or if trying to insert song at playhead (use setCurrentSong:play: instead)
- (BOOL)removeSong:(DPMusicItemSong*)song; // returns NO if song isn't in playlist of it song is currentSong

- (BOOL)addSongCollection:(DPMusicItemCollection*)collection;
- (BOOL)insertSongCollection:(DPMusicItemCollection*)collection atIndex:(NSInteger)index indexType:(DPMusicIndexType)type;

- (NSInteger)indexOfSong:(DPMusicItemSong*)song indexType:(DPMusicIndexType)type;

- (void)shufflePlaylist:(BOOL)unplayedSongsOnly;
- (void)clearPlaylist;

//*****
//
// player controls
//
//****

@property (nonatomic, strong, readonly) DPMusicPlayer *player;

@property (nonatomic) NSInteger eqPreset;
@property (nonatomic) Float64 volume;

@property (nonatomic, readonly) NSTimeInterval trackPosition;

- (NSString*)elapsedTimeString;		// i.e. 02:47
- (NSString*)remainingTimeString;	// i.e. -01:15

- (void)seekToTime:(NSTimeInterval)time;

@property (nonatomic, readonly) NSTimeInterval duration;	// duration of current song in seconds

// handy helper to simplify scrubbing from a UISlider
- (void)enableScrubbingFromSlider:(UISlider*)slider;
- (void)disableScrubbingFromSlider:(UISlider*)slider;

// if seeking / scrubbing without using the set up method above, be sure to call these when the seek begins / ends
- (void)beginSeek;
- (void)endSeek;


//*****
//
// crossfading
//
//****
@property (nonatomic) BOOL automaticCrossfadeEnabled;	// default: NO
														// manually crossfade to the specified song
-(void)crossfadeToSong:(DPMusicItemSong*)song;

// crossfade settings
@property (nonatomic) NSTimeInterval crossfadeDuration; // default: 6 seconds
@property (nonatomic) Float64 fadeInFromVolume;	// between 0-1, default: 0
@property (nonatomic) Float64 fadeOutToVolume;	// between 0-1, default: 0


@end
