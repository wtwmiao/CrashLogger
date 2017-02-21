//
//  ViewController.m
//  CrashLoggerDemo
//
//  Created by YourtionGuo on 1/26/15.
//  Copyright (c) 2015 GYX. All rights reserved.
//

#import "ViewController.h"
#import "CrashLogger.h"

@interface ViewController ()
@property(strong, atomic)CrashLogger *crashHandle;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.crashHandle = [CrashLogger sharedInstance];
  
    
    UIButton *btn  = [[UIButton alloc]initWithFrame:CGRectMake(0, 10, 300, 50)];
    [btn addTarget:self action:@selector(onclick) forControlEvents:UIControlEventTouchUpInside];
    [btn setTitle:@"注册" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize: 14.0];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor grayColor];
    [self.view addSubview:btn];
    
    UIButton *btn2  = [[UIButton alloc]initWithFrame:CGRectMake(0, 100, 300, 50)];
    [btn2 addTarget:self action:@selector(onclick2) forControlEvents:UIControlEventTouchUpInside];
    [btn2 setTitle:@"测试" forState:UIControlStateNormal];
    btn2.titleLabel.font = [UIFont systemFontOfSize: 14.0];
    [btn2 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    btn2.backgroundColor = [UIColor grayColor];
    [self.view addSubview:btn2];
    
}

-(void)onclick{
    [self.crashHandle redirectNSLogToDocumentFolder];
    NSLog(@"this is test  of logupload ");
    NSLog(@"this is test  of loguploadd 2222 ");
}

-(void)onclick2{
   // [self  test];
    [self.crashHandle uploadLog];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)add:(id)sender {
   // [self.crashHandle setHandler];
}

- (IBAction)remove:(id)sender {
   // [self.crashHandle remuseHandler];
}

- (IBAction)cash:(id)sender {
    [super delete:nil];
}

- (IBAction)get:(id)sender {
    NSLog(@"Log: %@",[self.crashHandle getCashLog]);
}

- (IBAction)delete:(id)sender {
    [self.crashHandle deleteCashLog];
}

@end
