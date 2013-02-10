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

- (void)loadLibrary;


- (DPMusicItemArtist*)artistForPersistentID:(NSNumber*)persistentID;
- (DPMusicItemAlbum*)albumForPersistentID:(NSNumber*)persistentID;
- (DPMusicItemSong*)songForPersistentID:(NSNumber*)persistentID;

@end
