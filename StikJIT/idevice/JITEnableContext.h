//
//  JITEnableContext.h
//  StikJIT
//
//  Created by s s on 2025/3/28.
//
#ifndef JITENABLECONTEXT_H
#define JITENABLECONTEXT_H

@import Foundation;
#include "idevice.h"
#include "heartbeat.h"

typedef void (^HeartbeatCompletionHandler)(int result, NSString *message);
typedef void (^LogFuncC)(const char* message, ...);
typedef void (^LogFunc)(NSString *message);

// Make sure this enum name doesn't conflict with Swift's enum
typedef NS_ENUM(NSInteger, ConnectionMode_objc) {
    ConnectionMode_objc_USB = 0,
    ConnectionMode_objc_TCP = 1
};

@interface JITEnableContext : NSObject
+ (instancetype)shared;
- (IdevicePairingFile*)getPairingFileWithError:(NSError**)error;

// Start heartbeat with current connection mode
- (void)startHeartbeatWithCompletionHandler:(HeartbeatCompletionHandler)completionHandler logger:(LogFunc)logger;

// Debug app with current connection mode
- (void)debugAppWithBundleID:(NSString*)bundleID logger:(LogFunc)logger;

// Get app list with error handling - respects connection mode
- (NSDictionary<NSString*, NSString*>*)getAppListWithError:(NSError**)error;

// Set the connection mode (0=USB, 1=TCP)
- (void)setConnectionMode:(int)mode;

// Simple method that handles its own error handling and returns empty dict on failure
- (NSDictionary<NSString*, NSString*>*)getAppsSimple;
@end

#endif /* JITENABLECONTEXT_H */
