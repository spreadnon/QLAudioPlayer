//
//  ViewController.m
//  QLAudioPlayer
//
//  Created by iOS123 on 2019/12/3.
//  Copyright © 2019 CQL. All rights reserved.
//

#import "ViewController.h"
#import "QLAudioPlayerManager.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSArray *urls = [NSArray new];
    NSInteger index = 0;
    [[QLAudioPlayerManager sharedManager] playAll:urls Index:index];
}


@end
