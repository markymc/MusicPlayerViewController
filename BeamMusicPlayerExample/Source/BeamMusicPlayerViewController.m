//
//  BeamMusicPlayerViewController.m
//  Part of MusicPlayerViewController
//
//  Created by Moritz Haarmann on 30.05.12.
//  Copyright (c) 2012 BeamApp UG. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// 
// Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
// 
// Neither the name of the project's author nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "BeamMusicPlayerViewController.h"
#import "UIImageView+Reflection.h"
#import "NSDateFormatter+Duration.h"

@interface BeamMusicPlayerViewController()

@property (nonatomic,weak) IBOutlet UISlider* volumeSlider; // Volume Slider
@property (nonatomic,weak) IBOutlet UISlider* progressSlider; // Progress Slider buried in the Progress View

@property (nonatomic,weak) IBOutlet UILabel* trackTitleLabel; // The Title Label
@property (nonatomic,weak) IBOutlet UILabel* albumTitleLabel; // Album Label
@property (nonatomic,weak) IBOutlet UILabel* artistNameLabel; // Artist Name Label

@property (nonatomic,weak) IBOutlet UIToolbar* controlsToolbar; // Encapsulates the Play, Forward, Rewind buttons


@property (nonatomic,weak) IBOutlet UIBarButtonItem* rewindButton; // Previous Track
@property (nonatomic,weak) IBOutlet UIBarButtonItem* fastForwardButton; // Next Track
@property (nonatomic,weak) IBOutlet UIBarButtonItem* playButton; // Play

@property (nonatomic,weak) IBOutlet UIImageView* albumArtImageView; // Album Art Image View
@property (nonatomic,weak) IBOutlet UIImageView* albumArtReflection; // It's reflection

@property (nonatomic,strong) NSTimer* playbackTickTimer; // Ticks each seconds when playing.

@property (nonatomic,strong) NSDateFormatter* durationFormatter; // Formatter used for the elapsed / remaining time.
@property (nonatomic,strong) UITapGestureRecognizer* coverArtGestureRecognizer; // Tap Recognizer used to dim in / out the scrobble overlay.

@property (nonatomic,weak) IBOutlet UIView* scrobbleOverlay; // Overlay that serves as a container for all components visible only in scrobble-mode
@property (nonatomic,weak) IBOutlet UILabel* timeElapsedLabel; // Elapsed Time Label
@property (nonatomic,weak) IBOutlet UILabel* timeRemainingLabel; // Remaining Time Label
@property (nonatomic,weak) IBOutlet UIButton* shuffleButton; // Shuffle Button
@property (nonatomic,weak) IBOutlet UIButton* repeatButton; // Repeat button

@property (nonatomic) CGFloat currentTrackLength;
@property (nonatomic) NSUInteger numberOfTracks;

@end

@implementation BeamMusicPlayerViewController

@synthesize trackTitleLabel;
@synthesize albumTitleLabel;
@synthesize artistNameLabel;
@synthesize rewindButton;
@synthesize fastForwardButton;
@synthesize playButton;
@synthesize volumeSlider;
@synthesize progressSlider;
@synthesize controlsToolbar;
@synthesize albumArtImageView;
@synthesize albumArtReflection;
@synthesize delegate;
@synthesize dataSource;
@synthesize currentTrack;
@synthesize currentPlaybackPosition;
@synthesize playbackTickTimer;
@synthesize playing;
@synthesize scrobbleOverlay;
@synthesize timeElapsedLabel;
@synthesize timeRemainingLabel;
@synthesize shuffleButton;
@synthesize repeatButton;
@synthesize durationFormatter;
@synthesize coverArtGestureRecognizer;
@synthesize currentTrackLength;
@synthesize numberOfTracks;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Scrobble Ovelray alpha should be 0, initialize the gesture recognizer
    self.scrobbleOverlay.alpha = 0;
    self.coverArtGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(coverArtTapped:)];
    [self.albumArtImageView addGestureRecognizer:self.coverArtGestureRecognizer];
    
    // Knobs for the sliders
    
    UIImage* sliderBlueTrack = [[UIImage imageNamed:@"VolumeBlueTrack.png"] stretchableImageWithLeftCapWidth:5.0 topCapHeight:0];
    UIImage* slideWhiteTrack = [[UIImage imageNamed:@"VolumeWhiteTrack.png"] stretchableImageWithLeftCapWidth:5.0 topCapHeight:0];
    UIImage* knob = [UIImage imageNamed:@"VolumeKnob"];
    knob = [UIImage imageWithCGImage:knob.CGImage scale:2.0 orientation:UIImageOrientationUp];
    [[UISlider appearanceWhenContainedIn:[self class], nil] setThumbImage:knob forState:UIControlStateNormal];
    
   // [[UISlider appearanceWhenContainedIn:[self class], nil] setMinimumValueImage:[UIImage imageNamed:@"VolumeBlueMusicCap.png"]];
   // [[UISlider appearanceWhenContainedIn:[self class], nil] setMaximumValueImage:[UIImage imageNamed:@"VolumeWhiteMusicCap.png"]];
    [[UISlider appearance] setMinimumTrackImage:sliderBlueTrack forState:UIControlStateNormal];
    [[UISlider appearance] setMaximumTrackImage:slideWhiteTrack forState:UIControlStateNormal];

    // The Original Toolbar is 48px high in the iPod/Music app
    
    CGRect toolbarRect = self.controlsToolbar.frame;
    toolbarRect.size.height = 48;
    self.controlsToolbar.frame = toolbarRect;
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.coverArtGestureRecognizer = nil;
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}


#pragma mark - Playback Management

/**
 * Updates the UI to match the current track by requesting the information from the datasource.
 */
-(void)updateUIForCurrentTrack {
    
    self.artistNameLabel.text = [self.dataSource musicPlayer:self artistForTrack:self.currentTrack];
    self.trackTitleLabel.text = [self.dataSource musicPlayer:self titleForTrack:self.currentTrack];
    self.albumTitleLabel.text = [self.dataSource musicPlayer:self albumForTrack:self.currentTrack];
    
    // We only request the coverart if the delegate responds to it.
    if (self.dataSource && [self.dataSource respondsToSelector:@selector(musicPlayer:artworkForTrack:receivingBlock:)]) {
        
        // Copy the current track to another variable, otherwise we would just access the current one.
        NSUInteger track = self.currentTrack;
        
        // Placeholder as long as we are loading
        self.albumArtImageView.image = [UIImage imageNamed:@"noartplaceholder.png"];
        self.albumArtReflection.image = [self.albumArtImageView reflectedImageWithHeight:self.albumArtReflection.frame.size.height];
        
        // Request the image. 
        [self.dataSource musicPlayer:self artworkForTrack:self.currentTrack receivingBlock:^(UIImage *image, NSError *__autoreleasing *error) {
            if ( track == self.currentTrack ){
            
                // If there is no image given, use the placeholder
                if ( image  != nil ){
                    dispatch_async(dispatch_get_main_queue(), ^{
                    self.albumArtImageView.image = image;
                    self.albumArtReflection.image = [self.albumArtImageView reflectedImageWithHeight:self.albumArtReflection.frame.size.height];
                });
            }
            
            } else {
                NSLog(@"Discarded Response, Invalid for this cycle.");
            }
        }];
        
    } else {
        // Otherwise, we'll stick with the placeholder.
        self.albumArtImageView.image = [UIImage imageNamed:@"noartplaceholder.png"];
        self.albumArtReflection.image = [self.albumArtImageView reflectedImageWithHeight:self.albumArtReflection.frame.size.height];
    }
}

/**
 * Prepares the player for track 0.
 */
-(void)preparePlayer {
    self.currentTrack = 0;
    [self updateUIForCurrentTrack];
}


-(void)play {
    if ( !self.playing ){
        self->playing = YES;
        self->currentPlaybackPosition = 0;
        
        [self updateUIForCurrentTrack];
        
        
        self.currentTrackLength = [self.dataSource musicPlayer:self lengthForTrack:self.currentTrack];
        self.numberOfTracks = [self.dataSource numberOfTracksInPlayer:self];
        
        // Slider
        self.progressSlider.maximumValue = self.currentTrackLength;
        self.progressSlider.minimumValue = 0;
        
        self.playbackTickTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(playbackTick:) userInfo:nil repeats:YES];
        
        if ( self.delegate && [self.delegate respondsToSelector:@selector(playerDidStartPlaying:)] ){
            [self.delegate musicPlayerDidStartPlaying:self];
        }
        
    }
}

-(void)pause {
    if ( self.playing ){
        self->playing = NO;
        [self.playbackTickTimer invalidate];
        self.playbackTickTimer = nil;
        
        if ( self.delegate && [self.delegate respondsToSelector:@selector(playerDidStopPlaying:)] ){
            [self.delegate musicPlayerDidStopPlaying:self];
        }
    }
}

-(void)next {
    [self changeTrack:self->currentTrack+1];
}

-(void)previous {
    [self changeTrack:self->currentTrack-1];
}

/*
 * Changes the track to the new track given. 
 */
-(void)changeTrack:(NSUInteger)newTrack {
    BOOL shouldChange = YES;
    if ( self.delegate && [self.delegate respondsToSelector:@selector(musicPlayer:shoulChangeTrack:) ]){
        shouldChange = [self.delegate musicPlayer:self shouldChangeTrack:newTrack];
    }
    
    if ( shouldChange ){
        [self pause];
        self->currentPlaybackPosition = 0;
        
        self.currentTrack = newTrack;
        if ( self.delegate && [self.delegate respondsToSelector:@selector(musicPlayer:didChangeTrack:) ]){
            [self.delegate musicPlayer:self didChangeTrack:newTrack];
        }
        
        [self play];
    }
}

/**
 * Reloads data from the data source and updates the player. If the player is currently playing, the playback is stopped.
 */
-(void)reloadData {
    
}

/**
 * Tick method called each second when playing back.
 */
-(void)playbackTick:(id)unused {
    self->currentPlaybackPosition += 1.0;
    NSString* elapsed = [NSDateFormatter formattedDuration:(long)self.currentPlaybackPosition];
    NSString* remaining = [NSDateFormatter formattedDuration:(self.currentTrackLength-self.currentPlaybackPosition)*-1];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.timeElapsedLabel.text =elapsed;
        self.timeRemainingLabel.text =remaining;
        self.progressSlider.value = self.currentPlaybackPosition;
    });
    
}

-(void)updateSeekUI {
    
}

#pragma mark - User Interface ACtions

-(IBAction)playAction:(UIBarButtonItem*)sender {
    if ( self.playing ){
        [self pause];
        self.playButton.image = [UIImage imageNamed:@"play.png"];
    } else {
        [self play];
        self.playButton.image = [UIImage imageNamed:@"pause.png"];
    }
}

-(IBAction)nextAction:(id)sender {
    [self next];
}

-(IBAction)previousAction:(id)sender {
    [self previous];
}


/**
 * Called when the cover art is tapped. Either shows or hides the scrobble-ui
 */
-(IBAction)coverArtTapped:(id)sender {
    if ( self.scrobbleOverlay.alpha == 0 ){
        [self.scrobbleOverlay setAlpha:1];
    } else {
        [self.scrobbleOverlay setAlpha:0];
    }
}

-(void)adjustButtonStates {
    
}

@end
