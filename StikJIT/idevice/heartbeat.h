//
//  heartbeat.h
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

// heartbeat.h
#ifndef HEARTBEAT_H
#define HEARTBEAT_H
#include "idevice.h"

typedef void (^HeartbeatCompletionHandlerC)(int result, const char *message);
typedef void (^LogFuncC)(const char* message, ...);

// Connection mode enum to support both USB and TCP
typedef enum {
    ConnectionModeUSB = 0,
    ConnectionModeTCP = 1
} ConnectionMode;

// Updated function signature to include connection mode
void startHeartbeat(IdevicePairingFile* pairingFile, TcpProviderHandle** provider, int* heartbeatSessionId, HeartbeatCompletionHandlerC completion, LogFuncC logger, ConnectionMode mode);

#endif /* HEARTBEAT_H */
