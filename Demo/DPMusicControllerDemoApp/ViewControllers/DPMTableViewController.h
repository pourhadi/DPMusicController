//
//  DPMTableViewController.h
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/10/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DPMusicController.h"

typedef NS_ENUM(NSUInteger, DPMTableViewControllerContentType) {
	DPMTableViewControllerContentTypeSongs,
	DPMTableViewControllerContentTypeArtists,
	DPMTableViewControllerContentTypeAlbums,
	DPMTableViewControllerContentTypeDrillDown,
	DPMTableViewControllerContentTypeQueue,
};

@interface DPMTableViewController : UITableViewController

@property (nonatomic) DPMTableViewControllerContentType tableContentType;

@property (nonatomic, strong) NSString *tableTitle;

@property (nonatomic, strong) NSArray *items;

@end
