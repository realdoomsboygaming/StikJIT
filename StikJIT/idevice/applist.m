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

// New function to list apps over USB with simpler filtering
NSDictionary<NSString*, NSString*>* list_installed_apps_usb(UsbmuxdAddrHandle* addr, NSString** error) {
    IdeviceErrorCode err = IdeviceSuccess;
    
    // Create USB provider
    UsbmuxdProviderHandle *provider = NULL;
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
    
    // Get all User applications
    err = installation_proxy_get_apps(client, "User", NULL, 0, &apps, &apps_len);
    if (err != IdeviceSuccess) {
        installation_proxy_client_free(client);
        usbmuxd_provider_free(provider);
        *error = @"Failed to get apps over USB";
        return nil;
    }

    plist_t *app_list = (plist_t *)apps;
    
    NSMutableDictionary<NSString*, NSString*>* ans = [[NSMutableDictionary alloc] init];
    
    for (size_t i = 0; i < apps_len; i++) {
        plist_t app = app_list[i];
        
        // Get the bundle identifier
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
                
                // If still no name, use the bundle ID
                if (app_name == NULL) {
                    app_name = strdup(bundle_id);
                }
            }

            NSString *bundleIDStr = [NSString stringWithCString:bundle_id encoding:NSASCIIStringEncoding];
            NSString *appNameStr = [NSString stringWithCString:app_name encoding:NSASCIIStringEncoding];
            
            // Add all apps to the dictionary
            ans[bundleIDStr] = appNameStr;
            
            free(bundle_id);
            free(app_name);
        }
    }
    
    installation_proxy_client_free(client);
    usbmuxd_provider_free(provider);
    
    return ans;
}

// Original function updated with similar simpler approach
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
    
    for (size_t i = 0; i < apps_len; i++) {
        plist_t app = app_list[i];
        
        // Get the bundle identifier
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
                
                // If still no name, use the bundle ID
                if (app_name == NULL) {
                    app_name = strdup(bundle_id);
                }
            }

            NSString *bundleIDStr = [NSString stringWithCString:bundle_id encoding:NSASCIIStringEncoding];
            NSString *appNameStr = [NSString stringWithCString:app_name encoding:NSASCIIStringEncoding];
            
            // Add all apps to the dictionary
            ans[bundleIDStr] = appNameStr;
            
            free(bundle_id);
            free(app_name);
        }
    }
    
    installation_proxy_client_free(client);
    
    return ans;
}
