//
//  IKAudioPlayerManager.h
//  IKAudioPlayerModule
//
//  Created by iOS123 on 2019/9/25.
//  Copyright © 2019 CQL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, QLPlayerState) {
    QLPlayerStateToPlay,        // 播放
    QLPlayerStateToPause,       // 暂停
    QLPlayerStateToNext,        // 下一首
    QLPlayerStateToPrevious,    // 上一首
    QLPlayerStateToBufferEmpty, // 缓冲不足
    QLPlayerStateToEnd,         // 结束
};

@interface QLAudioPlayerManager : NSObject
+ (instancetype)sharedManager;

@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) NSMutableArray *audiosArray;
@property (nonatomic, strong) NSString *ArticleListId;

- (void)playAll:(NSArray*)audios Index:(NSInteger)index;
- (void)pause;
- (void)play;
- (void)previous;
- (void)next;
- (void)seekToTime:(CGFloat)drageSecond completionHandler:(void (^ _Nullable )(BOOL))completionHandler;
- (BOOL)isPlaying;

@end

NS_ASSUME_NONNULL_END
