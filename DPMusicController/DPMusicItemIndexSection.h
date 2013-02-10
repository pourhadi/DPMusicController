//
//  DPMusicItemIndexSection.h
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/9/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DPMusicItemIndexSection : NSObject

- (id)initWithItems:(NSArray*)items forIndexTitle:(NSString*)indexTitle atIndex:(NSInteger)index;

@property (nonatomic, strong, readonly) NSString *indexTitle;
@property (nonatomic, strong, readonly) NSArray *items;
@property (nonatomic, readonly) NSInteger sectionIndex;
@end
