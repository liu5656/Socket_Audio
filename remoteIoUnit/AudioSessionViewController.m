//
//  AudioSessionViewController.m
//  remoteIoUnit
//
//  Created by 刘健 on 16/7/7.
//  Copyright © 2016年 王凡. All rights reserved.
//

#import "AudioSessionViewController.h"
#import <AudioToolbox/AudioToolbox.h>

@interface AudioSessionViewController ()



@end

@implementation AudioSessionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    

}

// judge if has head set
+ (BOOL)usingHeadSet
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    CFStringRef route;
    UInt32 propertySize = sizeof(CFStringRef);
    AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize, &route);
    
    BOOL hasHeadSet = NO;
    if (route == NULL || CFStringGetLength(route) == 0) {
            // silent mode
    }else{
        /* Known values of route:
         * "Headset"
         * "Headphone"
         * "Speaker"
         * "SpeakerAndMicrophone"
         * "HeadphonesAndMicrophone"
         * "HeadsetInOut"
         * "ReceiverAndMicrophone"
         * "Lineout"
         */
        
        NSString *routStr = (__bridge NSString *)route;
        NSRange headPhoneRange = [routStr rangeOfString:@"Headphone"];
        NSRange headSetRange = [routStr rangeOfString:@"Headset"];
        if (headSetRange.location != NSNotFound) {
            hasHeadSet = YES;
        }
        
        if (headPhoneRange.location != NSNotFound) {
            hasHeadSet = YES;
        }
    }
    if (route) {
        CFRelease(route);
    }
    return hasHeadSet;
    
}

+ (BOOL)isAirplayActived
{
    CFDictionaryRef currentRouteDescriptionDictionary = nil;
    UInt32 dataSize = sizeof(currentRouteDescriptionDictionary);
    AudioSessionGetProperty(kAudioSessionProperty_AudioRouteDescription, &dataSize, &currentRouteDescriptionDictionary);
    
    BOOL airplayActived = NO;
    if (currentRouteDescriptionDictionary)
    {
        CFArrayRef outputs = CFDictionaryGetValue(currentRouteDescriptionDictionary, kAudioSession_AudioRouteKey_Outputs);
        if(outputs != NULL && CFArrayGetCount(outputs) > 0)
        {
            CFDictionaryRef currentOutput = CFArrayGetValueAtIndex(outputs, 0);
            //Get the output type (will show airplay / hdmi etc
            CFStringRef outputType = CFDictionaryGetValue(currentOutput, kAudioSession_AudioRouteKey_Type);
            
            airplayActived = (CFStringCompare(outputType, kAudioSessionOutputRoute_AirPlay, 0) == kCFCompareEqualTo);
        }
        CFRelease(currentRouteDescriptionDictionary);
    }
    return airplayActived;
}

- (void)setAudioOption
{
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
}

- (UInt32)getAllTimeBy:(AudioFileStreamID )inAudioFileStream
{
    UInt32 bitRate;
    UInt32 bitRateSize = sizeof(bitRate);
    OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_BitRate, &bitRateSize, &bitRate);
    if (status != noErr)
    {
        //错误处理
    }
    return bitRate;
}

@end
