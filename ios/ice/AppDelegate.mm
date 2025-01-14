// SPDX-License-Identifier: ice License 1.0

#import "AppDelegate.h"

#import <React/RCTBundleURLProvider.h>
#import <React/RCTI18nUtil.h>

#import <React/RCTLinkingManager.h>
#import <Firebase.h>
#import <RNGoogleSignin/RNGoogleSignin.h>
#import <FBSDKCoreKit/FBSDKCoreKit-swift.h>
#import <React/RCTLinkingManager.h>

#import <ReactNativeMoEngage/MoEngageInitializer.h>
#import <ReactNativeMoEngage/MoEReactBridge.h>
#import <MoEngageSDK/MoEngageSDK.h>
#import <RNFBMessaging/RNFBMessagingSerializer.h>
#import <RNFBApp/RNFBRCTEventEmitter.h>

#import "RNCConfig.h"
#import "RNBootSplash.h"
#import <TSBackgroundFetch/TSBackgroundFetch.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  [self flushKeychainOnReinstall];
  [self configureFirebase];
  [self configureMoengage:launchOptions];
  
  [[FBSDKApplicationDelegate sharedInstance] application:application
                           didFinishLaunchingWithOptions:launchOptions];
  
  [UNUserNotificationCenter currentNotificationCenter].delegate = self;
  
  [[RCTI18nUtil sharedInstance] allowRTL:YES];
  
  // https://github.com/transistorsoft/react-native-background-fetch/blob/master/docs/INSTALL-AUTO-IOS.md
  [[TSBackgroundFetch sharedInstance] didFinishLaunching];
  
  self.moduleName = @"ice";
  // You can add your custom initial props in the dictionary below.
  // They will be passed down to the ViewController used by React Native.
  self.initialProps = @{};
  
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)moEngageRegisterForRemoteNotifications {
  [[MoEngageSDKMessaging sharedInstance] registerForRemoteNotificationWithCategories:nil andUserNotificationCenterDelegate:self];
}

- (NSString *)getMoeDeeplink {
  return self.moeDeeplink;
}

// UserNotifications Framework Callback for iOS10 and above
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)())completionHandler{
  NSDictionary *userInfo = response.notification.request.content.userInfo;
  // Check if the notification is from MoEngage
  if (userInfo[@"moengage"] != nil) {
    NSDictionary *eventPayload = @{@"kEventName": @"pushClicked", @"kPayloadDict": userInfo};
    [[MoEReactBridge allocWithZone: nil] sendEventWithName:eventPayload];
  } else {
    // It is a Firebase Message, send it to JS
    if (userInfo[@"gcm.message_id"] != nil) {
      NSDictionary *notificationDict =
      [RNFBMessagingSerializer remoteMessageUserInfoToDict:userInfo];
      [[RNFBRCTEventEmitter shared] sendEventWithName:@"messaging_notification_opened"
                                                 body:notificationDict];
    }
  }
  
  //Custom Handling of notification if Any
  completionHandler();
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler{
  
  //This is to only to display Alert and enable notification sound
  completionHandler((UNNotificationPresentationOptionSound
                     | UNNotificationPresentationOptionAlert ));
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
  if ([[FBSDKApplicationDelegate sharedInstance] application:application openURL:url options:options]) {
    return YES;
  }
  
  if ([RNGoogleSignin application:application openURL:url options:options]) {
    return YES;
  }
  
  if ([RCTLinkingManager application:application openURL:url options:options]) {
    return YES;
  }
  
  return NO;
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(nonnull NSUserActivity *)userActivity
 restorationHandler:(nonnull void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler
{
  return [RCTLinkingManager application:application
                   continueUserActivity:userActivity
                     restorationHandler:restorationHandler];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

// https://github.com/zoontek/react-native-bootsplash#ios-1
- (UIView *)createRootViewWithBridge:(RCTBridge *)bridge
                          moduleName:(NSString *)moduleName
                           initProps:(NSDictionary *)initProps {
  UIView *rootView = [super createRootViewWithBridge:bridge
                                          moduleName:moduleName
                                           initProps:initProps];
  
  [RNBootSplash initWithStoryboard:@"LaunchScreen" rootView:rootView];
  
  return rootView;
}

- (void)flushKeychainOnReinstall {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if (![defaults boolForKey:@"keychainFlushedOnReinstall"]) {
    [defaults setBool:YES forKey:@"keychainFlushedOnReinstall"];
    [defaults synchronize];
    NSArray *secItemClasses = @[(__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecClassInternetPassword,
                                (__bridge id)kSecClassCertificate,
                                (__bridge id)kSecClassKey,
                                (__bridge id)kSecClassIdentity];
    for (id secItemClass in secItemClasses) {
      NSDictionary *spec = @{(__bridge id)kSecClass: secItemClass};
      SecItemDelete((__bridge CFDictionaryRef)spec);
    }
  }
}

- (void)configureFirebase {
  [FIRApp configure];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if (![defaults boolForKey:@"notFirstFirebaseConfigure"]) {
    [defaults setBool:YES forKey:@"notFirstFirebaseConfigure"];
    [defaults synchronize];
    [[FIRAuth auth] signOut:NULL];
  }
}

- (void)configureMoengage:(NSDictionary *)launchOptions {
  NSString *moeAppId = [RNCConfig envFor:@"MO_ENGAGE_APP_ID"];
  NSString *moeDomain = [RNCConfig envFor:@"MO_ENGAGE_APP_DOMAIN"];
  MoEngageSDKConfig* sdkConfig = [[MoEngageSDKConfig alloc] initWithAppID:moeAppId];
  if ([moeDomain isEqualToString:@"DATA_CENTER_01"]) {
    sdkConfig.moeDataCenter = MoEngageDataCenterData_center_01;
  } else if ([moeDomain isEqualToString:@"DATA_CENTER_02"]) {
    sdkConfig.moeDataCenter = MoEngageDataCenterData_center_02;
  } else if ([moeDomain isEqualToString:@"DATA_CENTER_03"]) {
    sdkConfig.moeDataCenter = MoEngageDataCenterData_center_03;
  }
  sdkConfig.appGroupID = @"group.io.ice";
  sdkConfig.enableLogs = false;
  [[MoEngageInitializer sharedInstance] initializeDefaultSDKConfig:sdkConfig andLaunchOptions:launchOptions];
  
  // Check if the app was launched from a notification
  if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]) {
    NSDictionary *notificationPayload = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (notificationPayload[@"app_extra"][@"moe_deeplink"]) {
      self.moeDeeplink = notificationPayload[@"app_extra"][@"moe_deeplink"];
    }
  }
}

@end
