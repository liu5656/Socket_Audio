//
//  ServerViewController.m
//  remoteIoUnit
//
//  Created by 刘健 on 16/7/5.
//  Copyright © 2016年 王凡. All rights reserved.
//

#import "ServerViewController.h"
#import "GCDAsyncSocket.h"

#import <AVFoundation/AVFoundation.h>
#import <OpenAL/OpenAL.h>

@interface ServerViewController ()<GCDAsyncSocketDelegate>
{
    ALCdevice       *mDevice;
    ALCcontext      *mContext;
    ALuint          outSourceID;
}
@property(nonatomic,strong) GCDAsyncSocket *serverSocket;
@property(nonatomic,strong) NSMutableArray *clientSocketArray;  //保存客服端的所有Socket

@end

@implementation ServerViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    [self initOpenAL];
    [self start];
}

-(NSMutableArray *)clientSocketArray
{
    if (!_clientSocketArray) {
        _clientSocketArray = [NSMutableArray array];
    }
    
    return _clientSocketArray;
}


-(void)start
{
    GCDAsyncSocket *serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
    
    NSError *error = nil;
    [serverSocket acceptOnPort:10000 error:&error];
    if (!error) {
        NSLog(@"服务端已经开启");
    } else {
        NSLog(@"服务端开启失败");
    }
    
    self.serverSocket = serverSocket;   //需要对服务端Socket进行强引用,否则创建完就销毁了
    
    
}
#pragma mark -  有客户端链接
-(void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    NSLog(@"有客服端连接服务器%@----%@",sock,newSocket);
    [self.clientSocketArray addObject:newSocket];
    
    //监听客户端发送数据
    [newSocket readDataWithTimeout:-1 tag:0];
    
}

#pragma mark - 读取客户端请求的数据
-(void)socket:(GCDAsyncSocket *)clientSocket didReadData:(NSData *)data withTag:(long)tag
{
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"长度:%lu--数据:%@",(unsigned long)data.length, str);
    NSArray *tempArray = [str componentsSeparatedByString:@"|"];
    NSString *symbol = tempArray.firstObject;
    
    [clientSocket readDataWithTimeout:-1 tag:0];
//    [self openAudioFromQueue:data.bytes dataSize:data.length];
    
    if ([@"CK" isEqualToString:symbol]) {
        NSLog(@"收到心跳包");
        [clientSocket writeData:[@"00" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:12];
        return;
    }
    
    [clientSocket writeData:[@"00" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:12];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark 播放音频
-(void)initOpenAL
{
    
    mDevice=alcOpenDevice(NULL);
    if(mDevice) {
        mContext=alcCreateContext(mDevice,NULL);
        alcMakeContextCurrent(mContext);
    }
    
    alGenSources(1,&outSourceID);
    alSourcei(outSourceID,AL_LOOPING, AL_FALSE);
    alSourcef(outSourceID,AL_SOURCE_TYPE, AL_STREAMING);
}

- (BOOL) updataQueueBuffer
{
    ALint stateVaue;
    int processed, queued;
    
    
    alGetSourcei(outSourceID,AL_SOURCE_STATE, &stateVaue);
    
    if(stateVaue == AL_STOPPED)
    {
        return NO;
    }
    
    
    alGetSourcei(outSourceID,AL_BUFFERS_PROCESSED, &processed);
    alGetSourcei(outSourceID,AL_BUFFERS_QUEUED, &queued);
    
    
    NSLog(@"Processed= %dn", processed);
    NSLog(@"Queued= %dn", queued);
    
    
    while(processed--)
    {
        ALuint buff;
        alSourceUnqueueBuffers(outSourceID,1, &buff);
        alDeleteBuffers(1,&buff);
    }
    
    return YES;
}


- (void) openAudioFromQueue:(unsigned char*)data dataSize:(UInt32)dataSize
{
    ALenum  error= AL_NO_ERROR;
    
    if(data == NULL) {
        return;
    }
    
    NSCondition*ticketCondition= [[NSCondition alloc] init];
    
    [ticketCondition lock];
    [self updataQueueBuffer];
    
    ALuint bufferID = 0;
    alGenBuffers(1,&bufferID);
    if((error= alGetError()) != AL_NO_ERROR) {
        NSLog(@"erroralGenBuffers: %xn", error);
    }
    else{
        NSLog(@"sucalGenBuffers: %xn", error);
        NSLog(@"%s",data);
        int size = strlen( (const char *)data);
        
        NSData* tmpData = [NSData dataWithBytes:data length:dataSize];
        alBufferData(bufferID,AL_FORMAT_MONO16, (const ALvoid*)[tmpData bytes],(ALsizei)[tmpData length], 44100);
        if((error= alGetError()) != AL_NO_ERROR)
        {
            NSLog(@"errorsucalBufferData: %xn", error);
        }
        else
        {
            NSLog(@"sucalBufferData:%xn", error);
            alSourceQueueBuffers(outSourceID,1, &bufferID);
            if((error= alGetError()) != AL_NO_ERROR)
            {
                NSLog(@"erroralSourceQueueBuffers: %xn", error);
            }
            else
            {
                NSLog(@"sucalSourceQueueBuffers: %xn", error);
                ALint value;
                alGetSourcei(outSourceID,AL_SOURCE_STATE,&value);
                //    NSLog(@"%x",value);
                if(value != AL_PLAYING)
                {
                    alSourcePlay(outSourceID);
                }
                if((error= alGetError()) != AL_NO_ERROR)
                {
                    NSLog(@"erroralSourcePlay: %xn", error);
                    alDeleteBuffers(1,&bufferID);
                }
                else
                {
                    NSLog(@"sucalSourcePlay: %xn", error);
                }
            }
        }
    }
    [ticketCondition unlock];
    ticketCondition= nil;
}



@end