/// A type-safe wrapper around a four-character code (`OSType` / `UInt32`),
/// commonly used in Apple Event descriptors for class codes, property codes, etc.
///
/// Can be initialized from a four-character string literal:
/// ```swift
/// let code: FourCharCode = "pnam"  // 0x706E616D
/// ```
public struct FourCharCode: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Initialize from a four-character ASCII string.
    /// Pads with spaces if shorter than 4 characters. Truncates if longer.
    public init(_ string: String) {
        var code: UInt32 = 0
        let bytes = Array(string.utf8.prefix(4))
        for (i, byte) in bytes.enumerated() {
            code |= UInt32(byte) << UInt32((3 - i) * 8)
        }
        // Pad with spaces if shorter than 4 characters
        for i in bytes.count..<4 {
            code |= UInt32(0x20) << UInt32((3 - i) * 8)
        }
        self.rawValue = code
    }

    /// The four-character string representation.
    public var stringValue: String {
        let chars = [
            UInt8((rawValue >> 24) & 0xFF),
            UInt8((rawValue >> 16) & 0xFF),
            UInt8((rawValue >> 8) & 0xFF),
            UInt8(rawValue & 0xFF),
        ]
        return String(bytes: chars, encoding: .ascii) ?? "????"
    }

    public var description: String {
        "'\(stringValue)'"
    }
}

// MARK: - ExpressibleByStringLiteral

extension FourCharCode: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension FourCharCode: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

// MARK: - Codable

extension FourCharCode: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(UInt32.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Well-Known Codes

extension FourCharCode {
    // Core Suite event codes
    public static let getEvent: FourCharCode = "getd"
    public static let setEvent: FourCharCode = "setd"
    public static let countEvent: FourCharCode = "cnte"
    public static let makeEvent: FourCharCode = "crel"
    public static let deleteEvent: FourCharCode = "delo"
    public static let existsEvent: FourCharCode = "doex"
    public static let moveEvent: FourCharCode = "move"
    public static let duplicateEvent: FourCharCode = "clon"

    // Core Suite class code
    public static let coreSuite: FourCharCode = "core"

    // Standard property codes
    public static let propertyName: FourCharCode = "pnam"
    public static let propertyClass: FourCharCode = "pcls"
    public static let propertyID: FourCharCode = "ID  "
    public static let propertyBestType: FourCharCode = "pbst"
    public static let propertyDefaultType: FourCharCode = "deft"

    // Standard class codes
    public static let classApplication: FourCharCode = "capp"
    public static let classDocument: FourCharCode = "docu"
    public static let classWindow: FourCharCode = "cwin"
    public static let classItem: FourCharCode = "cobj"

    // Misc
    public static let typeNull: FourCharCode = "null"
    public static let typeObjectSpecifier: FourCharCode = "obj "
    public static let typeCurrentContainer: FourCharCode = "ccnt"
    public static let typeObjectBeingExamined: FourCharCode = "exmn"
}
