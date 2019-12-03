//
//  IKAudioPlayerManager.m
//  IKAudioPlayerModule
//
//  Created by iOS123 on 2019/9/25.
//  Copyright © 2019 CQL. All rights reserved.
//

#import "QLAudioPlayerManager.h"
#import "MediaPlayer/MediaPlayer.h"

#ifndef weakify
#if DEBUG
#if __has_feature(objc_arc)
#define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef strongify
#if DEBUG
#if __has_feature(objc_arc)
#define strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
#endif
#endif
#endif


@interface QLAudioPlayerManager()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVURLAsset *urlAsset;
@end

@implementation QLAudioPlayerManager

+ (instancetype)sharedManager {
    static QLAudioPlayerManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.currentIndex = 0;
        //开启音频会话后支持后台播放
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
    return self;
}

/**
 播放打断事件处理
 */
- (void)interruptHandleAction:(NSNotification *)noti {
    int type = [noti.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    switch (type) {
        case AVAudioSessionInterruptionTypeBegan:  //被打断
            [self pause];
            //取消选中状态
            break;
        case AVAudioSessionInterruptionTypeEnded: //结束打断
//            [self play];
            //设置为选中状态
        default:
            break;
    }
}

/**
 播放完成的通知
 */
- (void)playerMovieFinish:(NSNotification *)noti{
    [self next];
}

- (void)playAll:(NSArray*)audios Index:(NSInteger)index{
    if (audios.count == 0) {
        return;
    }
    if (index) {
        self.currentIndex = index;
    }else{
        self.currentIndex = 0;
    }
    [self.audiosArray removeAllObjects];
    [self.audiosArray addObjectsFromArray:audios];
    
    [self playerWithURL:audios[index]];
}

- (void)addNotifications{
    //注册打断通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interruptHandleAction:) name:AVAudioSessionInterruptionNotification object:nil];
           
    //播放完成通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerMovieFinish:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    
    //预加载状态
    [self.playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    //得到缓冲的进度
    [self.playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    // 缓冲区空了，需要等待数据
    [self.playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    //监听缓存足够播放的状态
    [self.playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)playerWithURL:(NSString*)url{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"QLAudioPlaybackBufferEmpty" object:nil userInfo:@{@"isEmpty" : @(YES)}];
    
    if (self.playerItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    
    NSURL *tempUrl = [NSURL URLWithString:url];
    self.urlAsset = [AVURLAsset assetWithURL:tempUrl];
    self.playerItem = [AVPlayerItem playerItemWithAsset:self.urlAsset];
    [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
    
    @weakify(self);
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:nil usingBlock:^(CMTime time) {
        @strongify(self);
        AVPlayerItem *item = self.playerItem;
        //两种方式求绝对时间
        NSInteger curTime = (NSInteger)item.currentTime.value/item.currentTime.timescale;
        NSInteger totTime   = (NSInteger)CMTimeGetSeconds(item.duration);
        float value = CMTimeGetSeconds(item.currentTime)/CMTimeGetSeconds(item.duration);
        NSNumber *sliderValue = [[NSNumber alloc]initWithFloat:value];
        
        //NSLog(@"当前播放时间：%ld",(long)currentTime);
        //NSLog(@"总播放时间：%ld",(long)totalTime);
        if ([self isPlaying]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"QLPlayerTimeObserver" object:nil userInfo:@{@"curTime" : @(curTime) ,@"totTime" : @(totTime) ,@"playerIndex" : @(self.currentIndex) , @"sliderValue" : sliderValue}];
        }
    }];
    
    [self addNotifications];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if ([object isKindOfClass:[AVPlayerItem class]]) {
        if ([keyPath isEqualToString:@"status"]) {
            switch (_playerItem.status) {
                case AVPlayerItemStatusReadyToPlay:
                    //将播放放在这里
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"QLAudioPlaybackBufferEmpty" object:nil userInfo:@{@"isEmpty" : @(NO)}];
                    [self play];
                    break;
                case AVPlayerItemStatusUnknown:
                    NSLog(@"AVPlayerItemStatusUnknown");
                    break;
                case AVPlayerItemStatusFailed:
                    NSLog(@"AVPlayerItemStatusFailed");
                    break;
                default:
                    break;
            }
        }
    }
    if ([keyPath isEqualToString:@"loadedTimeRanges"]){
        /**
                NSArray *array = _playerItem.loadedTimeRanges;
               CMTimeRange timeRange = [array.firstObject CMTimeRangeValue];//本次缓冲时间范围
               float startSeconds = CMTimeGetSeconds(timeRange.start);
               float durationSeconds = CMTimeGetSeconds(timeRange.duration);
               NSTimeInterval totalBuffer = startSeconds + durationSeconds;//缓冲总长度
               //NSLog(@"当前缓冲时间：%f",totalBuffer);
         */
      
    }
    if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        //缓冲区空了，所需做的处理操作
    }
    
    if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        //缓冲就绪，所需做的处理操作
    }
}

//播放
- (void)play {
    if (@available(iOS 10.0, *)) {
        [self.player playImmediatelyAtRate:1.0];
    } else {
        [self.player play];
    }
    
    //更新NowPlayingCenter数据
    [self configNowPlayingCenter];
    
    //如果不是正在播放
    if (![self isPlaying]) {
        if (self.currentIndex >= self.audiosArray.count) {
            return;
        }
        
        [self playerWithURL:self.audiosArray[self.currentIndex]];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"QLPlayerStateChanged" object:nil userInfo:@{@"playerState" : @(QLPlayerStateToPlay) ,@"playerIndex" : @(self.currentIndex)}];

}

//暂停
- (void)pause {
    [self.player pause];
    
    //更新NowPlayingCenter数据
    [self configNowPlayingCenter];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"QLPlayerStateChanged"  object:nil userInfo:@{@"playerState" : @(QLPlayerStateToPause),@"playerIndex" : @(self.currentIndex)}];
}

//上一个
- (void)previous{
    if (self.currentIndex == 0) {
        //@"这是第一条"
        return;
    }
    -- self.currentIndex;
    self.currentIndex = self.currentIndex < 0 ? 0 : self.currentIndex;
    NSLog(@"上一个音频%ld",(long)self.currentIndex);
    [self playerWithURL:self.audiosArray[self.currentIndex]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"QLPlayerStateChanged" object:nil userInfo:@{@"playerState" : @(QLPlayerStateToPrevious),@"playerIndex" : @(self.currentIndex)}];
}

//下一个
- (void)next{
    if (self.currentIndex == self.audiosArray.count-1) {
        //@"当前列表已播完"
        [[NSNotificationCenter defaultCenter] postNotificationName:@"QLPlayerStateChanged"  object:nil userInfo:@{@"playerState" : @(QLPlayerStateToEnd),@"playerIndex" : @(self.currentIndex)}];
        return;
    }
    ++ self.currentIndex;
    self.currentIndex = self.currentIndex >= self.audiosArray.count ? self.audiosArray.count-1 : self.currentIndex;
    NSLog(@"下一个音频%ld----%lu",(long)self.currentIndex,(unsigned long)self.audiosArray.count);
    
    [self playerWithURL:self.audiosArray[self.currentIndex]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"QLPlayerStateChanged" object:nil userInfo:@{@"playerState" : @(QLPlayerStateToNext),@"playerIndex" : @(self.currentIndex)}];
}

//改变进度
- (void)seekToTime:(CGFloat)drageSecond completionHandler:(void (^)(BOOL))completionHandler{
    if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
        AVPlayerItem *item = self.playerItem;
        NSTimeInterval currentTime = drageSecond *CMTimeGetSeconds(item.duration);
        [self.player seekToTime:CMTimeMake(currentTime, 1) toleranceBefore:CMTimeMake(1, 1) toleranceAfter:CMTimeMake(1, 1) completionHandler:^(BOOL finished) {
            if (completionHandler) {
                completionHandler(finished);
            }
            [self play];
        }];
    }
}

//是否在播放中
- (BOOL)isPlaying{
    return self.player.rate == 0 ? NO : YES;
}

#pragma mark - NowPlayingCenter & Remote Control
/**
 //每次播放暂停和继续都需要更新NowPlayingCenter,并正确设置ElapsedPlaybackTime和PlaybackRate。否则NowPlayingCenter中的播放进度无法正常显示
 *当前播放歌曲进度被拖动时 ✅
 *当前播放的歌曲变化时 ✅
 *播放暂停或者恢复时 ✅
 *当前播放歌曲的信息发生变化时
 **/
- (void)configNowPlayingCenter {
    AVPlayerItem *item = self.playerItem;
    //两种方式求绝对时间
    NSInteger currentTime = (NSInteger)item.currentTime.value/item.currentTime.timescale;
    NSInteger totalTime   = (NSInteger)CMTimeGetSeconds(item.duration);
    
    //NSLog(@"配置NowPlayingCenter");
    NSMutableDictionary * info = [NSMutableDictionary dictionary];
    [info setObject:@"xxx"forKey:MPMediaItemPropertyTitle];
    [info setObject:@"123" forKey:MPMediaItemPropertyArtist];
    [info setObject:@(currentTime) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];//表示已经播放的时间
    [info setObject:@(totalTime) forKey:MPMediaItemPropertyPlaybackDuration];//总共时间
    [info setObject:@(1.0) forKey:MPNowPlayingInfoPropertyPlaybackRate];//表示播放速率.通常情况下播放速率为1.0
    MPMediaItemArtwork * artwork = [[MPMediaItemArtwork alloc] initWithImage:[UIImage imageNamed:@"close"]];
    [info setObject:artwork forKey:MPMediaItemPropertyArtwork];
    [[MPNowPlayingInfoCenter defaultCenter]setNowPlayingInfo:info];
}

- (NSMutableArray *)audiosArray{
    if (!_audiosArray) {
        _audiosArray = [NSMutableArray arrayWithCapacity:0];
    }
    return _audiosArray;
}

-(AVPlayer *)player{
    if (!_player) {
        _player = [[AVPlayer alloc]init];
    }
    return _player;
}
@end
