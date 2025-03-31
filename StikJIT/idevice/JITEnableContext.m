// JITEnableContext.m Fix

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
    UsbmuxdAddrHandle* usb_addr;
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
        usb_addr = NULL;
        provider = NULL;
    }
    return self;
}

- (void)setConnectionMode:(int)mode {
    connectionMode = (mode == 0) ? ConnectionModeUSB : ConnectionModeTCP;
    
    // Log the mode change
    [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"Connection mode set to: %@", 
                                          (connectionMode == ConnectionModeUSB) ? @"USB" : @"TCP/WiFi"]];
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
        return NULL;
    }
        
    IdevicePairingFile* pairingFile = NULL;
    IdeviceErrorCode err = idevice_pairing_file_read(pairingFileURL.fileSystemRepresentation, &pairingFile);
    if (err != IdeviceSuccess) {
        *error = [self errorWithStr:@"Failed to read pairing file!" code:err];
        return NULL;
    }
    return pairingFile;
}

- (void)startHeartbeatWithCompletionHandler:(HeartbeatCompletionHandler)completionHandler logger:(LogFunc)logger {
    [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"Starting heartbeat in %@ mode", 
                                         (connectionMode == ConnectionModeUSB) ? @"USB" : @"TCP/WiFi"]];
    
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
    
    // Make sure to pass the connection mode to startHeartbeat
    startHeartbeat(pairingFile, &(self->provider), &(self->heartbeatSessionId), ^(int result, const char *message) {
        completionHandler(result,[NSString stringWithCString:message encoding:NSASCIIStringEncoding]);
    }, [self createCLogger:logger], connectionMode);
}

- (void)debugAppWithBundleID:(NSString*)bundleID logger:(LogFunc)logger {
    LogFuncC cLogger = [self createCLogger:logger];
    
    // Log which mode we're using
    cLogger("Using %s mode for debugging", (connectionMode == ConnectionModeUSB) ? "USB" : "TCP/WiFi");
    
    if(connectionMode == ConnectionModeUSB) {
        // USB mode
        cLogger("Setting up USB connection for debugging");
        
        // Create USB address handle
        UsbmuxdAddrHandle* addr = NULL;
        IdeviceErrorCode err = idevice_usbmuxd_unix_addr_new("/var/run/usbmuxd", &addr);
        if (err != IdeviceSuccess) {
            cLogger("Failed to create usbmuxd address: %d", err);
            return;
        }
        
        // Debug the app using USB mode
        debug_app_usb(addr, [bundleID UTF8String], cLogger);
        
        // Clean up
        idevice_usbmuxd_addr_free(addr);
    } else {
        // TCP/WiFi mode
        if(!provider) {
            cLogger("TCP Provider not initialized!");
            return;
        }
        
        // Debug the app using TCP mode
        debug_app(provider, [bundleID UTF8String], cLogger);
    }
}

- (NSDictionary<NSString*, NSString*>*)getAppListWithError:(NSError**)error {
    [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"Getting app list in %@ mode", 
                                         (connectionMode == ConnectionModeUSB) ? @"USB" : @"TCP/WiFi"]];
    
    if(connectionMode == ConnectionModeUSB) {
        // USB mode - create a direct USB connection for app listing
        UsbmuxdAddrHandle* addr = NULL;
        IdeviceErrorCode err = idevice_usbmuxd_unix_addr_new("/var/run/usbmuxd", &addr);
        if(err != IdeviceSuccess) {
            NSString* errorMsg = [NSString stringWithFormat:@"Failed to create usbmuxd address: %d", err];
            *error = [self errorWithStr:errorMsg code:err];
            return nil;
        }
        
        NSString* errorStr = nil;
        NSDictionary<NSString*, NSString*>* apps = list_installed_apps_usb(addr, &errorStr);
        
        // Clean up
        idevice_usbmuxd_addr_free(addr);
        
        if(errorStr) {
            *error = [self errorWithStr:errorStr code:-17];
            return nil;
        } else {
            return apps;
        }
    } else {
        // TCP mode - use the existing provider
        if(!provider) {
            *error = [self errorWithStr:@"TCP Provider not initialized!" code:-1];
            return nil;
        }
        
        NSString* errorStr = nil;
        NSDictionary<NSString*, NSString*>* apps = list_installed_apps(provider, &errorStr);
        
        if(errorStr) {
            *error = [self errorWithStr:errorStr code:-17];
            return nil;
        } else {
            return apps;
        }
    }
}

- (NSDictionary<NSString*, NSString*>*)getAppsSimple {
    NSError* error = nil;
    NSDictionary<NSString*, NSString*>* apps = [self getAppListWithError:&error];
    
    if(error) {
        [[LogManagerBridge shared] addErrorLog:[NSString stringWithFormat:@"Error getting apps: %@", error.localizedDescription]];
        return @{};
    }
    
    if(apps.count > 0) {
        [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"Found %lu apps", (unsigned long)apps.count]];
    } else {
        [[LogManagerBridge shared] addWarningLog:@"No apps found"];
    }
    
    return apps ?: @{};
}

- (void)dealloc {
    self->heartbeatSessionId = arc4random();
    
    if(provider) {
        tcp_provider_free(provider);
        provider = NULL;
    }
    
    if(usb_addr) {
        idevice_usbmuxd_addr_free(usb_addr);
        usb_addr = NULL;
    }
}

@end
