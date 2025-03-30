//
//  JITEnableContext.m
//  StikJIT
//
//  Created by s s on 2025/3/28.
//
#include "idevice.h"
#include <arpa/inet.h>
#include <stdlib.h>

#include "heartbeat.h"
#include "jit.h"
#include "applist.h"

#include "JITEnableContext.h"
#import "StikJIT-Swift.h"  // This imports the Swift files into Objective-C

JITEnableContext* sharedJITContext = nil;

@implementation JITEnableContext {
    int heartbeatSessionId;
    TcpProviderHandle* provider;
    UsbmuxdProviderHandle* usbProvider;
    ConnectionMode connectionMode;
}

+ (instancetype)shared {
    if(!sharedJITContext) {
        sharedJITContext = [[JITEnableContext alloc] init];
    }
    return sharedJITContext;
}

- (id)init {
    if (self = [super init]) {
        // Default to USB connection mode
        connectionMode = ConnectionModeUSB;
    }
    return self;
}

- (void)setConnectionMode:(ConnectionMode)mode {
    connectionMode = mode;
}

- (NSError*)errorWithStr:(NSString*)str code:(int)code {
    return [NSError errorWithDomain:@"StikJIT" code:code userInfo:@{NSLocalizedDescriptionKey: str}];
}

- (LogFuncC)createCLogger:(LogFunc)logger {
    return ^(const char* format, ...) {
        va_list args;
        va_start(args, format);
        NSString* formatStr = [NSString stringWithCString:format encoding:NSASCIIStringEncoding];
         
        NSString *message = [[NSString alloc] initWithFormat:formatStr arguments:args];
        NSLog(@"%@", message);
        
        // Add to log manager
        if ([message containsString:@"ERROR"] || [message containsString:@"Error"]) {
            [[LogManagerBridge shared] addErrorLog:message];
        } else if ([message containsString:@"WARNING"] || [message containsString:@"Warning"]) {
            [[LogManagerBridge shared] addWarningLog:message];
        } else if ([message containsString:@"DEBUG"]) {
            [[LogManagerBridge shared] addDebugLog:message];
        } else {
            [[LogManagerBridge shared] addInfoLog:message];
        }
        
        if(logger) {
            logger(message);
        }
        
        va_end(args);
    };
}

- (IdevicePairingFile*)getPairingFileWithError:(NSError**)error {
    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL* docPathUrl = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL* pairingFileURL = [docPathUrl URLByAppendingPathComponent:@"pairingFile.plist"];
    if(![fm fileExistsAtPath:pairingFileURL.path]) {
        NSLog(@"Pairing file not found!");
        *error = [self errorWithStr:@"Pairing file not found!" code:-17];
        return false;
    }
        
    IdevicePairingFile* pairingFile = NULL;
    IdeviceErrorCode err = idevice_pairing_file_read(pairingFileURL.fileSystemRepresentation, &pairingFile);
    if (err != IdeviceSuccess) {
        *error = [self errorWithStr:@"Failed to read pairing file!" code:err];
        return nil;
    }
    return pairingFile;
}

- (void)startHeartbeatWithCompletionHandler:(HeartbeatCompletionHandler)completionHandler logger:(LogFunc)logger {
    NSError* err = nil;
    IdevicePairingFile* pairingFile = [self getPairingFileWithError:&err];
    if(err) {
        if(logger) {
            logger(err.localizedDescription);
        }

        completionHandler(-17, err.localizedDescription);
        return;
    }
    self->heartbeatSessionId = arc4random();
    startHeartbeat(pairingFile, &(self->provider), &(self->heartbeatSessionId), ^(int result, const char *message) {
        completionHandler(result,[NSString stringWithCString:message encoding:NSASCIIStringEncoding]);
    }, [self createCLogger:logger], connectionMode);
}

- (void)debugAppWithBundleID:(NSString*)bundleID logger:(LogFunc)logger {
    if (connectionMode == ConnectionModeUSB) {
        // USB mode - create a direct USB connection for debugging
        logger(@"Setting up USB debugging connection");
        
        // Create a USB connection for debugging
        UsbmuxdAddrHandle *usb_addr = NULL;
        IdeviceErrorCode err = idevice_usbmuxd_unix_addr_new("/var/run/usbmuxd", &usb_addr);
        if (err != IdeviceSuccess) {
            logger([NSString stringWithFormat:@"Failed to create usbmuxd address: %d", err]);
            return;
        }
        
        // The actual debugging now uses direct USB
        debug_app_usb(usb_addr, [bundleID UTF8String], [self createCLogger:logger]);
        
        // Clean up
        idevice_usbmuxd_addr_free(usb_addr);
    } else {
        // TCP mode - use the existing provider
        if(!provider) {
            if(logger) {
                logger(@"TCP Provider not initialized!");
            }
            NSLog(@"TCP Provider not initialized!");
            return;
        }
        
        debug_app(provider, [bundleID UTF8String], [self createCLogger:logger]);
    }
}

// apps may have different name, so we must use BnudleId as key. [bundleId:name]
- (NSDictionary<NSString*, NSString*>*)getAppListWithError:(NSError**)error {
    if (connectionMode == ConnectionModeUSB) {
        // USB mode - create a direct USB connection for app listing
        NSLog(@"Setting up USB connection for app listing");
        
        UsbmuxdAddrHandle *usb_addr = NULL;
        IdeviceErrorCode err = idevice_usbmuxd_unix_addr_new("/var/run/usbmuxd", &usb_addr);
        if (err != IdeviceSuccess) {
            NSString *errorMsg = [NSString stringWithFormat:@"Failed to create usbmuxd address: %d", err];
            *error = [self errorWithStr:errorMsg code:err];
            return nil;
        }
        
        NSString* errorStr = nil;
        NSDictionary<NSString*, NSString*>* ans = list_installed_apps_usb(usb_addr, &errorStr);
        
        // Clean up
        idevice_usbmuxd_addr_free(usb_addr);
        
        if(errorStr){
            *error = [self errorWithStr:errorStr code:-17];
            return nil;
        } else {
            return ans;
        }
    } else {
        // TCP mode - use the existing provider
        if(!provider) {
            NSLog(@"TCP Provider not initialized!");
            *error = [self errorWithStr:@"TCP Provider not initialized!" code:-1];
            return nil;
        }
        
        NSString* errorStr = nil;
        NSDictionary<NSString*, NSString*>* ans = list_installed_apps(provider, &errorStr);
        if(errorStr){
            *error = [self errorWithStr:errorStr code:-17];
            return nil;
        } else {
            return ans;
        }
    }
}

- (void)dealloc {
    self->heartbeatSessionId = arc4random();
    if(provider) {
        tcp_provider_free(provider);
    }
}

@end
