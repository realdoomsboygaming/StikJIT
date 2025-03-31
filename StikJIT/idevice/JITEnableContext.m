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
    // Create a timestamp for the log
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss.SSS"];
    NSString *timestamp = [dateFormatter stringFromDate:[NSDate date]];
    
    // Log detailed information about the heartbeat attempt
    NSString *modeString = (connectionMode == ConnectionModeUSB) ? @"USB" : @"TCP/WiFi";
    [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"[%@] 💓 HEARTBEAT: Initializing heartbeat connection in %@ mode", timestamp, modeString]];
    
    // Add additional context about the connection mode
    if (connectionMode == ConnectionModeUSB) {
        [[LogManagerBridge shared] addInfoLog:@"💡 USB mode requires a physical connection via USB cable"];
        [[LogManagerBridge shared] addInfoLog:@"💡 Make sure your device is connected and trusted"];
    } else {
        [[LogManagerBridge shared] addInfoLog:@"💡 WiFi mode requires an active WireGuard connection"];
        [[LogManagerBridge shared] addInfoLog:@"💡 Make sure WireGuard is connected to your device network"];
    }
    
    // Check for pairing file
    NSError* err = nil;
    IdevicePairingFile* pairingFile = [self getPairingFileWithError:&err];
    if(err) {
        NSString *errorMsg = [NSString stringWithFormat:@"⛔ ERROR: Failed to read pairing file: %@", err.localizedDescription];
        [[LogManagerBridge shared] addErrorLog:errorMsg];
        [[LogManagerBridge shared] addErrorLog:@"⛔ Please import a valid pairing file in Settings"];
        
        if(logger) {
            logger(errorMsg);
        }
        completionHandler(-17, err.localizedDescription);
        return;
    }
    
    [[LogManagerBridge shared] addInfoLog:@"✓ Pairing file loaded successfully"];
    
    // Generate a new random session ID for this heartbeat attempt
    self->heartbeatSessionId = arc4random();
    [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"✓ Created new heartbeat session with ID: %d", self->heartbeatSessionId]];
    
    // Create a more detailed completion block with timestamps and detailed messages
    HeartbeatCompletionHandlerC detailedCompletionHandler = ^(int result, const char *message) {
        NSString *resultMessage = [NSString stringWithCString:message encoding:NSASCIIStringEncoding];
        NSString *timestamp = [dateFormatter stringFromDate:[NSDate date]];
        
        if (result == 0) {
            [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"[%@] ✅ HEARTBEAT SUCCESS: %@", timestamp, resultMessage]];
        } else {
            [[LogManagerBridge shared] addErrorLog:[NSString stringWithFormat:@"[%@] ❌ HEARTBEAT FAILURE: %@ (Code: %d)", timestamp, resultMessage, result]];
            
            // Add troubleshooting advice
            if (connectionMode == ConnectionModeUSB) {
                [[LogManagerBridge shared] addWarningLog:@"⚠️ Try unplugging and reconnecting your device"];
                [[LogManagerBridge shared] addWarningLog:@"⚠️ Make sure your device is unlocked and trusted"];
                [[LogManagerBridge shared] addWarningLog:@"⚠️ Consider trying WiFi mode in Settings if USB isn't working"];
            } else {
                [[LogManagerBridge shared] addWarningLog:@"⚠️ Check that WireGuard is properly connected"];
                [[LogManagerBridge shared] addWarningLog:@"⚠️ Make sure your device is on the same network"];
                [[LogManagerBridge shared] addWarningLog:@"⚠️ Consider trying USB mode in Settings if WiFi isn't working"];
            }
        }
        
        completionHandler(result, resultMessage);
    };
    
    // Start the heartbeat process with improved logging
    [[LogManagerBridge shared] addInfoLog:@"▶️ Starting heartbeat connection process..."];
    startHeartbeat(pairingFile, &(self->provider), &(self->heartbeatSessionId), detailedCompletionHandler, [self createCLogger:logger], connectionMode);
}

- (void)debugAppWithBundleID:(NSString*)bundleID logger:(LogFunc)logger {
    LogFuncC cLogger = [self createCLogger:logger];
    
    // Log detailed info about the JIT debugging session
    cLogger("========== JIT DEBUGGING SESSION START ==========");
    cLogger("📱 App Bundle ID: %s", [bundleID UTF8String]);
    cLogger("⚡ Connection Mode: %s", (connectionMode == ConnectionModeUSB) ? "USB" : "TCP/WiFi");
    cLogger("⏱ Session Time: %s", [[[NSDateFormatter new] stringFromDate:[NSDate date]] UTF8String]);
    
    // Check if bundle ID is valid
    if (bundleID.length == 0) {
        cLogger("❌ ERROR: Invalid bundle ID - empty string provided");
        cLogger("❌ Please select a valid application to enable JIT");
        cLogger("========== JIT DEBUGGING SESSION FAILED ==========");
        return;
    }
    
    cLogger("🔍 Starting JIT enabling process for: %s", [bundleID UTF8String]);
    
    if(connectionMode == ConnectionModeUSB) {
        // USB mode
        cLogger("🔌 USB MODE: Setting up physical USB connection for debugging");
        cLogger("🔄 Creating connection to usbmuxd service...");
        
        // Create USB address handle
        UsbmuxdAddrHandle* addr = NULL;
        IdeviceErrorCode err = idevice_usbmuxd_unix_addr_new("/var/run/usbmuxd", &addr);
        if (err != IdeviceSuccess) {
            cLogger("❌ ERROR: Failed to create usbmuxd address (error: %d)", err);
            cLogger("❌ USB connection failed - cannot communicate with device");
            cLogger("💡 TIPS: Make sure your device is:");
            cLogger("   - Connected via USB cable");
            cLogger("   - Unlocked and trusted on this computer");
            cLogger("   - Not in use by another app");
            cLogger("   - Try switching to WiFi mode in Settings");
            cLogger("========== JIT DEBUGGING SESSION FAILED ==========");
            return;
        }
        
        cLogger("✅ USB connection established successfully");
        cLogger("🚀 Starting USB debug session for app: %s", [bundleID UTF8String]);
        
        // Debug the app using USB mode
        int result = debug_app_usb(addr, [bundleID UTF8String], cLogger);
        
        // Clean up
        idevice_usbmuxd_addr_free(addr);
        
        if (result == 0) {
            cLogger("🎉 SUCCESS: JIT debugging enabled via USB for %s", [bundleID UTF8String]);
        } else {
            cLogger("❌ ERROR: JIT debugging failed with code: %d", result);
        }
    } else {
        // TCP/WiFi mode
        cLogger("🌐 WIFI MODE: Setting up network connection for debugging");
        
        if(!provider) {
            cLogger("❌ ERROR: TCP Provider not initialized!");
            cLogger("❌ No active network connection to device");
            cLogger("💡 TIPS:");
            cLogger("   - Make sure WireGuard is connected");
            cLogger("   - Try restarting the app");
            cLogger("   - Consider switching to USB mode in Settings");
            cLogger("========== JIT DEBUGGING SESSION FAILED ==========");
            return;
        }
        
        cLogger("✅ WiFi connection is active");
        cLogger("🚀 Starting TCP debug session for app: %s", [bundleID UTF8String]);
        
        // Debug the app using TCP mode
        int result = debug_app(provider, [bundleID UTF8String], cLogger);
        
        if (result == 0) {
            cLogger("🎉 SUCCESS: JIT debugging enabled via WiFi for %s", [bundleID UTF8String]);
        } else {
            cLogger("❌ ERROR: JIT debugging failed with code: %d", result);
        }
    }
    
    cLogger("========== JIT DEBUGGING SESSION COMPLETE ==========");
}

- (NSDictionary<NSString*, NSString*>*)getAppListWithError:(NSError**)error {
    // Create timestamp for logs
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss.SSS"];
    NSString *timestamp = [dateFormatter stringFromDate:[NSDate date]];
    
    NSString *modeString = (connectionMode == ConnectionModeUSB) ? @"USB" : @"TCP/WiFi";
    [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"[%@] 📱 Scanning for installed apps using %@ connection", timestamp, modeString]];
    
    if(connectionMode == ConnectionModeUSB) {
        // USB mode - create a direct USB connection for app listing
        [[LogManagerBridge shared] addInfoLog:@"🔌 Using USB connection to discover apps"];
        [[LogManagerBridge shared] addInfoLog:@"🔍 Connecting to usbmuxd service..."];
        
        UsbmuxdAddrHandle* addr = NULL;
        IdeviceErrorCode err = idevice_usbmuxd_unix_addr_new("/var/run/usbmuxd", &addr);
        if(err != IdeviceSuccess) {
            NSString* errorMsg = [NSString stringWithFormat:@"⛔ Failed to create usbmuxd address: %d", err];
            [[LogManagerBridge shared] addErrorLog:errorMsg];
            [[LogManagerBridge shared] addErrorLog:@"⛔ Unable to connect to USB service - device may not be connected properly"];
            
            *error = [self errorWithStr:errorMsg code:err];
            return nil;
        }
        
        [[LogManagerBridge shared] addInfoLog:@"✓ Connected to usbmuxd service successfully"];
        [[LogManagerBridge shared] addInfoLog:@"🔍 Requesting installed apps from device..."];
        
        NSString* errorStr = nil;
        NSDictionary<NSString*, NSString*>* apps = list_installed_apps_usb(addr, &errorStr);
        
        // Clean up resources
        idevice_usbmuxd_addr_free(addr);
        
        if(errorStr) {
            NSString* errorMsg = [NSString stringWithFormat:@"⛔ Failed to get app list via USB: %@", errorStr];
            [[LogManagerBridge shared] addErrorLog:errorMsg];
            [[LogManagerBridge shared] addWarningLog:@"⚠️ Try reconnecting your device or switching to WiFi mode"];
            *error = [self errorWithStr:errorStr code:-17];
            return nil;
        } else {
            if (apps.count > 0) {
                [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"✅ Successfully discovered %lu apps via USB connection", (unsigned long)apps.count]];
                
                // Log sample of found apps (up to 3)
                NSArray *appIds = [apps allKeys];
                if (appIds.count > 0) {
                    NSMutableString *sampleApps = [NSMutableString string];
                    int sampleCount = MIN(3, (int)appIds.count);
                    for (int i = 0; i < sampleCount; i++) {
                        [sampleApps appendFormat:@"%@%@", appIds[i], (i < sampleCount-1) ? @", " : @""];
                    }
                    [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"📱 Sample apps: %@%@", 
                                                         sampleApps, 
                                                         (appIds.count > 3) ? @"..." : @""]];
                }
            } else {
                [[LogManagerBridge shared] addWarningLog:@"⚠️ No apps with get-task-allow entitlement found via USB"];
                [[LogManagerBridge shared] addWarningLog:@"⚠️ Make sure you have development apps installed"];
            }
            return apps;
        }
    } else {
        // TCP mode - use the existing provider
        [[LogManagerBridge shared] addInfoLog:@"🌐 Using WiFi/TCP connection to discover apps"];
        
        if(!provider) {
            NSString *errorMsg = @"⛔ TCP Provider not initialized - no active WiFi connection!";
            [[LogManagerBridge shared] addErrorLog:errorMsg];
            [[LogManagerBridge shared] addErrorLog:@"⛔ Heartbeat connection has not been established"];
            [[LogManagerBridge shared] addWarningLog:@"⚠️ Try restarting the app or switching to USB mode"];
            
            *error = [self errorWithStr:@"TCP Provider not initialized!" code:-1];
            return nil;
        }
        
        [[LogManagerBridge shared] addInfoLog:@"🔍 Requesting installed apps over TCP/WiFi..."];
        
        NSString* errorStr = nil;
        NSDictionary<NSString*, NSString*>* apps = list_installed_apps(provider, &errorStr);
        
        if(errorStr) {
            NSString* errorMsg = [NSString stringWithFormat:@"⛔ Failed to get app list via WiFi: %@", errorStr];
            [[LogManagerBridge shared] addErrorLog:errorMsg];
            [[LogManagerBridge shared] addWarningLog:@"⚠️ Check that WireGuard is connected or try USB mode"];
            *error = [self errorWithStr:errorStr code:-17];
            return nil;
        } else {
            if (apps.count > 0) {
                [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"✅ Successfully discovered %lu apps via WiFi connection", (unsigned long)apps.count]];
                
                // Log sample of found apps (up to 3)
                NSArray *appIds = [apps allKeys];
                if (appIds.count > 0) {
                    NSMutableString *sampleApps = [NSMutableString string];
                    int sampleCount = MIN(3, (int)appIds.count);
                    for (int i = 0; i < sampleCount; i++) {
                        [sampleApps appendFormat:@"%@%@", appIds[i], (i < sampleCount-1) ? @", " : @""];
                    }
                    [[LogManagerBridge shared] addInfoLog:[NSString stringWithFormat:@"📱 Sample apps: %@%@", 
                                                         sampleApps, 
                                                         (appIds.count > 3) ? @"..." : @""]];
                }
            } else {
                [[LogManagerBridge shared] addWarningLog:@"⚠️ No apps with get-task-allow entitlement found via WiFi"];
                [[LogManagerBridge shared] addWarningLog:@"⚠️ Make sure you have development apps installed"];
            }
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
