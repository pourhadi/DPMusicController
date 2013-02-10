//
//  DPMusicItemArtist.m
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import "DPMusicItemArtist.h"
#import "DPMusicItemAlbum.h"
#import "DPMusicLibraryManager.h"
@interface DPMusicItemArtist ()

@end
@implementation DPMusicItemArtist
@synthesize persistentID=_persistentID, associatedItem=_associatedItem, albums=_albums, songs=_songs;

- (id)initWithMediaItem:(MPMediaItem *)item
{
	self = [super initWithMediaItem:item];
	if (self) {
		_name = [item valueForProperty:MPMediaItemPropertyArtist];
		_persistentID = [item valueForProperty:MPMediaItemPropertyArtistPersistentID];
		_associatedItem = item;
	}
	
	return self;
}

- (NSString*)generalTitle
{
	return self.name;
}

- (NSString*)generalSubtitle
{
	return nil;
}

- (UIImage*)getRepresentativeImageForSize:(CGSize)size
{
	UIImage *image;
	MPMediaItemArtwork *art = [self.associatedItem valueForKey:MPMediaItemPropertyArtwork];
	
	if (!art) {
		if (self.albums && self.albums.count > 0) {
			image = [self.albums[0] getRepresentativeImageForSize:size];
		}
	} else {
		image = [art imageWithSize:size];
	}
	
	return image;
}

- (NSArray*)albums
{
	if (!_albums) {
		if (self.libraryManager) {
			NSPredicate *pred = [NSPredicate predicateWithFormat:@"artistPersistentID == %@", self.persistentID];
			
			NSArray *allAlbums = [self.libraryManager valueForKeyPath:@"albums.@unionOfArrays.items"];
			
			_albums = [allAlbums filteredArrayUsingPredicate:pred];
		}
	}
	
	return _albums;
}

- (NSArray*)songs
{
	if (!_songs) {
		if (self.libraryManager) {
			NSPredicate *pred = [NSPredicate predicateWithFormat:@"artistPersistentID == %@", self.persistentID];
			
			NSArray *allSongs = [self.libraryManager valueForKeyPath:@"songs.@unionOfArrays.items"];
			
			_songs = [allSongs filteredArrayUsingPredicate:pred];
		}
	}
	
	return _songs;
}
@end
