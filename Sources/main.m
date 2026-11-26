
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <math.h>
#import <stdatomic.h>

static _Atomic float gFrequency = 80.0f;
static _Atomic float gVolume = 0.15f;

static double gPhase = 0.0;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@interface BuzzViewController : UIViewController

@property (strong, nonatomic) UIButton *toggleButton;
@property (strong, nonatomic) UILabel *frequencyLabel;
@property (strong, nonatomic) UILabel *volumeLabel;
@property (strong, nonatomic) UISlider *frequencySlider;
@property (strong, nonatomic) UISlider *volumeSlider;

@property (assign, nonatomic) BOOL buzzing;
@property (assign, nonatomic) AudioComponentInstance audioUnit;

@end

static OSStatus AudioRenderCallback(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData
) {
    float frequency = atomic_load(&gFrequency);
    float volume = atomic_load(&gVolume);

    double increment = 2.0 * M_PI * frequency / 44100.0;

    for (UInt32 buffer = 0; buffer < ioData->mNumberBuffers; buffer++) {
        float *samples = (float *)ioData->mBuffers[buffer].mData;

        UInt32 channels = ioData->mBuffers[buffer].mNumberChannels;

        for (UInt32 i = 0; i < inNumberFrames; i++) {
            float sample = volume * (float)sin(gPhase);

            for (UInt32 channel = 0; channel < channels; channel++) {
                samples[i * channels + channel] = sample;
            }

            gPhase += increment;

            if (gPhase >= 2.0 * M_PI) {
                gPhase -= 2.0 * M_PI;
            }
        }
    }

    return noErr;
}

@implementation BuzzViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor colorWithWhite:0.07 alpha:1.0];

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

    self.toggleButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    self.toggleButton.frame = CGRectMake(
        40, 220,
        self.view.bounds.size.width - 80,
        65
    );

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

    self.frequencyLabel =
        [self makeLabel:@"Frequency: 80 Hz" top:330];

    self.frequencySlider = [self makeSlider:330
                                        min:40
                                        max:180
                                     action:@selector(frequencyChanged:)];

    self.volumeLabel =
        [self makeLabel:@"Volume: 15%" top:430];

    self.volumeSlider = [self makeSlider:430
                                     min:0.01
                                     max:0.25
                                  action:@selector(volumeChanged:)];

    UILabel *warning = [[UILabel alloc] init];

    warning.text =
        @"Low-frequency audio may be audible.\nStart at low volume.";

    warning.textColor = UIColor.grayColor;
    warning.textAlignment = NSTextAlignmentCenter;
    warning.numberOfLines = 2;
    warning.font = [UIFont systemFontOfSize:12];

    [self addView:warning top:540 height:45];
}

- (void)addView:(UIView *)view
            top:(CGFloat)top
         height:(CGFloat)height {

    view.frame = CGRectMake(
        20, top,
        self.view.bounds.size.width - 40,
        height
    );

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

    slider.frame = CGRectMake(
        20, top + 35,
        self.view.bounds.size.width - 40,
        35
    );

    [slider addTarget:self
               action:action
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

    NSError *error = nil;

    AVAudioSession *session =
        [AVAudioSession sharedInstance];

    if (![session setCategory:AVAudioSessionCategoryPlayback
                         error:&error]) {

        NSLog(@"SpeakerBuzz session category error: %@", error);
        return;
    }

    if (![session setActive:YES error:&error]) {

        NSLog(@"SpeakerBuzz session activation error: %@", error);
        return;
    }

    [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                               error:nil];

    AudioComponentDescription description;

    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_RemoteIO;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    description.componentFlags = 0;
    description.componentFlagsMask = 0;

    AudioComponent component =
        AudioComponentFindNext(NULL, &description);

    if (!component) {
        NSLog(@"SpeakerBuzz: RemoteIO unavailable");
        [session setActive:NO error:nil];
        return;
    }

    OSStatus status =
        AudioComponentInstanceNew(component, &_audioUnit);

    if (status != noErr) {
        NSLog(@"SpeakerBuzz: AudioUnit creation failed: %d", (int)status);
        [session setActive:NO error:nil];
        return;
    }

    AudioStreamBasicDescription format;

    memset(&format, 0, sizeof(format));

    format.mSampleRate = 44100.0;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags =
        kAudioFormatFlagIsFloat |
        kAudioFormatFlagIsPacked;

    format.mBytesPerPacket = sizeof(float) * 2;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = sizeof(float) * 2;
    format.mChannelsPerFrame = 2;
    format.mBitsPerChannel = 32;

    UInt32 formatSize = sizeof(format);

    status = AudioUnitSetProperty(
        _audioUnit,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input,
        0,
        &format,
        formatSize
    );

    if (status != noErr) {
        NSLog(@"SpeakerBuzz: Audio format error: %d", (int)status);
        AudioComponentInstanceDispose(_audioUnit);
        _audioUnit = NULL;
        [session setActive:NO error:nil];
        return;
    }

    AURenderCallbackStruct callback;

    callback.inputProc = AudioRenderCallback;
    callback.inputProcRefCon = NULL;

    status = AudioUnitSetProperty(
        _audioUnit,
        kAudioUnitProperty_SetRenderCallback,
        kAudioUnitScope_Input,
        0,
        &callback,
        sizeof(callback)
    );

    if (status != noErr) {
        NSLog(@"SpeakerBuzz: Callback setup error: %d", (int)status);
        AudioComponentInstanceDispose(_audioUnit);
        _audioUnit = NULL;
        [session setActive:NO error:nil];
        return;
    }

    status = AudioUnitInitialize(_audioUnit);

    if (status != noErr) {
        NSLog(@"SpeakerBuzz: Initialization error: %d", (int)status);
        AudioComponentInstanceDispose(_audioUnit);
        _audioUnit = NULL;
        [session setActive:NO error:nil];
        return;
    }

    gPhase = 0.0;

    status = AudioOutputUnitStart(_audioUnit);

    if (status != noErr) {
        NSLog(@"SpeakerBuzz: Start error: %d", (int)status);

        AudioUnitUninitialize(_audioUnit);
        AudioComponentInstanceDispose(_audioUnit);
        _audioUnit = NULL;

        [session setActive:NO error:nil];
        return;
    }

    self.buzzing = YES;

    [self.toggleButton setTitle:@"STOP BUZZING"
                       forState:UIControlStateNormal];
}

- (void)stopBuzz {

    if (_audioUnit) {
        AudioOutputUnitStop(_audioUnit);
        AudioUnitUninitialize(_audioUnit);
        AudioComponentInstanceDispose(_audioUnit);
        _audioUnit = NULL;
    }

    [[AVAudioSession sharedInstance]
     setActive:NO
     withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
     error:nil];

    self.buzzing = NO;

    [self.toggleButton setTitle:@"START BUZZING"
                       forState:UIControlStateNormal];
}

- (void)dealloc {

    if (_audioUnit) {
        AudioOutputUnitStop(_audioUnit);
        AudioUnitUninitialize(_audioUnit);
        AudioComponentInstanceDispose(_audioUnit);
        _audioUnit = NULL;
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
        return UIApplicationMain(
            argc,
            argv,
            nil,
            NSStringFromClass([AppDelegate class])
        );
    }
}

