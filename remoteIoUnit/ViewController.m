//
//  RootViewController.m
//  recorder1
//
//  Created by luna on 13-8-5.
//  Copyright (c) 2013年 xxx. All rights reserved.
//

#import "ViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "InMemoryAudioFile.h"
#import "AsyncUdpSocket.h"
#import "AsyncSocket.h"
#import <AVFoundation/AVFoundation.h>
#import <OpenAL/OpenAL.h>


@interface ViewController () <AsyncUdpSocketDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,AsyncSocketDelegate>
{
    ALCdevice       *mDevice;
    ALCcontext      *mContext;
    ALuint          outSourceID;
}

@property (strong,nonatomic) AsyncUdpSocket *udpSocket;

@property (strong,nonatomic) AsyncSocket *tcpSocket;

@property (nonatomic,strong) AVCaptureSession *session;
@property (nonatomic,strong) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer  *previewLayer;
@property (nonatomic,strong) AVCaptureAudioDataOutput* audioOutput;
@end

@implementation ViewController


- (IBAction)sendData:(id)sender {
    
    [self.session stopRunning];
}
- (IBAction)touchdown:(id)sender {
    
    [self.session startRunning];

}

-(void)viewDidLoad
{
    [self setUpSession];
    [self InitTcpSocket];
}

-(void)InitTcpSocket{
    self.tcpSocket = [[AsyncSocket alloc] initWithDelegate:self];
    NSError *err;
    [self.tcpSocket connectToHost:@"192.168.20.214" onPort:7789 error:&err];
    NSLog(@"error %@",err);
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port{
    NSLog(@"连接上了");
    [self.tcpSocket readDataWithTimeout:-1 tag:100];
}


- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"%lu",(unsigned long)data.length);

    [self.tcpSocket readDataWithTimeout:-1 tag:100];
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag{
    NSLog(@"发送了包");
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock{
    NSLog(@"断开链接");
}


-(void) setUpSession
{
    _session = [[AVCaptureSession alloc] init];
    
    AVCaptureDevice * audioDevice1 = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput1 = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice1 error:nil];
    _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
    [_audioOutput setSampleBufferDelegate:self queue:queue];
    
    [_session beginConfiguration];
    if (audioInput1) {
        [_session addInput:audioInput1];
    }
    
    [_session addOutput:_audioOutput];
    
    [_session commitConfiguration];
    
}

-(void)InitSocket
{
    self.udpSocket = [[AsyncUdpSocket alloc] initWithDelegate:self];
    [self.udpSocket bindToPort:25257 error:nil];
    
    NSError *error;
    
    [self.udpSocket enableBroadcast:YES error:&error];
    [self.udpSocket receiveWithTimeout:-1 tag:100];
}

-(void)onUdpSocket:(AsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    NSLog(@"发送数据失败");
}

-(BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"%lu",(unsigned long)data.length);
    
    [self.udpSocket receiveWithTimeout:-1 tag:100];
    return YES;
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
//    NSData *data = [@"Hello" dataUsingEncoding:NSUTF8StringEncoding];
    
    CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length = CMBlockBufferGetDataLength(blockBufferRef);
    Byte buffer[length];
    CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, buffer);
    NSData *data = [NSData dataWithBytes:buffer length:length];
    
    dispatch_async(dispatch_get_main_queue(), ^{
//        [self.udpSocket sendData:data toHost:@"192.168.2.8" port:25257 withTimeout:-1 tag:100];
        [self.tcpSocket writeData:data withTimeout:-1 tag:100];
    });

    
}





@end