#if canImport(Carbon)
import Foundation
import Carbon
import SwiftScripting

// Disambiguate from Carbon's FourCharCode (which is a typealias for UInt32)
typealias ScriptFourCharCode = SwiftScripting.FourCharCode

/// Converts between Swift `ScriptableValue` types and `NSAppleEventDescriptor`.
@MainActor
public enum DescriptorPacking {

    // MARK: - Pack Swift → AEDescriptor

    public static func pack(_ value: any ScriptableValue) -> NSAppleEventDescriptor {
        switch value {
        case let s as String:
            return NSAppleEventDescriptor(string: s)
        case let i as Int:
            return NSAppleEventDescriptor(int32: Int32(clamping: i))
        case let d as Double:
            return packDouble(d)
        case let b as Bool:
            return NSAppleEventDescriptor(boolean: b)
        case let date as Date:
            return packDate(date)
        case let data as Data:
            return packData(data)
        case let url as URL:
            return packURL(url)
        default:
            // Check for ScriptableObject — return as object specifier reference
            if let obj = value as? any ScriptableObject {
                return packObjectReference(obj)
            }
            if let array = value as? [any ScriptableValue] {
                return packList(array)
            }
            // Check for nil optionals — return missing value
            if case Optional<Any>.none = value as Any {
                return NSAppleEventDescriptor(typeCode: UInt32(cMissingValue))
            }
            return NSAppleEventDescriptor(string: String(describing: value))
        }
    }

    public static func packObjectReference(
        _ object: any ScriptableObject,
        in container: NSAppleEventDescriptor = NSAppleEventDescriptor.null()
    ) -> NSAppleEventDescriptor {
        let classDesc = type(of: object).scriptingClassDescription
        if let name = object.scriptableName {
            return buildNameSpecifier(classCode: classDesc.code, name: name, container: container)
        }
        return buildIDSpecifier(classCode: classDesc.code, id: object.scriptableID, container: container)
    }

    // MARK: - Unpack AEDescriptor → Swift

    public static func unpack(
        _ descriptor: NSAppleEventDescriptor,
        as type: ScriptingType
    ) -> (any ScriptableValue)? {
        switch type {
        case .text:
            return descriptor.stringValue
        case .integer:
            return Int(descriptor.int32Value)
        case .real:
            return unpackDouble(descriptor)
        case .boolean:
            return descriptor.booleanValue
        case .date:
            return unpackDate(descriptor)
        case .data:
            return descriptor.data as Data
        case .fileURL:
            return unpackURL(descriptor)
        case .list(let elementType):
            let arr = unpackList(descriptor, elementType: elementType)
            // Return first element or nil if we need a single value
            return arr.isEmpty ? nil : arr.first
        case .optional(let innerType):
            if descriptor.descriptorType == typeNull {
                return nil as String?
            }
            return unpack(descriptor, as: innerType)
        case .enumerated, .record, .objectSpecifier, .color, .any:
            return descriptor.stringValue
        }
    }

    public static func unpackAuto(_ descriptor: NSAppleEventDescriptor) -> (any ScriptableValue)? {
        switch descriptor.descriptorType {
        case typeUnicodeText, typeUTF8Text:
            return descriptor.stringValue
        case typeSInt32, typeSInt16:
            return Int(descriptor.int32Value)
        case typeSInt64:
            return unpackInt64(descriptor)
        case typeIEEE64BitFloatingPoint, typeIEEE32BitFloatingPoint:
            return unpackDouble(descriptor)
        case typeBoolean, typeTrue, typeFalse:
            return descriptor.booleanValue
        case typeLongDateTime:
            return unpackDate(descriptor)
        case typeFileURL:
            return unpackURL(descriptor)
        case typeAEList:
            let items = unpackListAuto(descriptor)
            return items.first  // Return single item
        default:
            return descriptor.stringValue
        }
    }

    // MARK: - List unpacking (returns arrays)

    public static func unpackListValues(
        _ descriptor: NSAppleEventDescriptor,
        elementType: ScriptingType
    ) -> [any ScriptableValue] {
        unpackList(descriptor, elementType: elementType)
    }

    // MARK: - Specific Packers

    private static func packDouble(_ value: Double) -> NSAppleEventDescriptor {
        var d = value
        let data = Data(bytes: &d, count: MemoryLayout<Double>.size)
        return NSAppleEventDescriptor(descriptorType: typeIEEE64BitFloatingPoint, data: data)!
    }

    private static func packDate(_ value: Date) -> NSAppleEventDescriptor {
        var ldt = Int64(value.timeIntervalSinceReferenceDate)
        let data = Data(bytes: &ldt, count: MemoryLayout<Int64>.size)
        return NSAppleEventDescriptor(descriptorType: typeLongDateTime, data: data)!
    }

    private static func packData(_ value: Data) -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(descriptorType: typeData, data: value)!
    }

    private static func packURL(_ value: URL) -> NSAppleEventDescriptor {
        let urlData = value.absoluteString.data(using: .utf8)!
        return NSAppleEventDescriptor(descriptorType: typeFileURL, data: urlData)!
    }

    private static func packList(_ values: [any ScriptableValue]) -> NSAppleEventDescriptor {
        let listDesc = NSAppleEventDescriptor.list()
        for (i, value) in values.enumerated() {
            listDesc.insert(pack(value), at: i + 1)
        }
        return listDesc
    }

    // MARK: - Specific Unpackers

    private static func unpackDouble(_ descriptor: NSAppleEventDescriptor) -> Double? {
        guard let coerced = descriptor.coerce(toDescriptorType: typeIEEE64BitFloatingPoint) else {
            return Double(descriptor.int32Value)
        }
        let data = coerced.data
        guard data.count >= MemoryLayout<Double>.size else {
            return Double(descriptor.int32Value)
        }
        return data.withUnsafeBytes { $0.load(as: Double.self) }
    }

    private static func unpackInt64(_ descriptor: NSAppleEventDescriptor) -> Int? {
        let data = descriptor.data
        guard data.count >= MemoryLayout<Int64>.size else {
            return Int(descriptor.int32Value)
        }
        let value = data.withUnsafeBytes { $0.load(as: Int64.self) }
        return Int(value)
    }

    private static func unpackDate(_ descriptor: NSAppleEventDescriptor) -> Date? {
        guard let coerced = descriptor.coerce(toDescriptorType: typeLongDateTime) else {
            return nil
        }
        let data = coerced.data
        guard data.count >= MemoryLayout<Int64>.size else {
            return nil
        }
        let ldt = data.withUnsafeBytes { $0.load(as: Int64.self) }
        return Date(timeIntervalSinceReferenceDate: TimeInterval(ldt))
    }

    private static func unpackURL(_ descriptor: NSAppleEventDescriptor) -> URL? {
        let data = descriptor.data
        if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
            return URL(string: str)
        }
        if let str = descriptor.stringValue {
            return URL(fileURLWithPath: str)
        }
        return nil
    }

    private static func unpackList(
        _ descriptor: NSAppleEventDescriptor,
        elementType: ScriptingType
    ) -> [any ScriptableValue] {
        let count = descriptor.numberOfItems
        guard count > 0 else { return [] }
        var result: [any ScriptableValue] = []
        for i in 1...count {
            if let item = descriptor.atIndex(i),
               let value = unpack(item, as: elementType) {
                result.append(value)
            }
        }
        return result
    }

    private static func unpackListAuto(_ descriptor: NSAppleEventDescriptor) -> [any ScriptableValue] {
        let count = descriptor.numberOfItems
        guard count > 0 else { return [] }
        var result: [any ScriptableValue] = []
        for i in 1...count {
            if let item = descriptor.atIndex(i),
               let value = unpackAuto(item) {
                result.append(value)
            }
        }
        return result
    }

    // MARK: - Object Specifier Building

    private static func buildNameSpecifier(
        classCode: ScriptFourCharCode,
        name: String,
        container: NSAppleEventDescriptor
    ) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(
            NSAppleEventDescriptor(typeCode: classCode.rawValue),
            forKeyword: AEKeyword(keyAEDesiredClass)
        )
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        record.setDescriptor(
            NSAppleEventDescriptor(enumCode: OSType(formName)),
            forKeyword: AEKeyword(keyAEKeyForm)
        )
        record.setDescriptor(
            NSAppleEventDescriptor(string: name),
            forKeyword: AEKeyword(keyAEKeyData)
        )
        return record.coerce(toDescriptorType: typeObjectSpecifier) ?? record
    }

    private static func buildIDSpecifier(
        classCode: ScriptFourCharCode,
        id: String,
        container: NSAppleEventDescriptor
    ) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(
            NSAppleEventDescriptor(typeCode: classCode.rawValue),
            forKeyword: AEKeyword(keyAEDesiredClass)
        )
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        record.setDescriptor(
            NSAppleEventDescriptor(enumCode: OSType(formUniqueID)),
            forKeyword: AEKeyword(keyAEKeyForm)
        )
        record.setDescriptor(
            NSAppleEventDescriptor(string: id),
            forKeyword: AEKeyword(keyAEKeyData)
        )
        return record.coerce(toDescriptorType: typeObjectSpecifier) ?? record
    }

    private static func buildIndexSpecifier(
        classCode: ScriptFourCharCode,
        index: Int,
        container: NSAppleEventDescriptor
    ) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(
            NSAppleEventDescriptor(typeCode: classCode.rawValue),
            forKeyword: AEKeyword(keyAEDesiredClass)
        )
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        record.setDescriptor(
            NSAppleEventDescriptor(enumCode: OSType(formAbsolutePosition)),
            forKeyword: AEKeyword(keyAEKeyForm)
        )
        record.setDescriptor(
            NSAppleEventDescriptor(int32: Int32(index)),
            forKeyword: AEKeyword(keyAEKeyData)
        )
        return record.coerce(toDescriptorType: typeObjectSpecifier) ?? record
    }

    // MARK: - Specifier Packing (ObjectSpecifier → AEDescriptor)

    /// Converts a parsed `ObjectSpecifier` back into an `NSAppleEventDescriptor`.
    /// Used to build proper container chains when returning object references.
    public static func packSpecifier(_ specifier: ObjectSpecifier) -> NSAppleEventDescriptor {
        switch specifier {
        case .application:
            return NSAppleEventDescriptor.null()
        case .name(let classCode, let name, let container):
            let containerDesc = container.map { packSpecifier($0) } ?? NSAppleEventDescriptor.null()
            return buildNameSpecifier(classCode: classCode, name: name, container: containerDesc)
        case .index(let classCode, let index, let container):
            let containerDesc = container.map { packSpecifier($0) } ?? NSAppleEventDescriptor.null()
            return buildIndexSpecifier(classCode: classCode, index: index, container: containerDesc)
        case .id(let classCode, let id, let container):
            let containerDesc = container.map { packSpecifier($0) } ?? NSAppleEventDescriptor.null()
            return buildIDSpecifier(classCode: classCode, id: id, container: containerDesc)
        default:
            // For every, property, whose, range — resolve to null (application) container
            return NSAppleEventDescriptor.null()
        }
    }
}
#endif
