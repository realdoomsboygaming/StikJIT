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
    logger("DEBUG: Initializing heartbeat with session ID: %d", currentSessionId);
    idevice_init_logger(Debug, Disabled, NULL);
    
    IdeviceErrorCode err = IdeviceSuccess;
    HeartbeatClientHandle *client = NULL;
    
    if (mode == ConnectionModeUSB) {
        // Use USB connection
        logger("HEARTBEAT: ⚡ Attempting to establish USB connection mode");
        
        // Create a UsbmuxdAddrHandle for the standard usbmuxd socket
        UsbmuxdAddrHandle *usb_addr = NULL;
        err = idevice_usbmuxd_unix_addr_new("/var/run/usbmuxd", &usb_addr);
        if (err != IdeviceSuccess) {
            logger("ERROR: 🔌 USB connection failed - could not create usbmuxd address (error: %d)", err);
            logger("ERROR: This usually means the USB connection to your device isn't working");
            logger("ERROR: Check that your device is connected and trusted");
            completion(err, "Failed to create usbmuxd address");
            return;
        }
        logger("HEARTBEAT: USB socket created successfully at /var/run/usbmuxd");
        
        // Create UsbmuxdProviderHandle
        UsbmuxdProviderHandle *usb_provider = NULL;
        err = usbmuxd_provider_new(usb_addr, 1, "", 0, "StikJIT", &usb_provider);
        if (err != IdeviceSuccess) {
            logger("ERROR: 🔌 USB provider creation failed (error: %d)", err);
            logger("ERROR: Could not initialize USB communication with the device");
            idevice_usbmuxd_addr_free(usb_addr);
            completion(err, "Failed to create USB provider");
            return;
        }
        logger("HEARTBEAT: USB provider successfully created");
        
        // Connect to heartbeat service
        logger("HEARTBEAT: Attempting to connect to heartbeat service over USB...");
        err = heartbeat_connect_usbmuxd(usb_provider, &client);
        if (err != IdeviceSuccess) {
            logger("ERROR: 💔 Failed to connect to heartbeat over USB (error: %d)", err);
            logger("ERROR: Device may not be properly paired or USB connection is unstable");
            logger("ERROR: Try reconnecting your device or restart the app");
            usbmuxd_provider_free(usb_provider);
            idevice_usbmuxd_addr_free(usb_addr);
            completion(err, "Failed to connect to heartbeat over USB");
            return;
        }
        
        logger("HEARTBEAT: ✅ Successfully connected to heartbeat service over USB");
        logger("HEARTBEAT: Device is responsive and communication established");
        completion(0, "Heartbeat over USB connected successfully");
        
        // Set provider to NULL since we can't use the USB provider for TCP functions
        *provider = NULL;
        logger("HEARTBEAT: USB mode is active - TCP provider is NULL by design");
    }
    else {
        // Use TCP connection (original code)
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        if (inet_pton(AF_INET, "10.7.0.1", &addr.sin_addr) <= 0) {
            logger("ERROR: 🌐 WiFi connection failed - Invalid IP address format");
            logger("ERROR: Could not convert '10.7.0.1' to a valid IP address");
            logger("ERROR: Check your WireGuard connection is active");
            completion(-1, "Error converting IP address");
            return;
        }
        logger("HEARTBEAT: 🌐 Socket address created for IP 10.7.0.1");
        
        logger("HEARTBEAT: Creating TCP provider for WiFi communication...");
        err = idevice_tcp_provider_new((struct sockaddr *)&addr, pairing_file,
                                      "StikJIT", provider);
        if (err != IdeviceSuccess) {
            logger("ERROR: 🌐 TCP provider creation failed (error: %d)", err);
            logger("ERROR: Unable to establish network communication with the device");
            logger("ERROR: Check that WireGuard is connected and running");
            completion(err, "Failed to create TCP provider");
            return;
        }
        logger("HEARTBEAT: TCP provider created successfully");
        
        logger("HEARTBEAT: Connecting to heartbeat service over WiFi...");
        err = heartbeat_connect_tcp(*provider, &client);
        if (err != IdeviceSuccess) {
            logger("ERROR: 💔 Failed to connect to heartbeat over WiFi (error: %d)", err);
            logger("ERROR: Cannot establish heartbeat with device");
            logger("ERROR: Check that WireGuard is properly configured and connected");
            completion(err, "Failed to connect to Heartbeat over WiFi");
            return;
        }
        logger("HEARTBEAT: ✅ Successfully connected to heartbeat service over WiFi");
        logger("HEARTBEAT: Network communication with device established");
        
        completion(0, "Heartbeat over WiFi connected successfully");
    }
    
    // Heartbeat loop is the same for both connection modes
    logger("HEARTBEAT: 💓 Starting heartbeat loop for continuous device connection");
    u_int64_t current_interval = 15;
    int heartbeat_count = 0;
    
    while (1) {
        if(*heartbeatSessionId != currentSessionId) {
            logger("HEARTBEAT: Session ID changed - terminating heartbeat loop");
            break;
        }
        
        u_int64_t new_interval = 0;
        logger("HEARTBEAT: Sending marco ping #%d (interval: %llu seconds)...", ++heartbeat_count, current_interval);
        err = heartbeat_get_marco(client, current_interval, &new_interval);
        if (err != IdeviceSuccess) {
            logger("ERROR: 💔 Heartbeat failure - marco request failed (error: %d)", err);
            logger("ERROR: Device may have disconnected or the connection was interrupted");
            logger("ERROR: Please check your device connection and restart the app");
            heartbeat_client_free(client);
            return;
        }
        logger("HEARTBEAT: ✓ Marco received (ping #%d) - Device responded", heartbeat_count);
        logger("HEARTBEAT: New requested interval: %llu seconds", new_interval);
        current_interval = new_interval + 5;
        
        logger("HEARTBEAT: Sending polo response...");
        err = heartbeat_send_polo(client);
        if (err != IdeviceSuccess) {
            logger("ERROR: 💔 Heartbeat failure - failed to send polo response (error: %d)", err);
            logger("ERROR: Connection to device lost during heartbeat exchange");
            logger("ERROR: Please check your device connection and restart the app");
            heartbeat_client_free(client);
            return;
        }
        logger("HEARTBEAT: ✓ Polo sent successfully - Heartbeat cycle #%d complete", heartbeat_count);
        
        // Log a periodic status message every 5 heartbeats
        if (heartbeat_count % 5 == 0) {
            logger("HEARTBEAT: 💓 Connection is healthy after %d heartbeat cycles", heartbeat_count);
        }
    }
}
