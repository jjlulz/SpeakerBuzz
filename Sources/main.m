
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <math.h>
#import <stdatomic.h>

static _Atomic float gFrequency = 80.0f;
static _Atomic float gVolume = 0.15f;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@interface BuzzViewController : UIViewController
@property (strong, nonatomic) AVAudioEngine *engine;
@property (strong, nonatomic) UIButton *toggleButton;
@property (strong, nonatomic) UILabel *frequencyLabel;
@property (strong, nonatomic) UILabel *volumeLabel;
@property (strong, nonatomic) UISlider *frequencySlider;
@property (strong, nonatomic) UISlider *volumeSlider;
@property (assign, nonatomic) BOOL buzzing;
@end

@implementation BuzzViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1.0];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"SpeakerBuzz";
    title.font = [UIFont boldSystemFontOfSize:32];
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;

    [self addView:title top:90 height:45];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = @"Speaker Pulse Generator";
    subtitle.textColor = UIColor.lightGrayColor;
    subtitle.textAlignment = NSTextAlignmentCenter;
    [self addView:subtitle top:140 height:30];

    self.toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.toggleButton.frame = CGRectMake(40, 220,
                                         self.view.bounds.size.width - 80, 65);
    self.toggleButton.autoresizingMask =
        UIViewAutoresizingFlexibleWidth;
    self.toggleButton.backgroundColor =
        [UIColor colorWithRed:0.1 green:0.55 blue:0.9 alpha:1];
    self.toggleButton.layer.cornerRadius = 14;
    [self.toggleButton setTitle:@"START BUZZING"
                       forState:UIControlStateNormal];
    [self.toggleButton setTitleColor:UIColor.whiteColor
                            forState:UIControlStateNormal];
    self.toggleButton.titleLabel.font =
        [UIFont boldSystemFontOfSize:18];
    [self.toggleButton addTarget:self
                          action:@selector(toggleBuzz)
                forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.toggleButton];

    self.frequencyLabel = [self makeLabel:@"Frequency: 80 Hz" top:330];
    self.frequencySlider = [self makeSlider:330
                                      min:40 max:180
                                   action:@selector(frequencyChanged:)];

    self.volumeLabel = [self makeLabel:@"Volume: 15%" top:430];
    self.volumeSlider = [self makeSlider:430
                                   min:0.01 max:0.25
                                action:@selector(volumeChanged:)];

    UILabel *warning = [[UILabel alloc] init];
    warning.text = @"Low-frequency audio may be audible.\nStart at low volume.";
    warning.textColor = UIColor.grayColor;
    warning.textAlignment = NSTextAlignmentCenter;
    warning.numberOfLines = 2;
    warning.font = [UIFont systemFontOfSize:12];
    [self addView:warning top:540 height:45];
}

- (void)addView:(UIView *)view top:(CGFloat)top height:(CGFloat)height {
    view.frame = CGRectMake(20, top, self.view.bounds.size.width - 40, height);
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:view];
}

- (UILabel *)makeLabel:(NSString *)text top:(CGFloat)top {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.textColor = UIColor.whiteColor;
    [self addView:label top:top height:30];
    return label;
}

- (UISlider *)makeSlider:(CGFloat)top
                     min:(float)min
                     max:(float)max
                  action:(SEL)action {
    UISlider *slider = [[UISlider alloc] init];
    slider.minimumValue = min;
    slider.maximumValue = max;
    slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    slider.frame = CGRectMake(20, top + 35,
                              self.view.bounds.size.width - 40, 35);
    [slider addTarget:self action:action
     forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:slider];
    return slider;
}

- (void)frequencyChanged:(UISlider *)slider {
    float value = slider.value;
    atomic_store(&gFrequency, value);
    self.frequencyLabel.text =
        [NSString stringWithFormat:@"Frequency: %.0f Hz", value];
}

- (void)volumeChanged:(UISlider *)slider {
    float value = slider.value;
    atomic_store(&gVolume, value);
    self.volumeLabel.text =
        [NSString stringWithFormat:@"Volume: %.0f%%", value * 100];
}

- (void)toggleBuzz {
    if (self.buzzing) {
        [self stopBuzz];
    } else {
        [self startBuzz];
    }
}

- (void)startBuzz {
    AVAudioSession *session = AVAudioSession.sharedInstance;

    NSError *error = nil;

    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:0
                   error:&error];

    if (![session setActive:YES error:&error]) {
        NSLog(@"SpeakerBuzz audio session error: %@", error);
        return;
    }

    [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                               error:nil];

    self.engine = [[AVAudioEngine alloc] init];

    AVAudioFormat *format =
        [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100
                                                       channels:1];

    __block double phase = 0.0;

    AVAudioSourceNode *source =
    [[AVAudioSourceNode alloc]
     initWithFormat:format
     renderBlock:^OSStatus(BOOL *isSilence,
                           const AudioTimeStamp *timestamp,
                           AVAudioFrameCount frameCount,
                           AudioBufferList *outputData) {

        float *samples = (float *)outputData->mBuffers[0].mData;

        float frequency = atomic_load(&gFrequency);
        float volume = atomic_load(&gVolume);

        double increment = 2.0 * M_PI * frequency / 44100.0;

        for (AVAudioFrameCount i = 0; i < frameCount; i++) {
            samples[i] = volume * sin(phase);
            phase += increment;

            if (phase >= 2.0 * M_PI) {
                phase -= 2.0 * M_PI;
            }
        }

        *isSilence = NO;
        return noErr;
    }];

    [self.engine attachNode:source];

    [self.engine connect:source
                      to:self.engine.mainMixerNode
                  format:format];

    if (![self.engine startAndReturnError:&error]) {
        NSLog(@"SpeakerBuzz engine error: %@", error);
        self.engine = nil;
        [session setActive:NO error:nil];
        return;
    }

    self.buzzing = YES;
    [self.toggleButton setTitle:@"STOP BUZZING"
                       forState:UIControlStateNormal];
}

- (void)stopBuzz {
    [self.engine stop];
    self.engine = nil;

    [[AVAudioSession sharedInstance]
     setActive:NO
     withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
     error:nil];

    self.buzzing = NO;

    [self.toggleButton setTitle:@"START BUZZING"
                       forState:UIControlStateNormal];
}

- (void)dealloc {
    if (self.buzzing) {
        [self.engine stop];
    }
}

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)options {

    self.window = [[UIWindow alloc]
                   initWithFrame:UIScreen.mainScreen.bounds];

    self.window.rootViewController =
        [[BuzzViewController alloc] init];

    [self.window makeKeyAndVisible];

    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass([AppDelegate class]));
    }
}
