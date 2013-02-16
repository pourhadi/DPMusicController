//
//  DPMusicController.m
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import "DPMusicController.h"
#import "DPMusicPlayer.h"
#import "DPMusicItem.h"

@interface DPMusicController ()
{
	DPMusicPlayer *_player;
	NSArray *_queue;
	
	NSTimer *fadeOutTimer;
	NSTimer *fadeInTimer;
	
	BOOL fadingOut;
	BOOL fadingIn;
	
	NSTimeInterval _trackPosition;
}

@property (nonatomic, strong) DPMusicPlayer *crossfadePlayer;

@end


@implementation DPMusicController

+ (DPMusicController*)sharedController
{
    static dispatch_once_t onceQueue;
    static DPMusicController *dPMusicController = nil;
	
    dispatch_once(&onceQueue, ^{ dPMusicController = [[self alloc] init]; });
    return dPMusicController;
}


- (id)init
{
	self = [super init];
	
	if (self) {
		_libraryManager = [[DPMusicLibraryManager alloc] init];
		_crossfadeDuration = 6;
		_playhead = 0;
		_fadeInFromVolume = 0;
		_fadeOutToVolume = 0;
	}
	
	return self;
}

#pragma mark - playlist controls

- (NSArray*)queue
{
	if (!_queue) {
		_queue = [NSArray array];
	}
	
	return _queue;
}

- (void)setQueue:(NSArray *)queue
{
	[self willChangeValueForKey:@"queue"];
	_queue = queue;
	[self didChangeValueForKey:@"queue"];
}

- (DPMusicItemSong*)currentSong
{
	DPMusicItemSong *song;
	song = [self.queue objectAtIndex:self.playhead];
	
	return song;
}

- (void)setCurrentSong:(DPMusicItemSong *)currentSong play:(BOOL)play error:(NSError *__autoreleasing *)error
{
	NSMutableArray *mutablePlaylist = [self.queue mutableCopy];
	
	if ([self.queue containsObject:currentSong]) {
		
		NSUInteger index = [self indexOfSong:currentSong indexType:DPMusicIndexTypePlaylistIndex error:nil];
		
		if (index < self.playhead) {
			[self setPrimitivePlayhead:self.playhead-1];
		}
		
		[mutablePlaylist removeObject:currentSong];
		
		[self setQueue:[mutablePlaylist copy]];
		
	}
	
	[mutablePlaylist insertObject:currentSong atIndex:self.playhead];
	[self setQueue:[mutablePlaylist copy]];
	[self.player setCurrentSong:currentSong play:play];
	[self playlistChanged];
}

- (BOOL)play:(NSError *__autoreleasing *)error
{
	return [self.player play];
}

- (void)pause:(NSError *__autoreleasing *)error
{
	[self.player pause];
}

- (void)nextWithCrossfade:(BOOL)crossfade error:(NSError *__autoreleasing *)error
{
	if (self.queue.count < 1) {
		*error = [NSError errorWithDomain:kDPMusicErrorDomain code:0 userInfo:@{kDPMusicErrorDescriptionKey: @"There are no songs in your Queue."}];
		return;
	}
	
	NSInteger newPlayhead = self.playhead;
	if (self.playhead == self.queue.count-1) {
		newPlayhead = 0;
	} else {
		newPlayhead += 1;
	}
	
	BOOL play = self.isPlaying;
	
	if (crossfade) {
		play = NO;
	}
	
	[self setPrimitivePlayhead:newPlayhead];
	DPMusicItemSong *newSong = self.queue[self.playhead];

	if (crossfade && self.isPlaying) {
		[self crossfadeToSong:newSong];
	} else {
		[self setCurrentSong:newSong play:play error:error];
	}
}
- (void)previousWithCrossfade:(BOOL)crossfade error:(NSError *__autoreleasing *)error
{
	if (self.queue.count < 1) {
		*error = [NSError errorWithDomain:kDPMusicErrorDomain code:0 userInfo:@{kDPMusicErrorDescriptionKey: @"There are no songs in your Queue."}];
		return;
	}
	
	NSInteger newPlayhead = self.playhead;
	if (self.playhead == 0) {
		newPlayhead = self.queue.count-1;
	} else {
		newPlayhead -= 1;
	}
	
	BOOL play = self.isPlaying;
	
	if (crossfade) {
		play = NO;
	}
	
	[self setPrimitivePlayhead:newPlayhead];
	DPMusicItemSong *newSong = self.queue[self.playhead];
	
	if (crossfade && self.isPlaying) {
		[self crossfadeToSong:newSong];
	} else {
		[self setCurrentSong:newSong play:play error:error];
	}
}

- (void)setQueue:(NSArray *)playlist withPlayheadAtIndex:(NSInteger)index play:(BOOL)play error:(NSError *__autoreleasing *)error
{
	[self setQueue:playlist];
	
	[self setPlayhead:index play:play error:error];
}

- (void)setPlayhead:(NSInteger)playhead play:(BOOL)play error:(NSError *__autoreleasing *)error
{
	if (playhead >= self.queue.count) {
		*error = [NSError errorWithDomain:kDPMusicErrorDomain code:0 userInfo:@{kDPMusicErrorDescriptionKey: [NSString stringWithFormat:@"New playhead (%d) outside of bounds of queue with %d songs", playhead, self.queue.count]}];
		return;
	}
	
	[self setPrimitivePlayhead:playhead];
	
	[self.player setCurrentSong:[self.queue objectAtIndex:self.playhead] play:play];
	[self playlistChanged];
}

- (void)setPrimitivePlayhead:(NSInteger)playhead
{
	[self willChangeValueForKey:@"playhead"];
	_playhead = playhead;
	[self didChangeValueForKey:@"playhead"];
}

- (BOOL)addSong:(DPMusicItemSong *)song error:(NSError *__autoreleasing *)error
{
	if ([self.queue containsObject:song]) {
		if (error)
			*error = [[NSError alloc] initWithDomain:kDPMusicErrorDomain code:101 userInfo:@{kDPMusicErrorDescriptionKey: [NSString stringWithFormat:@"The song you are trying to add ('%@') is already in the playlist.", song.title]}];
		return NO;
	}
	
	NSMutableArray *mutablePlaylist = [self.queue mutableCopy];
	[mutablePlaylist addObject:song];
	
	[self setQueue:[mutablePlaylist copy]];
	[self playlistChanged];
	
	return YES;
}

- (BOOL)insertSong:(DPMusicItemSong *)song atIndex:(NSInteger)index indexType:(DPMusicIndexType)type error:(NSError *__autoreleasing *)error
{
	NSInteger newIndex = index;
	NSMutableArray *mutablePlaylist = [self.queue mutableCopy];
	
	if (type == DPMusicIndexTypeIndexRelativeToPlayhead) {
		newIndex = [self convertIndex:index toType:DPMusicIndexTypePlaylistIndex];
	}
	
	if (newIndex > self.queue.count) {
		*error = [NSError errorWithDomain:kDPMusicErrorDomain code:100 userInfo:@{kDPMusicErrorDescriptionKey:[NSString stringWithFormat:@"Attempting to insert song (%@) at index %d is beyond the playlist bounds.", song.title, index]}];
		
		return NO;
	}
	BOOL newPlayhead = self.playhead;

	if ([self.queue containsObject:song]) {
		NSInteger currentIndex = [self indexOfSong:song indexType:DPMusicIndexTypePlaylistIndex error:nil];
		
		if (currentIndex < self.playhead) {
			if (newIndex > self.playhead) {
				newPlayhead -= 1;
			} else if (newIndex > self.playhead) {
				newPlayhead += 1;
			}
		} else if (currentIndex == self.playhead) {
			return NO;
		}
		
		[mutablePlaylist removeObject:song];
	}
	
	if (newIndex < self.playhead) {
		newPlayhead-= 1;
	}
	
	[self setPrimitivePlayhead:newPlayhead];
	
	[mutablePlaylist insertObject:song atIndex:newIndex];
	[self setQueue:[mutablePlaylist copy]];
	[self playlistChanged];
	
	return YES;
}

- (BOOL)removeSong:(DPMusicItemSong *)song error:(NSError *__autoreleasing *)error
{
	if (![self.queue containsObject:song]) {
		*error = [NSError errorWithDomain:kDPMusicErrorDomain code:102 userInfo:@{kDPMusicErrorDescriptionKey:[NSString stringWithFormat:@"The song you are trying to remove from the playlist (%@) is not in the playlist.", song.title]}];
		return NO;
	}
	
	NSInteger index = [self indexOfSong:song indexType:DPMusicIndexTypePlaylistIndex error:error];
	
	if (index == self.playhead) {
		return NO;
	} else if (index < self.playhead) {
		[self setPrimitivePlayhead:self.playhead-1];
	}
	
	NSMutableArray *mutablePlaylist = [self.queue mutableCopy];
	[mutablePlaylist removeObject:song];
	
	[self setQueue:[mutablePlaylist copy]];
	[self playlistChanged];
	
	return YES;
}

- (BOOL)addSongCollection:(DPMusicItemCollection *)collection shuffle:(BOOL)shuffle error:(NSError *__autoreleasing *)error
{
	NSMutableArray *mutablePlaylist = [self.queue copy];
	
	NSArray *items = collection.songs;
	
	if (shuffle) {
		items = [self shuffle:items];
	}
	
	for (DPMusicItemSong *song in items) {
		if ([self.queue containsObject:song]) {
			
			NSInteger currentIndex = [self indexOfSong:song indexType:DPMusicIndexTypePlaylistIndex error:nil];
			if (currentIndex < self.playhead) {
				[self setPrimitivePlayhead:self.playhead-1];
			} else if (currentIndex == self.playhead) {
				return NO;
			}
			
		}
		[mutablePlaylist addObject:song];
		
	}
	
	[self setQueue:[mutablePlaylist copy]];
	[self playlistChanged];
	
	return YES;
}

- (BOOL)insertSongCollection:(DPMusicItemCollection*)collection atIndex:(NSInteger)index indexType:(DPMusicIndexType)type shuffle:(BOOL)shuffle error:(NSError *__autoreleasing *)error
{
	NSInteger newIndex = index;
	NSMutableArray *mutablePlaylist = [self.queue mutableCopy];
	
	if (type == DPMusicIndexTypeIndexRelativeToPlayhead) {
		newIndex = [self convertIndex:index toType:DPMusicIndexTypePlaylistIndex];
	}
	
	if (newIndex > self.queue.count) {
		return NO;
	}
	
	NSArray *items = collection.songs;
	
	if (shuffle) {
		items = [self shuffle:items];
	}
	
	NSInteger newPlayhead = self.playhead;
	
	for (DPMusicItemSong *song in items) {
		if ([self.queue containsObject:song]) {
			NSInteger currentIndex = [self indexOfSong:song indexType:DPMusicIndexTypePlaylistIndex error:nil];
			if (currentIndex < self.playhead) {
				if (newIndex > self.playhead) {
					newPlayhead -= 1;
				} else if (newIndex > self.playhead) {
					newPlayhead += 1;
				}
			} else if (currentIndex == self.playhead) {
				return NO;
			}
			
			[mutablePlaylist removeObject:song];
		}
		
		if (newIndex < self.playhead) {
			newPlayhead -= 1;
		}
		[mutablePlaylist insertObject:song atIndex:newIndex];
		
	}
	
	[self setPrimitivePlayhead:newPlayhead];
	[self setQueue:[mutablePlaylist copy]];
	[self playlistChanged];
	
	return YES;
}

- (NSInteger)indexOfSong:(DPMusicItemSong*)song indexType:(DPMusicIndexType)type error:(NSError *__autoreleasing *)error
{
	__block NSInteger index;
	
	[self.queue enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		
		if (obj == song) {
			index = idx;
			*stop = YES;
		}
		
	}];
	
	if (type == DPMusicIndexTypeIndexRelativeToPlayhead) {
		index = [self convertIndex:index toType:DPMusicIndexTypeIndexRelativeToPlayhead];
	}
	
	return index;
}

- (NSInteger)convertIndex:(NSInteger)index toType:(DPMusicIndexType)toType
{
	// assume from type is opposite of to type
	
	NSInteger newIndex = index;
	
	switch (toType) {
		case DPMusicIndexTypeIndexRelativeToPlayhead:
			
			// index - playhead = newindex
			
			newIndex = index - self.playhead;
			
			break;
		case DPMusicIndexTypePlaylistIndex:
			
			// index + playhead = newindex
			
			newIndex = index + self.playhead;
			
			break;
		default:
			break;
	}
	
	return newIndex;
}

- (void)shuffleQueue:(BOOL)unplayedSongsOnly error:(NSError *__autoreleasing *)error
{
	NSArray *songsToShuffle;
	DPMusicItemSong *playingSong;
	if (unplayedSongsOnly) {
		songsToShuffle = [self.queue objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.playhead+1, (self.queue.count - self.playhead+1))]];
	} else {
		
		if (self.isPlaying) {
			playingSong = self.currentSong;
			NSMutableArray *mutablePlaylist = [self.queue mutableCopy];
			[mutablePlaylist removeObjectAtIndex:self.playhead];
			songsToShuffle = [mutablePlaylist copy];
		} else {
			songsToShuffle = self.queue;
		}
		[self setPrimitivePlayhead:0];
	}
	
	[self setQueue:[self shuffle:songsToShuffle]];
	
	if (playingSong) {
		NSMutableArray *mutablePlaylist = [self.queue mutableCopy];
		[mutablePlaylist insertObject:playingSong atIndex:0];
		[self setQueue:[mutablePlaylist copy]];
	}
	[self playlistChanged];
}

- (NSArray *) shuffle:(NSArray*)array
{
	NSMutableArray *tmpArray = [NSMutableArray arrayWithCapacity:[array count]];
	
	for (id anObject in array)
	{
		NSUInteger randomPos = arc4random()%([tmpArray count]+1);
		[tmpArray insertObject:anObject atIndex:randomPos];
	}
	
	return [NSArray arrayWithArray:tmpArray];  // non-mutable autoreleased copy
}

- (void)clearQueue:(NSError *__autoreleasing *)error
{
	NSArray *newPlaylist;
	if (self.isPlaying) {
		DPMusicItemSong *currentSong = self.currentSong;
		newPlaylist = [NSArray arrayWithObject:currentSong];
	} else {
		newPlaylist = [NSArray array];
	}
	
	[self setQueue:newPlaylist];
	[self setPrimitivePlayhead:0];
	
	[self playlistChanged];
}

- (void)playlistChanged
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kDPMusicNotificationPlaylistChanged object:nil];
}


#pragma mark - player controls

- (DPMusicPlayer*)player
{
	if (!_player)
	{
		_player = [[DPMusicPlayer alloc] init];
		_player.delegate = self;
		[_player registerObjectToReceiveTrackPositionKVO:self];
	}
	return _player;
}

-(void)playbackDidFinish
{
	[self nextWithCrossfade:NO error:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self willChangeValueForKey:@"trackPosition"];
	_trackPosition = self.player.trackPosition;
	[self didChangeValueForKey:@"trackPosition"];
}

- (BOOL)isPlaying
{
	return self.player.isPlaying;
}

- (NSInteger)eqPreset
{
	return self.player.eqPreset;
}

- (void)setEqPreset:(NSInteger)eqPreset
{
	self.player.eqPreset = eqPreset;
}

- (void)setVolume:(Float64)volume
{
	self.player.volume = volume;
}

- (Float64)volume
{
	return self.player.volume;
}

- (NSString*)elapsedTimeString
{
	UInt64 currentTimeSec = self.trackPosition;
	
	int minutes = currentTimeSec / 60;
	int seconds = (currentTimeSec % 60);
	NSString *elapsed = [NSString stringWithFormat: @"%02d:%02d", minutes, seconds];
	
	return elapsed;
}

- (NSString*)remainingTimeString
{
	UInt64 leftTimeVal = self.duration - self.trackPosition;
	int leftMinutes = leftTimeVal / 60;
	int leftSeconds = (leftTimeVal % 60);
	NSString *remaining = [NSString stringWithFormat:@"-%02d:%02d", leftMinutes, leftSeconds];
	return remaining;
}

- (void)seekToTime:(NSTimeInterval)time
{
	[self.player seekToTime:time];
}

- (NSTimeInterval)duration
{
	return self.player.duration;
}

- (void)enableScrubbingFromSlider:(UISlider *)slider
{
	[slider addTarget:self action:@selector(beginSeek) forControlEvents:UIControlEventTouchDown];
	[slider addTarget:self action:@selector(scrub:) forControlEvents:UIControlEventValueChanged | UIControlEventTouchDown];
	[slider addTarget:self action:@selector(endSeek) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |UIControlEventTouchCancel];
}

- (void)disableScrubbingFromSlider:(UISlider *)slider
{
	[slider removeTarget:self action:@selector(beginSeek) forControlEvents:UIControlEventTouchDown];
	[slider removeTarget:self action:@selector(scrub:) forControlEvents:UIControlEventValueChanged | UIControlEventTouchDown];
	[slider removeTarget:self action:@selector(endSeek) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |UIControlEventTouchCancel];
}

- (void)scrub:(id)sender
{
	UISlider *playbackSlider = (UISlider*)sender;
	
	NSTimeInterval duration = self.duration;
	NSTimeInterval seekTime = duration * playbackSlider.value;
	
	[self seekToTime:seekTime];
}

- (void)beginSeek
{
	[self.player beginSeek];
}

- (void)endSeek
{
	[self.player endSeek];
}

#pragma mark - crossfading

- (void)crossfadeToSong:(DPMusicItemSong *)song
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self beginFadeInToSong:song];
		[self beginCrossfade];
	});
}

static CGFloat fadeOutVol;
-(void)performBackgroundFadeForPlayer:(DPMusicPlayer *)whichPlayer
{
	if (whichPlayer == self.player)
	{
		
		fadeOutVol = self.fadeOutToVolume;
		
		float dur = self.crossfadeDuration;
		
		float currentVol = self.player.volume;
		
		float denom = dur / 0.1;
		
		float step = currentVol / denom;
		
		fadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(fadeDownWithStep:) userInfo:[NSNumber numberWithFloat:step] repeats:YES];
	}
	else
	{
		float inDur = self.crossfadeDuration;
		float inVol = self.fadeInFromVolume;
		[self.crossfadePlayer setVolume:inVol];
		[self.crossfadePlayer play];
		
		float denom = inDur / 0.1;
		
		float step = (1-inVol) / denom;
		
		fadeInTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(fadeUpWithStep:) userInfo:[NSNumber numberWithFloat:step] repeats:YES];
		
	}
	
}
-(void)fadeDownWithStep:(NSTimer*)timer
{
	
	NSNumber *step = [timer userInfo];
	
	if (self.player && self.player.volume > fadeOutVol && fadingOut)
	{
		self.player.volume -= [step floatValue];
		
	}
	else
	{
		[fadeOutTimer invalidate];
		fadeOutTimer = nil;
		
		[fadeInTimer invalidate];
		fadeInTimer = nil;
		
		[self endCrossfade];
	}
	
}
-(void)fadeUpWithStep:(NSTimer*)timer
{
	
	NSNumber *step = [timer userInfo];
	
	if (self.crossfadePlayer && self.crossfadePlayer.volume < 1 && fadingIn)
	{
		self.crossfadePlayer.volume += [step floatValue];
		
	}
}

-(void)beginCrossfade
{
	fadingOut = YES;
	
	[self performBackgroundFadeForPlayer:self.player];
	
}
-(void)beginFadeInToSong:(DPMusicItemSong*)song
{
	
	fadingIn = YES;
	fadingOut = YES;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kDPMusicNotificationCrossfadeBegan object:nil];
	});
	
	if (self.crossfadePlayer)
		self.crossfadePlayer = nil;
	
	
	self.crossfadePlayer = [[DPMusicPlayer alloc] init];
	[self.crossfadePlayer setCurrentSong:song play:NO];
	[self.crossfadePlayer registerObjectToReceiveTrackPositionKVO:self];
	
	NSTimeInterval startTime = 0;
	
	[self.crossfadePlayer seekToTime:startTime];
	//float inVol = self.fadeInFromVolume;
	//[self.crossfadePlayer setVolume:inVol];
	//[self.crossfadePlayer play];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self performBackgroundFadeForPlayer:self.crossfadePlayer];
		
	});
	
}
-(void)endCrossfade
{
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kDPMusicNotificationCrossfadeEnded object:nil];
	});
	
	if (self.player)
	{
		
		[self.player teardownCoreAudio];
		//_player = nil;
		
		_player = self.crossfadePlayer;
		self.crossfadePlayer = nil;
		
		self.player.delegate = self;
		
		fadingIn = NO;
		fadingOut = NO;
		
	}
	[self playlistChanged];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDPMusicNotificationNowPlayingChanged object:nil];
	
}


#pragma mark - library controls

- (BOOL)libraryLoaded
{
	return self.libraryManager.listsLoaded;
}

- (NSArray*)songs
{
	NSArray *allSongs = [self.libraryManager valueForKeyPath:@"songs.@unionOfArrays.items"];
	return allSongs;
}

- (NSArray*)indexedSongs
{
	return self.libraryManager.songs;
}

- (NSArray*)artists
{
	NSArray *allArtists = [self.libraryManager valueForKeyPath:@"artists.@unionOfArrays.items"];
	return allArtists;
}

- (NSArray*)indexedArtists
{
	return self.libraryManager.artists;
}

- (NSArray*)albums
{
	NSArray *allAlbums = [self.libraryManager valueForKeyPath:@"albums.@unionOfArrays.items"];
	return allAlbums;
}

- (NSArray*)indexedAlbums
{
	return self.libraryManager.albums;
}

@end
