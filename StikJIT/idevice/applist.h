#ifndef APPLIST_H
#define APPLIST_H
@import Foundation;

NSDictionary<NSString*, NSString*>* list_installed_apps(TcpProviderHandle* provider, NSString** error);

// Add function for USB app listing
NSDictionary<NSString*, NSString*>* list_installed_apps_usb(UsbmuxdAddrHandle* addr, NSString** error);

#endif /* APPLIST_H */
