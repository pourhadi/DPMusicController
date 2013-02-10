//
//  DPMusicItemSong.m
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import "DPMusicItemSong.h"
#import "DPMusicItemArtist.h"
#import "DPMusicItemAlbum.h"
#import "DPMusicLibraryManager.h"
@interface DPMusicItemSong ()
{
//	DPMusicItemArtist *_artist;
//	DPMusicItemAlbum *_album;
//	NSNumber *_persistentID;
//	MPMediaItem *_associatedItem;
//	NSTimeInterval _duration;
//	NSNumber *_artistPersistentID;
//	NSNumber *_albumPersistentID;

}

@end

@implementation DPMusicItemSong
@synthesize persistentID=_persistentID, associatedItem=_associatedItem, artist=_artist, album=_album, artistPersistentID=_artistPersistentID, albumPersistentID=_albumPersistentID, url=_url;
- (id)initWithMediaItem:(MPMediaItem *)item
{
	self = [super initWithMediaItem:item];
	if (self) {
		_title = [item valueForProperty:MPMediaItemPropertyTitle];

		_artistPersistentID = [item valueForProperty:MPMediaItemPropertyArtistPersistentID];
		_albumPersistentID = [item valueForProperty:MPMediaItemPropertyAlbumPersistentID];
		_persistentID = [item valueForProperty:MPMediaItemPropertyPersistentID];
		_duration = [[item valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
		_url = [item valueForProperty:MPMediaItemPropertyAssetURL];
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
	NSString *detailText = [NSString stringWithFormat:@"%@ - %@", self.albumTitle, self.artistName];
	BOOL showDetail = YES;
	if ([self.albumTitle length] < 1 && ([self.artistName length] > 1))
	{
		showDetail = YES;
		detailText = [NSString stringWithFormat:@"%@", self.artistName];
	}
	else if (([self.artistName length] < 1) && ([self.albumTitle length] > 1))
	{
		detailText = [NSString stringWithFormat:@"%@", self.albumTitle];
		showDetail = YES;
	}
	else if ([self.albumTitle length] <1 && [self.albumTitle length] <1)
	{
		showDetail = NO;
	}

	if (!showDetail) {
		return nil;
	}
	
	return detailText;
}

- (UIImage*)getRepresentativeImageForSize:(CGSize)size
{
	UIImage *image;
	MPMediaItemArtwork *art = [self valueForMediaItemProperty:MPMediaItemPropertyArtwork];
	
	if (!art) {
		if (self.album) {
			image = [self.album getRepresentativeImageForSize:size];
		} else if (self.artist) {
			image = [self.artist getRepresentativeImageForSize:size];
		}
	} else {
		image = [art imageWithSize:size];
	}
	
	return image;
}

- (NSString*)artistName
{
	if (self.artist) {
		return self.artist.name;
	}
	return nil;
}

- (NSString*)albumTitle
{
	if (self.album) {
		return self.album.title;
	}
	
	return nil;
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

- (DPMusicItemAlbum*)album
{
	if (!_album) {
		if (self.libraryManager) {
			_album = [self.libraryManager albumForPersistentID:self.albumPersistentID];
		}
	}
	
	return _album;
}

- (id)valueForMediaItemProperty:(NSString*)property
{
	return [self.associatedItem valueForProperty:property];
}


@end
