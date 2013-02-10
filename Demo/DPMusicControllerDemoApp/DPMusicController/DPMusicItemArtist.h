//
//  DPMusicItemArtist.h
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import "DPMusicItem.h"

@interface DPMusicItemArtist : DPMusicItemCollection

@property (nonatomic, strong, readonly) NSString *name;

@property (nonatomic, readonly) NSArray *albums;

@end
