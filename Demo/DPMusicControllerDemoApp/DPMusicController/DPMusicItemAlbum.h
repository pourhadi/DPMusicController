//
//  DPMusicItemAlbum.h
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import "DPMusicItem.h"

@class DPMusicItemArtist;
@interface DPMusicItemAlbum : DPMusicItemCollection

@property (nonatomic, strong, readonly) NSString *title;

@property (nonatomic, readonly) DPMusicItemArtist *artist;
@property (nonatomic, readonly) NSNumber *artistPersistentID;
@end
