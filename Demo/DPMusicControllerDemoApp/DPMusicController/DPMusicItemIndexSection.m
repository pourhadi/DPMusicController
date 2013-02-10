//
//  DPMusicItemIndexSection.m
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import "DPMusicItemIndexSection.h"

@implementation DPMusicItemIndexSection

- (id)initWithItems:(NSArray*)items forIndexTitle:(NSString*)indexTitle atIndex:(NSInteger)index
{
	self = [super init];
	if (self) {
		_items = items;
		_indexTitle = indexTitle;
		_sectionIndex = index;
	}
	return self;
}
@end
