//
//  DPMusicItemArtist.m
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//
#import "DPMusicItemAlbum.h"
#import "DPMusicItemArtist.h"
#import "DPMusicLibraryManager.h"
@interface DPMusicItemAlbum ()


@end


@implementation DPMusicItemAlbum
@synthesize persistentID=_persistentID, associatedItem=_associatedItem, artist=_artist, songs=_songs;

- (id)initWithMediaItem:(MPMediaItem *)item
{
	self = [super initWithMediaItem:item];
	if (self) {

		_title = [item valueForProperty:MPMediaItemPropertyAlbumTitle];
		_artistPersistentID = [item valueForProperty:MPMediaItemPropertyArtistPersistentID];
		_persistentID = [item valueForProperty:MPMediaItemPropertyAlbumPersistentID];
		_associatedItem = item;
	}
	
	return self;
}

- (NSString*)generalTitle
{
	return self.title;
}

- (NSString*)generalSubtitle
{
	return self.artist.name;
}

- (UIImage*)getRepresentativeImageForSize:(CGSize)size
{
	UIImage *image;
	MPMediaItemArtwork *art = [self.associatedItem valueForKey:MPMediaItemPropertyArtwork];
	
	image = [art imageWithSize:size];
	
	return image;
}

- (DPMusicItemArtist*)artist
{
	if (!_artist) {
		if (self.libraryManager) {
			_artist = [self.libraryManager artistForPersistentID:self.artistPersistentID];

		}
	}
	
	return _artist;
}

- (NSArray*)songs
{
	if (!_songs) {
		if (self.libraryManager) {
			NSPredicate *pred = [NSPredicate predicateWithFormat:@"albumPersistentID == %@", self.persistentID];
			
			NSArray *allSongs = [self.libraryManager valueForKeyPath:@"songs.@unionOfArrays.items"];
			
			_songs = [allSongs filteredArrayUsingPredicate:pred];
		}
	}
	
	return _songs;
}
@end
