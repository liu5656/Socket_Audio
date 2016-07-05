//
//  AudioViewController.m
//  remoteIoUnit
//
//  Created by lj on 16/7/5.
//  Copyright © 2016年 王凡. All rights reserved.
//

#import "AudioViewController.h"
#import <AudioToolbox/AudioToolbox.h>

#define QUEUE_BUFFER_SIZE 4 // 队列缓冲个数
#define EVERY_READ_LENGTH 1000 // 每次从文件读取个数
#define MIN_SIZE_PER_FRAME  2000 // 每帧最小数据长度

@interface AudioViewController ()
{
    AudioStreamBasicDescription audioDescription; // 音频参数
    AudioQueueRef audioQueue; // 音频播放队列
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE]; // 音频缓存
    NSLock *synlock; // 同步控制
    Byte *pcmDataBuffer; // pcm的读文件区
    FILE *file; //pcm文件
}

static void AudioPlayerAQInputCallback(void *input, AudioQueueRef inQ, AudioQueueBufferRef outQB);

- (void)onbutton1clicked;
- (void)onbutton2clicked;
- (void)initAudio;
- (void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB;
- (void)checkUsedQueueBuffer:(AudioQueueBufferRef)qbuf;

@end

@implementation AudioViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        NSString *filePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"love.mp3"];
        NSLog(@"filepath = %@",filePath);
        NSFileManager *manager = [NSFileManager defaultManager];
        NSLog(@"file exist = %d", [manager fileExistsAtPath:filePath]);
        NSLog(@"file size = %lld", [[manager attributesOfItemAtPath:filePath error:nil] fileSize]);
        file = fopen([filePath UTF8String], "r");
        if (file) {
            fseek(file, 0, SEEK_SET);
            pcmDataBuffer = malloc(EVERY_READ_LENGTH);
        }else{
            NSLog(@"文件读取失败");
        }
        synlock = [[NSLock alloc] init];
    }
    return self;
}

-(void)initializeView
{
    self.view.backgroundColor = [UIColor grayColor];
    
    UIButton *button1 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button1.frame = CGRectMake(10, 10, 300, 50);
    [button1 setTitle:@"button1" forState:UIControlStateNormal];
    [button1 setTitle:@"button1" forState:UIControlStateHighlighted];
    [button1 addTarget:self action:@selector(onbutton1clicked) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button1];
    
    UIButton *button2 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button2.frame = CGRectMake(10, 70, 300, 50);
    [button2 setTitle:@"button2" forState:UIControlStateNormal];
    [button2 setTitle:@"button2" forState:UIControlStateHighlighted];
    [button2 addTarget:self action:@selector(onbutton2clicked) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(void)onbutton1clicked
{
    [self initAudio];
    NSLog(@"button1 clicked");
    
    AudioQueueStart(audioQueue, NULL);
    
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        [self readPCMAndPlay:audioQueue buffer:audioQueueBuffers[i]];
    }
    /*
     audioQueue使用的是驱动回调方式，即通过AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);传入一个buff去播放，播放完buffer区后通过回调通知用户,
     用户得到通知后再重新初始化buff去播放，周而复始,当然，可以使用多个buff提高效率(测试发现使用单个buff会小卡)
     */
}

-(void)onbutton2clicked
{
    NSLog(@"onbutton2clicked");
}

#pragma mark -
#pragma mark player call back
/*
 试了下其实可以不用静态函数，但是c写法的函数内是无法调用[self ***]这种格式的写法，所以还是用静态函数通过void *input来获取原类指针
 这个回调存在的意义是为了重用缓冲buffer区，当通过AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);函数放入queue里面的音频文件播放完以后，通过这个函数通知
 调用者，这样可以重新再使用回调传回的AudioQueueBufferRef
 */
static void AudioPlayerAQInputCallback(void *input, AudioQueueRef outQ, AudioQueueBufferRef outQB)
{
    NSLog(@"AudioPlayerAQInputCallback");
    AudioViewController *mainviewcontroller = (__bridge AudioViewController *)input;
    [mainviewcontroller checkUsedQueueBuffer:outQB];
    [mainviewcontroller readPCMAndPlay:outQ buffer:outQB];
}



-(void)initAudio
{
    ///设置音频参数
    audioDescription.mSampleRate = 8000;//采样率
    audioDescription.mFormatID = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioDescription.mChannelsPerFrame = 1;///单声道
    audioDescription.mFramesPerPacket = 1;//每一个packet一侦数据
    audioDescription.mBitsPerChannel = 16;//每个采样点16bit量化
    audioDescription.mBytesPerFrame = (audioDescription.mBitsPerChannel/8) * audioDescription.mChannelsPerFrame;
    audioDescription.mBytesPerPacket = audioDescription.mBytesPerFrame ;
    ///创建一个新的从audioqueue到硬件层的通道
    //  AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audioQueue);///使用当前线程播
    AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, (__bridge void * _Nullable)(self), nil, nil, 0, &audioQueue);//使用player的内部线程播
    ////添加buffer区
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        int result =  AudioQueueAllocateBuffer(audioQueue, MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d",i,result);
    }
}

-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB
{
    [synlock lock];
    int readLength = fread(pcmDataBuffer, 1, EVERY_READ_LENGTH, file);//读取文件
    NSLog(@"read raw data size = %d",readLength);
    outQB->mAudioDataByteSize = readLength;
    Byte *audiodata = (Byte *)outQB->mAudioData;
    for(int i=0;i<readLength;i++)
    {
        audiodata[i] = pcmDataBuffer[i];
    }
    /*
     将创建的buffer区添加到audioqueue里播放
     AudioQueueBufferRef用来缓存待播放的数据区，AudioQueueBufferRef有两个比较重要的参数，AudioQueueBufferRef->mAudioDataByteSize用来指示数据区大小，AudioQueueBufferRef->mAudioData用来保存数据区
     */
    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
    [synlock unlock];
}

-(void)checkUsedQueueBuffer:(AudioQueueBufferRef) qbuf
{
    if(qbuf == audioQueueBuffers[0])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 0");
    }
    if(qbuf == audioQueueBuffers[1])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 1");
    }
    if(qbuf == audioQueueBuffers[2])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 2");
    }
    if(qbuf == audioQueueBuffers[3])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 3");
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
    [self initializeView];
}
@end
