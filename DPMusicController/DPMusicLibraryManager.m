//
//  DPMusicLibraryManager.m
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import "DPMusicLibraryManager.h"
#import <MediaPlayer/MediaPlayer.h>
#import "DPMusicItem.h"
#import "DPMusicItemIndexSection.h"
#import "DPMusicItemSong.h"
#import "DPMusicItemArtist.h"
#import "DPMusicItemAlbum.h"

@interface DPMusicLibraryManager ()
{
	BOOL songsLoaded;
	BOOL artistsLoaded;
	BOOL albumsLoaded;
}

@end

@implementation DPMusicLibraryManager

- (id)init
{
	self = [super init];
	if (self) {
		[self loadLibrary];
	}
	return self;
}

- (void)loadLibrary
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		MPMediaQuery *songsQuery = [MPMediaQuery songsQuery];
		__block NSMutableArray *songsArray = [NSMutableArray arrayWithCapacity:songsQuery.itemSections.count];
		
		for (MPMediaQuerySection *section in songsQuery.itemSections) {
			NSArray *subArray = [songsQuery.items objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:section.range]];
			NSMutableArray *convertedSubArray = [NSMutableArray arrayWithCapacity:subArray.count];
			
			for (MPMediaItem *item in subArray) {
				
				if ([item valueForProperty:MPMediaItemPropertyAssetURL]) {
					DPMusicItemSong *libraryItem = [[DPMusicItemSong alloc] initWithMediaItem:item];
					libraryItem.libraryManager = self;

					[convertedSubArray addObject:libraryItem];
				}
			}
			
			DPMusicItemIndexSection *itemSection = [[DPMusicItemIndexSection alloc] initWithItems:convertedSubArray forIndexTitle:section.title atIndex:songsArray.count];

			[songsArray addObject:itemSection];
		}
		
		
		_songs = [NSArray arrayWithArray:songsArray];

		dispatch_async(dispatch_get_main_queue(), ^{
			songsLoaded = YES;
			[self sectionLoaded];
		});

		MPMediaQuery *artistsQuery = [MPMediaQuery artistsQuery];
		NSMutableArray *artistsArray = [NSMutableArray arrayWithCapacity:artistsQuery.itemSections.count];
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			
			for (MPMediaQuerySection *section in artistsQuery.collectionSections) {
				NSArray *subArray = [artistsQuery.collections objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:section.range]];
				NSMutableArray *convertedSubArray = [NSMutableArray arrayWithCapacity:subArray.count];
				
				for (MPMediaItemCollection *collection in subArray) {
					MPMediaItem *item = [collection representativeItem];

					DPMusicItemArtist *libraryItem = [[DPMusicItemArtist alloc] initWithMediaItem:item];
					libraryItem.libraryManager = self;
						NSArray *artistSongs = [libraryItem songs];
					
						if (artistSongs && artistSongs.count > 0) { // && !showUnplayableSongs)
						[convertedSubArray addObject:libraryItem];
					}
				}
				
				DPMusicItemIndexSection *itemSection = [[DPMusicItemIndexSection alloc] initWithItems:convertedSubArray forIndexTitle:section.title atIndex:artistsArray.count];
				
				
				if (itemSection.items && itemSection.items.count > 0)
					[artistsArray addObject:itemSection];
			}
			
			
			_artists = [NSArray arrayWithArray:artistsArray];
			dispatch_async(dispatch_get_main_queue(), ^{
				artistsLoaded = YES;
				[self sectionLoaded];
			});

		});
				
		MPMediaQuery *albumsQuery = [MPMediaQuery albumsQuery];
		NSMutableArray *albumsArray = [NSMutableArray arrayWithCapacity:albumsQuery.itemSections.count];
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			for (MPMediaQuerySection *section in albumsQuery.collectionSections) {
				NSArray *subArray = [albumsQuery.collections objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:section.range]];
				NSMutableArray *convertedSubArray = [NSMutableArray arrayWithCapacity:subArray.count];
				
				for (MPMediaItemCollection *collection in subArray) {
					MPMediaItem *item = [collection representativeItem];
					DPMusicItemAlbum *libraryItem = [[DPMusicItemAlbum alloc] initWithMediaItem:item];
					libraryItem.libraryManager = self; 
					NSArray *albumSongs = libraryItem.songs;
					
					if (albumSongs && albumSongs.count > 0) { // && !showUnplayableSongs)
						[convertedSubArray addObject:libraryItem];
						}
				}
				
				DPMusicItemIndexSection *itemSection = [[DPMusicItemIndexSection alloc] initWithItems:convertedSubArray forIndexTitle:section.title atIndex:albumsArray.count];
				
				if (itemSection.items && itemSection.items.count > 0)
					[albumsArray addObject:itemSection];
			}
			
			
			_albums = [NSArray arrayWithArray:albumsArray];
			dispatch_async(dispatch_get_main_queue(), ^{
				albumsLoaded = YES;
				[self sectionLoaded];
			});
		});
		
		
	});
}

- (void)sectionLoaded
{
	if (artistsLoaded && albumsLoaded && songsLoaded) {
		_listsLoaded = YES;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDPMusicNotificationLibraryLoaded object:nil];
		DLog(@"lists loaded");
	}
}


- (DPMusicItemArtist*)artistForPersistentID:(NSNumber*)persistentID
{
	DPMusicItemArtist *artist;
	NSPredicate *pred = [NSPredicate predicateWithFormat:@"persistentID == %@", persistentID];
	NSArray *allArtists = [self valueForKeyPath:@"artists.@unionOfArrays.items"];
	NSArray *filtered = [allArtists filteredArrayUsingPredicate:pred];
	
	if (filtered && filtered.count > 0) {
		artist = filtered[0];
	}
	return artist;
}
- (DPMusicItemAlbum*)albumForPersistentID:(NSNumber*)persistentID
{
	DPMusicItemAlbum *album;
	NSPredicate *pred = [NSPredicate predicateWithFormat:@"persistentID == %@", persistentID];
	NSArray *allAlbums = [self valueForKeyPath:@"albums.@unionOfArrays.items"];
	NSArray *filtered = [allAlbums filteredArrayUsingPredicate:pred];
	
	if (filtered && filtered.count > 0)
		album = filtered[0];
	
	return album;
}
- (DPMusicItemSong*)songForPersistentID:(NSNumber*)persistentID
{
	
}

@end
