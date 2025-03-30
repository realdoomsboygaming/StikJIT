//
//  applist.c
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

#include "idevice.h"
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#include "applist.h"

// New function to list apps over USB with less restrictive filtering
NSDictionary<NSString*, NSString*>* list_installed_apps_usb(UsbmuxdAddrHandle* addr, NSString** error) {
    IdeviceErrorCode err = IdeviceSuccess;
    
    // Create USB provider
    UsbmuxdProviderHandle *provider = NULL;
    // Using 0 for device_id when UDID is empty string to avoid any issues
    err = usbmuxd_provider_new(addr, 1, "", 0, "StikJIT", &provider);
    if (err != IdeviceSuccess) {
        *error = @"Failed to create USB provider";
        return nil;
    }

    // Connect to installation proxy over USB
    InstallationProxyClientHandle *client = NULL;
    err = installation_proxy_connect_usbmuxd(provider, &client);
    if (err != IdeviceSuccess) {
        usbmuxd_provider_free(provider);
        *error = @"Failed to connect to installation proxy over USB";
        return nil;
    }

    void *apps = NULL;
    size_t apps_len = 0;
    
    // Get User applications instead of "Any" to focus on user apps
    err = installation_proxy_get_apps(client, "User", NULL, 0, &apps, &apps_len);
    if (err != IdeviceSuccess) {
        installation_proxy_client_free(client);
        usbmuxd_provider_free(provider);
        *error = @"Failed to get apps over USB";
        return nil;
    }

    plist_t *app_list = (plist_t *)apps;
    
    NSMutableDictionary<NSString*, NSString*>* ans = [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString*, NSString*>* fallbackApps = [[NSMutableDictionary alloc] init];
    
    for (size_t i = 0; i < apps_len; i++) {
        plist_t app = app_list[i];
        
        // Get the bundle identifier regardless of entitlements
        plist_t bundle_id_node = plist_dict_get_item(app, "CFBundleIdentifier");
        if (bundle_id_node) {
            char *bundle_id = NULL;
            plist_get_string_val(bundle_id_node, &bundle_id);
            
            // Skip if bundle ID is empty
            if (bundle_id == NULL || strlen(bundle_id) == 0) {
                free(bundle_id);
                continue;
            }
            
            // Get the app name
            plist_t app_name_node = plist_dict_get_item(app, "CFBundleName");
            char *app_name = NULL;
            if (app_name_node) {
                plist_get_string_val(app_name_node, &app_name);
            } else {
                // If CFBundleName is missing, try CFBundleDisplayName
                plist_t display_name_node = plist_dict_get_item(app, "CFBundleDisplayName");
                if (display_name_node) {
                    plist_get_string_val(display_name_node, &app_name);
                }
                
                // If still no name, use a default
                if (app_name == NULL) {
                    app_name = strdup("Unknown");
                }
            }

            NSString *bundleIDStr = [NSString stringWithCString:bundle_id encoding:NSASCIIStringEncoding];
            NSString *appNameStr = [NSString stringWithCString:app_name encoding:NSASCIIStringEncoding];
            
            // Now check for entitlements - prioritize apps with get-task-allow
            plist_t entitlements = plist_dict_get_item(app, "Entitlements");
            if (entitlements) {
                plist_t taskAllowNode = plist_dict_get_item(entitlements, "get-task-allow");
                if (taskAllowNode) {
                    uint8_t isAllowed = 0;
                    plist_get_bool_val(taskAllowNode, &isAllowed);
                    if (isAllowed) {
                        // This is a JIT-capable app, add it to our main dictionary
                        ans[bundleIDStr] = appNameStr;
                    } else {
                        // Not JIT-capable, add to fallback dictionary
                        fallbackApps[bundleIDStr] = appNameStr;
                    }
                } else {
                    // No get-task-allow node, add to fallback
                    fallbackApps[bundleIDStr] = appNameStr;
                }
            } else {
                // No entitlements, add to fallback
                fallbackApps[bundleIDStr] = appNameStr;
            }
            
            free(bundle_id);
            free(app_name);
        }
    }
    
    installation_proxy_client_free(client);
    usbmuxd_provider_free(provider);
    
    // If we found JIT-capable apps, return those
    if (ans.count > 0) {
        return ans;
    }
    
    // Otherwise, use the fallback list (all apps)
    // Only include some common development apps in the fallback
    NSMutableDictionary<NSString*, NSString*>* filteredFallback = [[NSMutableDictionary alloc] init];
    NSArray* knownDevApps = @[
        @"com.apple.TestFlight",
        @"com.apple.Playground",
        @"com.apple.dt.",  // Prefix for Apple dev tools
        @"org.webkit.",    // WebKit-based apps
        @"com.blackcats.alpha", // Unity-based apps (example)
        @"com.unity.",     // Unity apps
        @"com.yourcompany." // Default Xcode app prefix
    ];
    
    // Filter to only include apps likely to need JIT
    for (NSString* bundleID in fallbackApps) {
        for (NSString* prefix in knownDevApps) {
            if ([bundleID hasPrefix:prefix]) {
                filteredFallback[bundleID] = fallbackApps[bundleID];
                break;
            }
        }
    }
    
    // If we have filtered apps, return those
    if (filteredFallback.count > 0) {
        return filteredFallback;
    }
    
    // Last resort: return all apps
    return fallbackApps;
}

// Original function updated with same improvements
NSDictionary<NSString*, NSString*>* list_installed_apps(TcpProviderHandle* provider, NSString** error) {
    IdeviceErrorCode err = IdeviceSuccess;

    InstallationProxyClientHandle *client = NULL;
    err = installation_proxy_connect_tcp(provider, &client);
    if (err != IdeviceSuccess) {
        *error = @"Failed to connect to installation proxy";
        return nil;
    }

    void *apps = NULL;
    size_t apps_len = 0;
    err = installation_proxy_get_apps(client, "User", NULL, 0, &apps, &apps_len);
    if (err != IdeviceSuccess) {
        installation_proxy_client_free(client);
        *error = @"Failed to get apps";
        return nil;
    }

    plist_t *app_list = (plist_t *)apps;
    
    NSMutableDictionary<NSString*, NSString*>* ans = [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString*, NSString*>* fallbackApps = [[NSMutableDictionary alloc] init];
    
    for (size_t i = 0; i < apps_len; i++) {
        plist_t app = app_list[i];
        
        // Get the bundle identifier regardless of entitlements
        plist_t bundle_id_node = plist_dict_get_item(app, "CFBundleIdentifier");
        if (bundle_id_node) {
            char *bundle_id = NULL;
            plist_get_string_val(bundle_id_node, &bundle_id);
            
            // Skip if bundle ID is empty
            if (bundle_id == NULL || strlen(bundle_id) == 0) {
                free(bundle_id);
                continue;
            }
            
            // Get the app name
            plist_t app_name_node = plist_dict_get_item(app, "CFBundleName");
            char *app_name = NULL;
            if (app_name_node) {
                plist_get_string_val(app_name_node, &app_name);
            } else {
                // If CFBundleName is missing, try CFBundleDisplayName
                plist_t display_name_node = plist_dict_get_item(app, "CFBundleDisplayName");
                if (display_name_node) {
                    plist_get_string_val(display_name_node, &app_name);
                }
                
                // If still no name, use a default
                if (app_name == NULL) {
                    app_name = strdup("Unknown");
                }
            }

            NSString *bundleIDStr = [NSString stringWithCString:bundle_id encoding:NSASCIIStringEncoding];
            NSString *appNameStr = [NSString stringWithCString:app_name encoding:NSASCIIStringEncoding];
            
            // Now check for entitlements - prioritize apps with get-task-allow
            plist_t entitlements = plist_dict_get_item(app, "Entitlements");
            if (entitlements) {
                plist_t taskAllowNode = plist_dict_get_item(entitlements, "get-task-allow");
                if (taskAllowNode) {
                    uint8_t isAllowed = 0;
                    plist_get_bool_val(taskAllowNode, &isAllowed);
                    if (isAllowed) {
                        // This is a JIT-capable app, add it to our main dictionary
                        ans[bundleIDStr] = appNameStr;
                    } else {
                        // Not JIT-capable, add to fallback dictionary
                        fallbackApps[bundleIDStr] = appNameStr;
                    }
                } else {
                    // No get-task-allow node, add to fallback
                    fallbackApps[bundleIDStr] = appNameStr;
                }
            } else {
                // No entitlements, add to fallback
                fallbackApps[bundleIDStr] = appNameStr;
            }
            
            free(bundle_id);
            free(app_name);
        }
    }
    
    installation_proxy_client_free(client);
    
    // If we found JIT-capable apps, return those
    if (ans.count > 0) {
        return ans;
    }
    
    // Otherwise, use the fallback list (all apps)
    // Only include some common development apps in the fallback
    NSMutableDictionary<NSString*, NSString*>* filteredFallback = [[NSMutableDictionary alloc] init];
    NSArray* knownDevApps = @[
        @"com.apple.TestFlight",
        @"com.apple.Playground",
        @"com.apple.dt.",  // Prefix for Apple dev tools
        @"org.webkit.",    // WebKit-based apps
        @"com.blackcats.alpha", // Unity-based apps (example)
        @"com.unity.",     // Unity apps
        @"com.yourcompany." // Default Xcode app prefix
    ];
    
    // Filter to only include apps likely to need JIT
    for (NSString* bundleID in fallbackApps) {
        for (NSString* prefix in knownDevApps) {
            if ([bundleID hasPrefix:prefix]) {
                filteredFallback[bundleID] = fallbackApps[bundleID];
                break;
            }
        }
    }
    
    // If we have filtered apps, return those
    if (filteredFallback.count > 0) {
        return filteredFallback;
    }
    
    // Last resort: return all apps
    return fallbackApps;
}
