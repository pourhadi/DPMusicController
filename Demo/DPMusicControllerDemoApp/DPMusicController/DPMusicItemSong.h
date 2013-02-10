//
//  DPMusicItemSong.h
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import "DPMusicItem.h"

@class DPMusicItemArtist;
@class DPMusicItemAlbum;

@interface DPMusicItemSong : DPMusicItem

@property (nonatomic, strong, readonly) NSString *title;

@property (nonatomic, readonly) DPMusicItemArtist *artist; // may be nil
@property (nonatomic, readonly) NSString *artistName;	// may be nil if no associated artist
@property (nonatomic, readonly) NSNumber *artistPersistentID;

@property (nonatomic, readonly) DPMusicItemAlbum *album; // may be nil
@property (nonatomic, readonly) NSString *albumTitle;	// may be nil if no associated album
@property (nonatomic, readonly) NSNumber *albumPersistentID;

@property (nonatomic, strong, readonly) NSURL *url; // MPMediaItemAssetURL

@property (nonatomic, readonly) NSTimeInterval duration; // duration if song, otherwise 0

- (id)valueForMediaItemProperty:(NSString*)property; // parameter is MPMediaItem property key

@end
