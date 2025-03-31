#ifndef APPLIST_H
#define APPLIST_H
@import Foundation;
#include "idevice.h"

NSDictionary<NSString*, NSString*>* list_installed_apps(TcpProviderHandle* provider, NSString** error);
NSDictionary<NSString*, NSString*>* list_installed_apps_usb(UsbmuxdAddrHandle* addr, NSString** error);

#endif /* APPLIST_H */
