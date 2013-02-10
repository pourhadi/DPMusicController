//
//  DPMusicItem.m
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import "DPMusicItem.h"

@implementation DPMusicItem

- (id)initWithMediaItem:(MPMediaItem *)item
{
	self = [super init];
	if (self) {
		
	}
	
	return self;
}
- (UIImage*)getRepresentativeImageForSize:(CGSize)size
{
	return nil;
}

- (BOOL)equals:(DPMusicItem*)otherObj
{
	return self.persistentID.unsignedLongLongValue == otherObj.persistentID.unsignedLongLongValue;
}

- (NSString*)generalTitle
{
	return nil;
}

- (NSString*)generalSubtitle
{
	return nil;
}

@end


@implementation DPMusicItemCollection



@end
