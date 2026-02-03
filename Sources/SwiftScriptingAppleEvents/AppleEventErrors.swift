#if canImport(Carbon)
import Carbon
import SwiftScripting

/// Apple Event error codes used in scripting replies.
public enum AppleEventError: Error, Sendable {
    /// No such object (errAENoSuchObject / -1728)
    case noSuchObject(String)

    /// Event not handled (errAEEventNotHandled / -1708)
    case eventNotHandled(String)

    /// Wrong data type (errAEWrongDataType / -1700)
    case wrongDataType(String)

    /// Not modifiable / read-only (errAENotModifiable / -10006)
    case notModifiable(String)

    /// Coroutine required parameter missing (-1701)
    case parameterMissing(String)

    /// General error
    case general(Int, String)

    /// The OSStatus error code for this error.
    public var code: OSStatus {
        switch self {
        case .noSuchObject: return OSStatus(errAENoSuchObject)
        case .eventNotHandled: return OSStatus(errAEEventNotHandled)
        case .wrongDataType: return OSStatus(errAEWrongDataType)
        case .notModifiable: return -10006
        case .parameterMissing: return OSStatus(errAEParamMissed)
        case .general(let code, _): return OSStatus(code)
        }
    }

    /// A human-readable description of the error.
    public var message: String {
        switch self {
        case .noSuchObject(let msg): return msg
        case .eventNotHandled(let msg): return msg
        case .wrongDataType(let msg): return msg
        case .notModifiable(let msg): return msg
        case .parameterMissing(let msg): return msg
        case .general(_, let msg): return msg
        }
    }

    /// Convert a ScriptingError to an AppleEventError.
    public static func from(_ error: ScriptingError) -> AppleEventError {
        switch error {
        case .propertyNotFound, .elementNotFound, .objectNotFound, .indexOutOfBounds:
            return .noSuchObject(error.description)
        case .typeMismatch:
            return .wrongDataType(error.description)
        case .readOnlyProperty:
            return .notModifiable(error.description)
        case .invalidSpecifier:
            return .eventNotHandled(error.description)
        case .commandFailed:
            return .general(-10000, error.description)
        }
    }
}
#endif
