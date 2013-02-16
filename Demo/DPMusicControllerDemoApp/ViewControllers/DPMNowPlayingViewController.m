//
//  DPMNowPlayingViewController.m
//  DPMusicControllerDemoApp
//
//  Created by Dan Pourhadi on 2/10/13.
//  Copyright (c) 2013 Dan Pourhadi. All rights reserved.
//

#import "DPMNowPlayingViewController.h"
#import "DPMusicController.h"
@interface DPMNowPlayingViewController ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *artistLabel;
@property (nonatomic, weak) IBOutlet UILabel *albumLabel;

@property (nonatomic, weak) IBOutlet UIButton *playButton;
@property (nonatomic, weak) IBOutlet UIButton *backbutton;
@property (nonatomic, weak) IBOutlet UIButton *nextButton;

@property (nonatomic, weak) IBOutlet UIImageView *artworkImageView;

@property (nonatomic, weak) IBOutlet UISlider *scrubSlider;
@property (nonatomic, weak) IBOutlet UILabel *remainingLabel;
@property (nonatomic, weak) IBOutlet UILabel *elapsedLabel;

- (IBAction)buttonHit:(id)sender;
@end

@implementation DPMNowPlayingViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[[DPMusicController sharedController] addObserver:self forKeyPath:@"trackPosition" options:0 context:nil];
	[[DPMusicController sharedController] enableScrubbingFromSlider:self.scrubSlider];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateInterface) name:kDPMusicNotificationPlaylistChanged object:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self updatePlayingTime];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self updateInterface];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateInterface
{
	DPMusicItemSong *currentSong = [[DPMusicController sharedController] currentSong];
	
	self.titleLabel.text = currentSong.title;
	self.albumLabel.text = currentSong.albumTitle;
	self.artistLabel.text = currentSong.artistName;
	
	self.artworkImageView.image = [currentSong getRepresentativeImageForSize:self.artworkImageView.frame.size];
}

- (void)updatePlayingTime
{
	self.remainingLabel.text = [[DPMusicController sharedController] remainingTimeString];
	self.elapsedLabel.text = [[DPMusicController sharedController] elapsedTimeString];
	self.scrubSlider.value = [[DPMusicController sharedController] trackPosition] / [[DPMusicController sharedController] duration];
}

- (IBAction)buttonHit:(id)sender
{
	if (sender == self.playButton) {
		
		if ([[DPMusicController sharedController] isPlaying]) {
			[[DPMusicController sharedController] pause:nil];
		} else {
			[[DPMusicController sharedController] play:nil];
		}
		
	} else if (sender == self.backbutton) {
		
		[[DPMusicController sharedController] previousWithCrossfade:YES error:nil];
		
	} else if (sender == self.nextButton) {
		[[DPMusicController sharedController] nextWithCrossfade:YES error:nil];
		
	}
}

@end
