//
//  DPMusicItem.h
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@class DPMusicLibraryManager;
@interface DPMusicItem : NSObject

- (id)initWithMediaItem:(MPMediaItem*)item;

- (NSString*)generalTitle;		// override point - general title for the item (i.e. for songs, song title. for artists, artist name. for albums, album title. should not return nil.
- (NSString*)generalSubtitle;	// override point - general subtitle for the item (i.e. for songs, it may be something like "[Album Title] - [Artist Name]". may return nil.


@property (nonatomic, weak) DPMusicLibraryManager *libraryManager;

@property (nonatomic, strong, readonly) NSNumber *persistentID;

@property (nonatomic, strong, readonly) MPMediaItem *associatedItem;

- (UIImage*)getRepresentativeImageForSize:(CGSize)size;

- (BOOL)equals:(id)otherObj;

@end


@interface DPMusicItemCollection : DPMusicItem

@property (nonatomic, strong, readonly) NSArray *songs;

@end