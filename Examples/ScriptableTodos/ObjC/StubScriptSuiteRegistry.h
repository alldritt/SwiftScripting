#import <TargetConditionals.h>

#if TARGET_OS_MAC && !TARGET_OS_IPHONE

#import <Foundation/Foundation.h>

/// A stub NSScriptSuiteRegistry that prevents Cocoa Scripting from loading
/// its own suite definitions and installing handlers that would conflict
/// with our custom Apple Event handlers (AppleEventInterface).
///
/// Installs itself via +load before main() runs.
@interface StubScriptSuiteRegistry : NSScriptSuiteRegistry
@end

#endif
