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
- (void)startHeartbeatWithCompletionHandler:(HeartbeatCompletionHandler)completionHandler logger:(LogFunc)logger;
- (void)debugAppWithBundleID:(NSString*)bundleID logger:(LogFunc)logger;
- (NSDictionary<NSString*, NSString*>*)getAppListWithError:(NSError**)error;

// Updated method to set the connection mode using just an integer value
- (void)setConnectionMode:(int)mode;

// New simple method that handles its own error handling
- (NSDictionary<NSString*, NSString*>*)getAppsSimple;
@end

#endif /* JITENABLECONTEXT_H */
