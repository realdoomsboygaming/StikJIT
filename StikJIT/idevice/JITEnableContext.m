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

- (void)setConnectionMode:(int)mode {
    connectionMode = (mode == 0) ? ConnectionModeUSB : ConnectionModeTCP;
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

// apps may have different name, so we must use BundleId as key. [bundleId:name]
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

// Simplified method for getting apps without explicit error handling
- (NSDictionary<NSString*, NSString*>*)getAppsSimple {
    NSError *error = nil;
    NSDictionary<NSString*, NSString*>* apps = [self getAppListWithError:&error];
    
    if (error) {
        NSLog(@"Error getting apps: %@", error);
        return @{};
    }
    
    return apps ?: @{};
}

// Deallocation logic remains the same
- (void)dealloc {
    self->heartbeatSessionId = arc4random();
    if(provider) {
        tcp_provider_free(provider);
    }
}
@end
