//
//  DPMusicLibraryManager.h
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DPMusicConstants.h"
@class DPMusicItem;
@class DPMusicItemArtist;
@class DPMusicItemSong;
@class DPMusicItemAlbum;
@interface DPMusicLibraryManager : NSObject

@property (nonatomic, readonly) BOOL listsLoaded;

// arrays of DPMusicItemIndexSections
@property (nonatomic, strong, readonly) NSArray *songs;
@property (nonatomic, strong, readonly) NSArray *artists;
@property (nonatomic, strong, readonly) NSArray *albums;

@property (nonatomic) BOOL includeUnplayable; // set to YES to include songs that cannot be played with DPMusicPlayer (either because they're protected or stored in the cloud, etc.)
- (void)loadLibrary;


- (DPMusicItemArtist*)artistForPersistentID:(NSNumber*)persistentID;
- (DPMusicItemAlbum*)albumForPersistentID:(NSNumber*)persistentID;

@end
