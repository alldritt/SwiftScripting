#import <TargetConditionals.h>

#if TARGET_OS_MAC && !TARGET_OS_IPHONE

#import "StubScriptSuiteRegistry.h"

@implementation StubScriptSuiteRegistry

+ (void)load {
    // Install ourselves as the shared registry before AppKit's Cocoa Scripting
    // subsystem gets a chance to initialize. This ensures that when AppKit calls
    // loadSuitesFromBundle: (triggered by NSAppleScriptEnabled=YES), our no-op
    // override is called instead of the real implementation.
    StubScriptSuiteRegistry *stub = [[StubScriptSuiteRegistry alloc] init];
    [NSScriptSuiteRegistry setSharedScriptSuiteRegistry:stub];
}

- (void)loadSuitesFromBundle:(NSBundle *)bundle {
    // No-op: prevent Cocoa Scripting from loading suite definitions
    // that would install conflicting Apple Event handlers.
}

// Private AppKit methods that may also attempt to load suites.
// Override them as no-ops for completeness.

- (void)_loadSuitesForAlreadyLoadedBundles {
    // No-op
}

- (void)_loadSuitesFromSDEFData:(id)data bundle:(NSBundle *)bundle {
    // No-op
}

@end

#endif
