//
//  RCCall.m
//  RongCallKit
//
//  Created by 岑裕 on 16/3/11.
//  Copyright © 2016年 RongCloud. All rights reserved.
//

#import "RCCall.h"
#import "RCCallAudioMultiCallViewController.h"
#import "RCCallBaseViewController.h"
#import "RCCallDetailMessageCell.h"
#import "RCCallKitUtility.h"
#import "RCCallSelectMemberViewController.h"
#import "RCCallSelectMemberViewController.h"
#import "RCCallSingleCallViewController.h"
#import "RCCallTipMessageCell.h"
#import "RCCallVideoMultiCallViewController.h"
#import "RCDVideoFrameObserver.h"
#import "RCUserInfoCacheManager.h"
#import <AVFoundation/AVFoundation.h>
#import "RCDAudioFrameObserver.h"

#define AlertWithoutConfirm 1000
#define AlertWithConfirm 1001

@interface RCCall () <RCCallReceiveDelegate>

@property(nonatomic, strong) NSMutableDictionary *alertInfoDic;
@property(nonatomic, strong) AVAudioPlayer *audioPlayer;
@property(nonatomic, strong) NSMutableArray *callWindows;
@property(nonatomic, strong) NSMutableArray *locationNotificationList;
@end

@implementation RCCall

+ (instancetype)sharedRCCall {
  static RCCall *pRongVoIP;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (pRongVoIP == nil) {
      pRongVoIP = [[RCCall alloc] init];
      [[RCCallClient sharedRCCallClient] setDelegate:pRongVoIP];
      pRongVoIP.maxMultiAudioCallUserNumber = 20;
      pRongVoIP.maxMultiVideoCallUserNumber = 9;
      pRongVoIP.callWindows = [[NSMutableArray alloc] init];
      pRongVoIP.locationNotificationList = [[NSMutableArray alloc] init];

//      agoraRegisterVideoFrameObserver(RCDVideoFrameObserver::sharedObserver(), true, true);
//      agoraRegisterAudioFrameObserver(RCDAudioFrameObserver::sharedObserver());
    }
  });
  return pRongVoIP;
}

- (BOOL)isAudioCallEnabled:(RCConversationType)conversationType {
  return
      [[RCCallClient sharedRCCallClient] isAudioCallEnabled:conversationType];
}

- (BOOL)isVideoCallEnabled:(RCConversationType)conversationType {
  return
      [[RCCallClient sharedRCCallClient] isVideoCallEnabled:conversationType];
}

- (void)startSingleCall:(NSString *)targetId
              mediaType:(RCCallMediaType)mediaType {
  if ([self preCheckForStartCall:mediaType]) {
    [self checkSystemPermission:mediaType
                        success:^{
                          [self startSingleCallViewController:targetId
                                                    mediaType:mediaType];
                        }];
  }
}

- (void)startSingleCallViewController:(NSString *)targetId
                            mediaType:(RCCallMediaType)mediaType {
  RCCallSingleCallViewController *singleCallViewController =
      [[RCCallSingleCallViewController alloc] initWithOutgoingCall:targetId
                                                         mediaType:mediaType];

  [self presentCallViewController:singleCallViewController];
}

- (void)startMultiCall:(RCConversationType)conversationType
              targetId:(NSString *)targetId
             mediaType:(RCCallMediaType)mediaType {
  if ([self preCheckForStartCall:mediaType]) {
    [self checkSystemPermission:mediaType
                        success:^{
                          [self startSelectMemberViewContoller:conversationType
                                                      targetId:targetId
                                                     mediaType:mediaType];
                        }];
  }
}

- (void)startSelectMemberViewContoller:(RCConversationType)conversationType
                              targetId:(NSString *)targetId
                             mediaType:(RCCallMediaType)mediaType {
  if (conversationType == ConversationType_DISCUSSION ||
      conversationType == ConversationType_GROUP) {
    __weak typeof(self) weakSelf = self;
    RCCallSelectMemberViewController *voipCallSelectViewController =
        [[RCCallSelectMemberViewController alloc]
            initWithConversationType:conversationType
                            targetId:targetId
                           mediaType:mediaType
                               exist:@[
                                 [RCIMClient sharedRCIMClient]
                                     .currentUserInfo.userId
                               ]
                             success:^(NSArray *addUserIdList) {
                               [weakSelf
                                   startMultiCallViewController:conversationType
                                                       targetId:targetId
                                                      mediaType:mediaType
                                                     userIdList:addUserIdList];
                             }];

    [self presentCallViewController:voipCallSelectViewController];
  }
}

- (void)startMultiCallViewController:(RCConversationType)conversationType
                            targetId:(NSString *)targetId
                           mediaType:(RCCallMediaType)mediaType
                          userIdList:(NSArray *)userIdList {
  if (mediaType == RCCallMediaAudio) {
    UIViewController *audioCallViewController =
        [[RCCallAudioMultiCallViewController alloc]
            initWithOutgoingCall:conversationType
                        targetId:targetId
                      userIdList:userIdList];

    [self presentCallViewController:audioCallViewController];
  } else {
    RCCallVideoMultiCallViewController *videoCallViewController =
        [[RCCallVideoMultiCallViewController alloc]
            initWithOutgoingCall:conversationType
                        targetId:targetId
                       mediaType:mediaType
                      userIdList:userIdList];

    [self presentCallViewController:videoCallViewController];
  }
}

- (void)checkSystemPermission:(RCCallMediaType)mediaType
                      success:(void (^)())successBlock {
  if (mediaType == RCCallMediaVideo) {
    [self checkCapturePermission:^(BOOL granted) {
      if (granted) {
        [self checkRecordPermission:^() {
          successBlock();
        }];
      }
    }];

  } else if (mediaType == RCCallMediaAudio) {
    [self checkRecordPermission:^() {
      successBlock();
    }];
  }
}

- (void)checkRecordPermission:(void (^)())successBlock {
  if ([[AVAudioSession sharedInstance]
          respondsToSelector:@selector(requestRecordPermission:)]) {
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (granted) {
          successBlock();
        } else {
          [self loadErrorAlertWithConfirm:NSLocalizedStringFromTable(
                                              @"AccessRightTitle",
                                              @"RongCloudKit", nil)
                                  message:NSLocalizedStringFromTable(
                                              @"speakerAccessRight",
                                              @"RongCloudKit", nil)];
        }
      });
    }];
  }
}

- (void)checkCapturePermission:(void (^)(BOOL granted))complete {
  AVAuthorizationStatus authStatus =
      [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

  if (authStatus == AVAuthorizationStatusDenied ||
      authStatus == AVAuthorizationStatusRestricted) {
    [self
        loadErrorAlertWithConfirm:NSLocalizedStringFromTable(
                                      @"AccessRightTitle", @"RongCloudKit", nil)
                          message:NSLocalizedStringFromTable(
                                      @"cameraAccessRight", @"RongCloudKit",
                                      nil)];
    complete(NO);
  } else if (authStatus == AVAuthorizationStatusNotDetermined) {
    [AVCaptureDevice
        requestAccessForMediaType:AVMediaTypeVideo
                completionHandler:^(BOOL granted) {
                  if (!granted) {
                    [self loadErrorAlertWithConfirm:NSLocalizedStringFromTable(
                                                        @"AccessRightTitle",
                                                        @"RongCloudKit", nil)
                                            message:NSLocalizedStringFromTable(
                                                        @"cameraAccessRight",
                                                        @"RongCloudKit", nil)];
                  }
                  complete(granted);
                }];
  } else {
    complete(YES);
  }
}

- (BOOL)preCheckForStartCall:(RCCallMediaType)mediaType {
  RCCallSession *currentCallSession = [RCCall sharedRCCall].currentCallSession;
  if (currentCallSession && currentCallSession.mediaType == RCCallMediaAudio) {
    [self loadErrorAlertWithoutConfirm:NSLocalizedStringFromTable(
                                           @"VoIPAudioCallExistedWarning",
                                           @"RongCloudKit", nil)];
    return NO;
  } else if (currentCallSession &&
             currentCallSession.mediaType == RCCallMediaVideo) {
    [self loadErrorAlertWithoutConfirm:NSLocalizedStringFromTable(
                                           @"VoIPVideoCallExistedWarning",
                                           @"RongCloudKit", nil)];
    return NO;
  } else {
    return YES;
  }
}

- (void)presentCallViewController:(UIViewController *)viewController{
  [[[UIApplication sharedApplication] keyWindow] endEditing:YES];
  UIWindow *activityWindow =
  [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  activityWindow.windowLevel = UIWindowLevelAlert;
  activityWindow.rootViewController = viewController;
  [activityWindow makeKeyAndVisible];
  CATransition *animation = [CATransition animation];
  [animation setDuration:0.3];
  animation.type = kCATransitionMoveIn;     //可更改为其他方式
  animation.subtype = kCATransitionFromTop; //可更改为其他方式
  [[activityWindow layer] addAnimation:animation forKey:nil];
  [self.callWindows addObject:activityWindow];
}

- (void)dismissCallViewController:(UIViewController *)viewController {

  if ([viewController isKindOfClass:[RCCallBaseViewController class]]) {
    UIViewController *rootVC = viewController;
    while (rootVC.parentViewController) {
      rootVC = rootVC.parentViewController;
    }
    viewController = rootVC;
  }

  for (UIWindow *window in self.callWindows) {
    if (window.rootViewController == viewController) {
      [window resignKeyWindow];
      window.hidden = YES;
      [[UIApplication sharedApplication].delegate.window makeKeyWindow];
      [self.callWindows removeObject:window];
      break;
    }
  }
  [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (RCCallSession *)currentCallSession {
  return [RCCallClient sharedRCCallClient].currentCallSession;
}

#pragma mark - receive call
- (void)didReceiveCall:(RCCallSession *)callSession {
    if (!(callSession.conversationType == ConversationType_PRIVATE)) {
    RCCallSingleCallViewController *singleCallViewController =
        [[RCCallSingleCallViewController alloc]
            initWithIncomingCall:callSession];

    [self presentCallViewController:singleCallViewController];
  } else {
    if (callSession.mediaType == RCCallMediaAudio) {
      RCCallAudioMultiCallViewController *multiCallViewController =
          [[RCCallAudioMultiCallViewController alloc]
              initWithIncomingCall:callSession];

      [self presentCallViewController:multiCallViewController];
    } else {
      RCCallVideoMultiCallViewController *multiCallViewController =
          [[RCCallVideoMultiCallViewController alloc]
              initWithIncomingCall:callSession];

      [self presentCallViewController:multiCallViewController];
    }
  }
}

- (void)didCancelCallRemoteNotification:(NSString *)callId
                          inviterUserId:(NSString *)inviterUserId
                              mediaType:(RCCallMediaType)mediaType
                             userIdList:(NSArray *)userIdList {
  for (UILocalNotification *notification in self.locationNotificationList) {
    if ([notification.userInfo[@"appData"][@"callId"] isEqualToString:callId]) {
      [[UIApplication sharedApplication] cancelLocalNotification:notification];
      [self.locationNotificationList removeObject:notification];
      break;
    }
  }
}

- (void)didReceiveCallRemoteNotification:(NSString *)callId
                           inviterUserId:(NSString *)inviterUserId
                               mediaType:(RCCallMediaType)mediaType
                              userIdList:(NSArray *)userIdList
                                userDict:(NSDictionary *)userDict {
  UILocalNotification *callNotification = [[UILocalNotification alloc] init];
  callNotification.alertAction = NSLocalizedStringFromTable(
      @"LocalNotificationShow", @"RongCloudKit", nil);

  NSString *inviterUserName =
      [[RCUserInfoCacheManager sharedManager] getUserInfo:inviterUserId].name;
  if (mediaType == RCCallMediaAudio) {
    if (inviterUserName) {
      callNotification.alertBody = [NSString
          stringWithFormat:@"%@%@", inviterUserName,
                           NSLocalizedStringFromTable(@"VoIPAudioCallIncoming",
                                                      @"RongCloudKit", nil)];
    } else {
      callNotification.alertBody = [NSString
          stringWithFormat:@"%@", NSLocalizedStringFromTable(
                                        @"VoIPAudioCallIncomingWithoutUserName",
                                        @"RongCloudKit", nil)];
      ;
    }
  } else {
    if (inviterUserName) {
      callNotification.alertBody = [NSString
          stringWithFormat:@"%@%@", inviterUserName,
                           NSLocalizedStringFromTable(@"VoIPVideoCallIncoming",
                                                      @"RongCloudKit", nil)];
    } else {
      callNotification.alertBody = [NSString
          stringWithFormat:@"%@", NSLocalizedStringFromTable(
                                        @"VoIPVideoCallIncomingWithoutUserName",
                                        @"RongCloudKit", nil)];
    }
  }

  callNotification.userInfo = userDict;
  callNotification.soundName = @"RongCloud.bundle/voip/voip_call.caf";

  // VoIP Push和接收消息的通话排重
  for (UILocalNotification *notification in self.locationNotificationList) {
    if ([notification.userInfo[@"appData"][@"callId"] isEqualToString:callId]) {
      return;
    }
  }

  [self.locationNotificationList addObject:callNotification];
  [[UIApplication sharedApplication]
      presentLocalNotificationNow:callNotification];
}

#pragma mark - ringing
- (void)startPlayRing:(NSString *)ringPath {
  if (ringPath) {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    //默认情况下扬声器播放
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];

    if (self.audioPlayer) {
      [self stopPlayRing];
    }

    NSURL *url = [NSURL URLWithString:ringPath];
    NSError *error = nil;
    self.audioPlayer =
        [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (!error) {
      self.audioPlayer.numberOfLoops = -1;
      self.audioPlayer.volume = 1.0;
      [self.audioPlayer prepareToPlay];
      [self.audioPlayer play];
    }
  }
}

- (void)stopPlayRing {
  if (self.audioPlayer) {
    [self.audioPlayer stop];
    self.audioPlayer = nil;
  }
}

#pragma mark - alert
- (void)loadErrorAlertWithoutConfirm:(NSString *)title {
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                  message:nil
                                                 delegate:nil
                                        cancelButtonTitle:nil
                                        otherButtonTitles:nil];
  alert.tag = AlertWithoutConfirm;
  [NSTimer scheduledTimerWithTimeInterval:1.0f
                                   target:self
                                 selector:@selector(cancelAlert:)
                                 userInfo:alert
                                  repeats:NO];
  [alert show];
}

- (void)cancelAlert:(NSTimer *)scheduledTimer {
  UIAlertView *alert = (UIAlertView *)(scheduledTimer.userInfo);
  if (alert.tag == AlertWithoutConfirm) {
    [alert dismissWithClickedButtonIndex:0 animated:NO];
  }
}

- (void)loadErrorAlertWithConfirm:(NSString *)title
                          message:(NSString *)message {
  UIAlertView *alert = [[UIAlertView alloc]
          initWithTitle:title
                message:message
               delegate:nil
      cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"RongCloudKit", nil)
      otherButtonTitles:nil];
  alert.tag = AlertWithConfirm;
  [alert show];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//接口向后兼容 [[++
- (id<RCCallGroupMemberDataSource>)groupMemberDataSource {
  return [RCIM sharedRCIM].groupMemberDataSource;
}
- (void)setGroupMemberDataSource:(id<RCCallGroupMemberDataSource>)groupMemberDataSource {
  [RCIM sharedRCIM].groupMemberDataSource = groupMemberDataSource;
}
//接口向后兼容 --]]

@end
