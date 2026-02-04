// Re-export macro declarations so consumers only need `import SwiftScripting`
@_exported import SwiftScriptingMacrosClient
// Re-export Observation so @Scriptable macro's Observable conformance resolves
@_exported import Observation

// Resolve ambiguity between SwiftScriptingMacrosClient.FourCharCode and the
// system's MacTypes.h `typedef UInt32 FourCharCode` brought in by Foundation/AppKit.
public typealias FourCharCode = SwiftScriptingMacrosClient.FourCharCode
