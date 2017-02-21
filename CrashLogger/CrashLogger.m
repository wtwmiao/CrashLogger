//
//  CrashLogger.m
//  CrashLoggerDemo
//
//  Created by YourtionGuo on 1/26/15.
//  Copyright (c) 2015 GYX. All rights reserved.
//

#import "CrashLogger.h"
#import <UIKit/UIDevice.h>
#import <UIKit/UIApplication.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#include <libkern/OSAtomic.h>
#include <execinfo.h>

NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString * const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
NSString * const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

volatile int32_t UncaughtExceptionCount = 0;
const int32_t UncaughtExceptionMaximum = 10;

const NSInteger UncaughtExceptionHandlerSkipAddressCount = 4;
const NSInteger UncaughtExceptionHandlerReportAddressCount = 5;

NSString *logPathUrl() {
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]stringByAppendingPathComponent:@"Exception.txt"];
}

void UncaughtExceptionHandler(NSException *exception) {
    
    NSMutableDictionary *log = [[NSMutableDictionary alloc]init];
    [log setObject:[NSDate date] forKey:@"date"];
    
    // exception info
    NSArray *arr = [exception callStackSymbols];
    NSString *reason = [exception reason];
    NSString *name = [exception name];
    [log setObject:name forKey:@"name"];
    [log setObject:reason forKey:@"reason"];
    [log setObject:[arr componentsJoinedByString:@"\n"] forKey:@"log"];
    
    // Device info
    [log setObject:[UIDevice currentDevice].model forKey:@"device"];
    [log setObject:[UIDevice currentDevice].systemVersion forKey:@"osversion"];

    // batteryLevel info
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    [log setObject:[NSNumber numberWithFloat:[UIDevice currentDevice].batteryLevel*100] forKey:@"batteryLevel"];
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
    
    // Network info
    CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];
    [log setObject:networkInfo.currentRadioAccessTechnology forKey:@"networkInfo"];
    [log setObject:carrier.carrierName forKey:@"carrierName"];
    [log setObject:carrier.isoCountryCode forKey:@"isoCountryCode"];
    [log setObject:carrier.mobileCountryCode forKey:@"mobileCountryCode"];
    
    NSString *path = logPathUrl();
    NSDictionary *logfile = [NSDictionary dictionaryWithDictionary:log];
    [logfile writeToFile:path atomically:YES];
}


@implementation CrashLogger{
    NSUncaughtExceptionHandler *_uncaughtExceptionHandler;
}

+ (NSArray *)backtrace
{
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (
         i = UncaughtExceptionHandlerSkipAddressCount;
         i < UncaughtExceptionHandlerSkipAddressCount +
         UncaughtExceptionHandlerReportAddressCount;
         i++)
    {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    
    return backtrace;
}

void SignalHandler(int signal)
{
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount > UncaughtExceptionMaximum)
    {
        return;
    }
    
    NSMutableDictionary *userInfo =
    [NSMutableDictionary
     dictionaryWithObject:[NSNumber numberWithInt:signal]
     forKey:UncaughtExceptionHandlerSignalKey];
    
    NSArray *callStack = [CrashLogger backtrace];
    [userInfo
     setObject:callStack
     forKey:UncaughtExceptionHandlerAddressesKey];
    
    UncaughtExceptionHandler([NSException
                              exceptionWithName:UncaughtExceptionHandlerSignalExceptionName
                              reason:
                              [NSString stringWithFormat:
                               NSLocalizedString(@"Signal %d was raised.", nil),
                               signal]
                              userInfo:
                              [NSDictionary
                               dictionaryWithObject:[NSNumber numberWithInt:signal]
                               forKey:UncaughtExceptionHandlerSignalKey]]);
}

+ (CrashLogger *)sharedInstance
{
    static CrashLogger*_sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[CrashLogger alloc] initPrivate];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Do not init CrashLogger"
                                   reason:@"You should use [CrashLogger sharedInstance]"
                                 userInfo:nil];
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        _uncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
    }
    return self;
}

-(NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

- (void)setHandler
{
    if(isatty(STDOUT_FILENO)) {
        return;
    }
    
    UIDevice *device = [UIDevice currentDevice];
    if([[device model] hasSuffix:@"Simulator"]){
        return;
    }
    
    NSSetUncaughtExceptionHandler (&UncaughtExceptionHandler);
    signal(SIGABRT, SignalHandler);
    signal(SIGILL, SignalHandler);
    signal(SIGSEGV, SignalHandler);
    signal(SIGFPE, SignalHandler);
    signal(SIGBUS, SignalHandler);
    signal(SIGPIPE, SignalHandler);
}

-(void)remuseHandler
{
    NSSetUncaughtExceptionHandler (_uncaughtExceptionHandler);
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
}

-(NSDictionary *)getCashLog
{
    return [NSDictionary dictionaryWithContentsOfFile:logPathUrl()];
}

-(BOOL)deleteCashLog
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:logPathUrl()]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        return [fileManager removeItemAtPath:logPathUrl() error:NULL];
    }else{
        return YES;
    }
}


/*
 - (void)applicationDidFinishLaunching:(UIApplication *)application {
 // 真机测试时保存日志
 if ([CDeviceInfo getModelType] != SIMULATOR) {
 [self redirectNSLogToDocumentFolder];
 }
 }
 */
- (void)redirectNSLogToDocumentFolder
{
    //如果已经连接Xcode调试则不输出到文件
    if(isatty(STDOUT_FILENO)) {
        return;
    }
    
    UIDevice *device = [UIDevice currentDevice];
    if([[device model] hasSuffix:@"Simulator"]){ //在模拟器不保存到文件中
        return;
    }
    
    //将NSlog打印信息保存到Document目录下的Log文件夹下
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Log"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL fileExists = [fileManager fileExistsAtPath:logDirectory];
    if (!fileExists) {
        [fileManager createDirectoryAtPath:logDirectory  withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
//    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
//    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"]];
//    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"]; //每次启动后都保存一个新的日志文件中
//    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
//    NSString *logFilePath = [logDirectory stringByAppendingFormat:@"/%@.log",dateStr];
    
    NSString *logFilePath  = logPathUrl();
    
    // 将log输入到文件
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stdout);
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
    
    //未捕获的Objective-C异常日志
    ///NSSetUncaughtExceptionHandler (&UncaughtExceptionHandler);
}


-(void)uploadLog{
    
    //把错误日志发送到邮箱

    
    NSString *urlStr = [NSString stringWithFormat:@"mailto://mm@qq.com?subject=bug报告&body=感谢您的配合!"];
  
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [[UIApplication sharedApplication] openURL:url];
}

void UncaughtExceptionHandler_(NSException* exception)
{
    NSString* name = [ exception name ];
    NSString* reason = [ exception reason ];
    NSArray* symbols = [ exception callStackSymbols ]; // 异常发生时的调用栈
    NSMutableString* strSymbols = [ [ NSMutableString alloc ] init ]; //将调用栈拼成输出日志的字符串
    for ( NSString* item in symbols )
    {
        [ strSymbols appendString: item ];
        [ strSymbols appendString: @"\r\n" ];
    }
    
    //将crash日志保存到Document目录下的Log文件夹下
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Log"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:logDirectory]) {
        [fileManager createDirectoryAtPath:logDirectory  withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *logFilePath = [logDirectory stringByAppendingPathComponent:@"UncaughtException.log"];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"]];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    
    NSString *crashString = [NSString stringWithFormat:@"<- %@ ->[ Uncaught Exception ]\r\nName: %@, Reason: %@\r\n[ Fe Symbols Start ]\r\n%@[ Fe Symbols End ]\r\n\r\n", dateStr, name, reason, strSymbols];
    //把错误日志写到文件中
    if (![fileManager fileExistsAtPath:logFilePath]) {
        [crashString writeToFile:logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }else{
        NSFileHandle *outFile = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        [outFile seekToEndOfFile];
        [outFile writeData:[crashString dataUsingEncoding:NSUTF8StringEncoding]];
        [outFile closeFile];
    }
    
   
}

@end
