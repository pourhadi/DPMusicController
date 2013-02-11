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

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		
		MPMediaQuery *songsQuery = [MPMediaQuery songsQuery];
		__block NSMutableArray *songsArray = [NSMutableArray arrayWithCapacity:songsQuery.itemSections.count];
		
		for (MPMediaQuerySection *section in songsQuery.itemSections) {
			NSArray *subArray = [songsQuery.items objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:section.range]];
			NSMutableArray *convertedSubArray = [NSMutableArray arrayWithCapacity:subArray.count];
			
			for (MPMediaItem *item in subArray) {
				
				if ([item valueForProperty:MPMediaItemPropertyAssetURL] || self.includeUnplayable) {
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
                    [convertedSubArray addObject:libraryItem];
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
                    [convertedSubArray addObject:libraryItem];
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
        
        if (!self.includeUnplayable) {
            [self cleanUpUnplayable];
        }
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

- (void)cleanUpUnplayable
{
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
       
        NSMutableArray *newSongArray = [NSMutableArray arrayWithCapacity:weakSelf.songs.count];
        
        for (DPMusicItemIndexSection *section in weakSelf.songs) {
            NSMutableArray *newItems = [NSMutableArray arrayWithCapacity:section.items.count];
            
            for (DPMusicItemSong *song in section.items) {
                if (song.url) {
                    [newItems addObject:song];
                }
            }
            
            if (newItems.count > 0) {
                DPMusicItemIndexSection *newSection = [[DPMusicItemIndexSection alloc] initWithItems:newItems forIndexTitle:section.indexTitle atIndex:section.sectionIndex];
                [newSongArray addObject:newSection];
            }
        }
        
        _songs = newSongArray;
        
        NSMutableArray *newArtistArray = [NSMutableArray arrayWithCapacity:weakSelf.artists.count];
        
        for (DPMusicItemIndexSection *section in weakSelf.artists) {
            
            NSMutableArray *newItems = [NSMutableArray arrayWithCapacity:section.items.count];
            
            for (DPMusicItemArtist *artist in section.items) {
                NSArray *songs = artist.songs;
                
                if (songs && songs.count > 0) {
                    [newItems addObject:artist];
                }
                
            }
            
            if (newItems.count > 0) {
                DPMusicItemIndexSection *newSection = [[DPMusicItemIndexSection alloc] initWithItems:newItems forIndexTitle:section.indexTitle atIndex:section.sectionIndex];
                [newArtistArray addObject:newSection];
            }
            
        }
        
        _artists = newArtistArray;
       
        NSMutableArray *newAlbumArray = [NSMutableArray arrayWithCapacity:weakSelf.albums.count];
        
        for (DPMusicItemIndexSection *section in weakSelf.albums) {
            
            NSMutableArray *newItems = [NSMutableArray arrayWithCapacity:section.items.count];
            
            for (DPMusicItemAlbum *album in section.items) {
                NSArray *songs = album.songs;
                
                if (songs && songs.count > 0) {
                    [newItems addObject:album];
                }
                
            }
            
            if (newItems.count > 0) {
                DPMusicItemIndexSection *newSection = [[DPMusicItemIndexSection alloc] initWithItems:newItems forIndexTitle:section.indexTitle atIndex:section.sectionIndex];
                [newAlbumArray addObject:newSection];
            }
            
        }
        
        _albums = newAlbumArray;
        
        dispatch_async(dispatch_get_main_queue(), ^{
           
            [[NSNotificationCenter defaultCenter] postNotificationName:kDPMusicNotificationLibraryLoaded object:nil];
            
        });

        
    });
}

@end
