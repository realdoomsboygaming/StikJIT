// Jackson Coxson
// heartbeat.c

#include "idevice.h"
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/_types/_u_int64_t.h>
#include <CoreFoundation/CoreFoundation.h>
#include <limits.h>
#include "heartbeat.h"

void startHeartbeat(IdevicePairingFile* pairing_file, TcpProviderHandle** provider, int* heartbeatSessionId, HeartbeatCompletionHandlerC completion, LogFuncC logger, ConnectionMode mode) {
    int currentSessionId = *heartbeatSessionId;
    logger("DEBUG: Initializing logger...");
    idevice_init_logger(Debug, Disabled, NULL);
    
    IdeviceErrorCode err = IdeviceSuccess;
    HeartbeatClientHandle *client = NULL;
    
    if (mode == ConnectionModeUSB) {
        // Use USB connection
        logger("DEBUG: Using USB connection mode");
        
        // Create a UsbmuxdAddrHandle for the standard usbmuxd socket
        UsbmuxdAddrHandle *usb_addr = NULL;
        err = idevice_usbmuxd_unix_addr_new("/var/run/usbmuxd", &usb_addr);
        if (err != IdeviceSuccess) {
            logger("DEBUG: Failed to create usbmuxd address: %d", err);
            completion(err, "Failed to create usbmuxd address");
            return;
        }
        
        // Create UsbmuxdProviderHandle
        UsbmuxdProviderHandle *usb_provider = NULL;
        err = usbmuxd_provider_new(usb_addr, 1, "", 0, "StikJIT", &usb_provider);
        if (err != IdeviceSuccess) {
            logger("DEBUG: Failed to create USB provider: %d", err);
            idevice_usbmuxd_addr_free(usb_addr);
            completion(err, "Failed to create USB provider");
            return;
        }
        
        // Connect to heartbeat service
        logger("DEBUG: Connecting to heartbeat over USB...");
        err = heartbeat_connect_usbmuxd(usb_provider, &client);
        if (err != IdeviceSuccess) {
            logger("DEBUG: Failed to connect to heartbeat over USB: %d", err);
            usbmuxd_provider_free(usb_provider);
            idevice_usbmuxd_addr_free(usb_addr);
            completion(err, "Failed to connect to heartbeat over USB");
            return;
        }
        
        logger("DEBUG: Connected to heartbeat over USB successfully.");
        completion(0, "Heartbeat over USB connected successfully");
        
        // Set provider to NULL since we can't use the USB provider for TCP functions
        *provider = NULL;
        logger("DEBUG: USB mode is used - TCP provider is NULL");
    }
    else {
        // Use TCP connection (original code)
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        if (inet_pton(AF_INET, "10.7.0.1", &addr.sin_addr) <= 0) {
            logger("DEBUG: Error converting IP address.");
            completion(-1, "Error converting IP address");
            return;
        }
        logger("DEBUG: Socket address created for IP 10.7.0.1");
        
        logger("DEBUG: Creating TCP provider...");
        err = idevice_tcp_provider_new((struct sockaddr *)&addr, pairing_file,
                                      "StikJIT", provider);
        if (err != IdeviceSuccess) {
            logger("DEBUG: Failed to create TCP provider: %d", err);
            completion(err, "Failed to create TCP provider");
            return;
        }
        logger("DEBUG: TCP provider created successfully.");
        
        logger("DEBUG: Connecting to heartbeat...");
        err = heartbeat_connect_tcp(*provider, &client);
        if (err != IdeviceSuccess) {
            completion(err, "Failed to connect to Heartbeat");
            logger("DEBUG: Failed to connect to heartbeat: %d", err);
            return;
        }
        logger("DEBUG: Connected to heartbeat successfully.");
        
        completion(0, "Heartbeat over TCP connected successfully");
    }
    
    // Heartbeat loop is the same for both connection modes
    u_int64_t current_interval = 15;
    while (1) {
        if(*heartbeatSessionId != currentSessionId) {
            break;
        }
        
        u_int64_t new_interval = 0;
        logger("DEBUG: Sending heartbeat with current interval: %llu seconds...", current_interval);
        err = heartbeat_get_marco(client, current_interval, &new_interval);
        if (err != IdeviceSuccess) {
            logger("DEBUG: Failed to get marco: %d", err);
            heartbeat_client_free(client);
            return;
        }
        logger("DEBUG: Received new interval: %llu seconds.", new_interval);
        current_interval = new_interval + 5;
        
        logger("DEBUG: Sending polo reply...");
        err = heartbeat_send_polo(client);
        if (err != IdeviceSuccess) {
            logger("DEBUG: Failed to send polo: %d", err);
            heartbeat_client_free(client);
            return;
        }
        logger("DEBUG: Polo reply sent successfully.");
    }
}
