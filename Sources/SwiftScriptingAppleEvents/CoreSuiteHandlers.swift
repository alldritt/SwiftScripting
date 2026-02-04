#if canImport(Carbon)
import Foundation
import Carbon
import SwiftScripting

/// Handles the Core Suite Apple Events: get, set, count, make, delete, exists, move, duplicate.
@MainActor
public final class CoreSuiteHandlers: Sendable {
    private let resolver: ObjectResolver
    private let pipeline: MutationPipeline
    private let registry: ScriptableObjectRegistry

    public init(resolver: ObjectResolver, pipeline: MutationPipeline, registry: ScriptableObjectRegistry) {
        self.resolver = resolver
        self.pipeline = pipeline
        self.registry = registry
    }

    // MARK: - Property Packing

    /// Pack a single property value from an object.
    /// `pcls` is always available. `pID` is only returned if the class
    /// advertises it in its class description (i.e. the model opts into
    /// Identifiable). Everything else delegates to the object.
    private func packProperty(
        _ propertyCode: ScriptFourCharCode,
        of target: any ScriptableObject
    ) -> NSAppleEventDescriptor {
        let classDesc = type(of: target).scriptingClassDescription

        switch propertyCode {
        case .propertyClass:
            return NSAppleEventDescriptor(typeCode: classDesc.code.rawValue)
        case .propertyID where classDesc.property(forCode: .propertyID) != nil:
            return DescriptorPacking.pack(target.scriptableID)
        default:
            let value = target.scriptableValue(forProperty: propertyCode)
            return DescriptorPacking.pack(value)
        }
    }

    // MARK: - Get (getd)

    public func handleGet(
        directObject: NSAppleEventDescriptor
    ) throws -> NSAppleEventDescriptor {
        let specifier = try ObjectSpecifierParsing.parse(directObject)

        switch specifier {
        case .property(let propertyCode, let container):
            let containers = try resolver.resolve(container ?? .application)
            guard !containers.isEmpty else {
                throw AppleEventError.noSuchObject("No container for property \(propertyCode)")
            }

            // When the container resolves to multiple objects (e.g. "name of every todo item"),
            // return a list of property values from each object.
            if containers.count > 1 {
                let list = NSAppleEventDescriptor.list()
                for (i, target) in containers.enumerated() {
                    list.insert(packProperty(propertyCode, of: target), at: i + 1)
                }
                return list
            }

            return packProperty(propertyCode, of: containers[0])

        default:
            let objects = try resolver.resolve(specifier)
            // Build the container descriptor from the specifier's container chain
            // so returned object references include the full path (e.g.
            // todo item "Milk" of todo list "Shopping" rather than just todo item "Milk")
            let containerDesc = specifier.container.map {
                DescriptorPacking.packSpecifier($0)
            } ?? NSAppleEventDescriptor.null()

            if objects.count == 1, let obj = objects.first {
                return DescriptorPacking.packObjectReference(obj, in: containerDesc)
            }
            let list = NSAppleEventDescriptor.list()
            for (i, obj) in objects.enumerated() {
                list.insert(DescriptorPacking.packObjectReference(obj, in: containerDesc), at: i + 1)
            }
            return list
        }
    }

    // MARK: - Set (setd)

    public func handleSet(
        directObject: NSAppleEventDescriptor,
        data: NSAppleEventDescriptor
    ) throws -> NSAppleEventDescriptor {
        let specifier = try ObjectSpecifierParsing.parse(directObject)

        switch specifier {
        case .property(let propertyCode, let container):
            let containers = try resolver.resolve(container ?? .application)
            guard let target = containers.first else {
                throw AppleEventError.noSuchObject("No container for property \(propertyCode)")
            }

            let classDesc = type(of: target).scriptingClassDescription
            guard let propDesc = classDesc.property(forCode: propertyCode) else {
                throw AppleEventError.noSuchObject("No property \(propertyCode)")
            }

            guard !propDesc.isReadOnly else {
                throw AppleEventError.notModifiable("Property \(propertyCode) is read-only")
            }

            // If the data is an object specifier, resolve it to the actual object
            if case .objectSpecifier = propDesc.type,
               data.descriptorType == typeObjectSpecifier {
                let objSpecifier = try ObjectSpecifierParsing.parse(data)
                let resolved = try resolver.resolve(objSpecifier)
                guard let resolvedObj = resolved.first else {
                    throw AppleEventError.noSuchObject("Could not resolve object for property \(propertyCode)")
                }
                try target.setScriptableValue(resolvedObj as any ScriptableValue, forProperty: propertyCode)
            } else if data.descriptorType == typeNull ||
                      (data.descriptorType == typeType && data.typeCodeValue == UInt32(cMissingValue)) {
                // Handle missing value / null — clear the property
                try target.setScriptableValue(ScriptingMissingValue() as any ScriptableValue, forProperty: propertyCode)
            } else {
                guard let value = DescriptorPacking.unpack(data, as: propDesc.type) else {
                    throw AppleEventError.wrongDataType("Cannot convert to \(propDesc.type)")
                }
                try pipeline.setProperty(propertyCode, of: target, to: value)
            }

        default:
            throw AppleEventError.eventNotHandled("Set requires a property specifier")
        }

        return NSAppleEventDescriptor.null()
    }

    // MARK: - Count (cnte)

    public func handleCount(
        directObject: NSAppleEventDescriptor,
        objectClass: NSAppleEventDescriptor?
    ) throws -> NSAppleEventDescriptor {
        let containerSpecifier = try ObjectSpecifierParsing.parse(directObject)
        let containers = try resolver.resolve(containerSpecifier)
        guard let container = containers.first else {
            throw AppleEventError.noSuchObject("No container for count")
        }

        let classCode: ScriptFourCharCode
        if let classDesc = objectClass {
            classCode = ScriptFourCharCode(rawValue: classDesc.typeCodeValue)
        } else if case .every(let code, _) = containerSpecifier {
            classCode = code
        } else {
            throw AppleEventError.parameterMissing("Count requires kAEObjectClass parameter")
        }

        let elements = container.scriptableElements(forCode: classCode)
        return NSAppleEventDescriptor(int32: Int32(elements.count))
    }

    // MARK: - Make (crel)

    public func handleMake(
        objectClass: NSAppleEventDescriptor,
        insertionLocation: NSAppleEventDescriptor?,
        withProperties: NSAppleEventDescriptor?
    ) throws -> NSAppleEventDescriptor {
        let classCode = ScriptFourCharCode(rawValue: objectClass.typeCodeValue)

        let container: any ScriptableObject
        let index: Int?

        if let location = insertionLocation {
            if location.descriptorType == typeInsertionLoc {
                // Insertion location record: extract container object and position
                let objectDesc = location.forKeyword(AEKeyword(keyAEObject)) ?? NSAppleEventDescriptor.null()
                let positionDesc = location.forKeyword(AEKeyword(keyAEPosition))
                let position = positionDesc?.enumCodeValue ?? OSType(kAEEnd)

                let specifier = try ObjectSpecifierParsing.parse(objectDesc)
                let resolved = try resolver.resolve(specifier)
                guard let target = resolved.first else {
                    throw AppleEventError.noSuchObject("No container for insertion")
                }
                container = target

                let elementCount = container.scriptableElements(forCode: classCode).count
                switch position {
                case OSType(kAEBeginning):
                    index = 0
                case OSType(kAEEnd):
                    index = elementCount
                case OSType(kAEBefore):
                    index = 0
                case OSType(kAEAfter):
                    index = elementCount
                default:
                    index = elementCount
                }
            } else {
                let specifier = try ObjectSpecifierParsing.parse(location)
                let resolved = try resolver.resolve(specifier)
                if let first = resolved.first {
                    container = first
                } else {
                    container = try resolver.resolve(.application).first!
                }
                index = nil
            }
        } else {
            guard let app = registry.application else {
                throw AppleEventError.noSuchObject("No application")
            }
            container = app
            index = nil
        }

        var properties: [(ScriptFourCharCode, any ScriptableValue)] = []
        if let propsDesc = withProperties {
            // Iterate record-style (keyword-value pairs)
            let count = propsDesc.numberOfItems
            if count > 0 {
                for i in 1...count {
                    if let item = propsDesc.atIndex(i) {
                        if let value = DescriptorPacking.unpackAuto(item) {
                            // Use index as a placeholder code
                            let propCode = ScriptFourCharCode(rawValue: UInt32(i))
                            properties.append((propCode, value))
                        }
                    }
                }
            }
        }

        let newObject = try pipeline.makeElement(
            classCode: classCode,
            in: container,
            withProperties: properties,
            at: index
        )

        return DescriptorPacking.packObjectReference(newObject)
    }

    // MARK: - Delete (delo)

    public func handleDelete(
        directObject: NSAppleEventDescriptor
    ) throws -> NSAppleEventDescriptor {
        let specifier = try ObjectSpecifierParsing.parse(directObject)

        switch specifier {
        case .index(let classCode, let index, let container):
            let containers = try resolver.resolve(container ?? .application)
            guard let containerObj = containers.first else {
                throw AppleEventError.noSuchObject("No container")
            }
            let zeroIndex = index > 0 ? index - 1 : containerObj.scriptableElements(forCode: classCode).count + index
            try pipeline.deleteElement(at: zeroIndex, classCode: classCode, from: containerObj)

        case .name(let classCode, let name, let container):
            let containers = try resolver.resolve(container ?? .application)
            guard let containerObj = containers.first else {
                throw AppleEventError.noSuchObject("No container")
            }
            let elements = containerObj.scriptableElements(forCode: classCode)
            guard let idx = elements.firstIndex(where: { $0.scriptableName == name }) else {
                throw AppleEventError.noSuchObject("No element named \(name)")
            }
            try pipeline.deleteElement(at: idx, classCode: classCode, from: containerObj)

        default:
            throw AppleEventError.eventNotHandled("Delete requires an element specifier")
        }

        return NSAppleEventDescriptor.null()
    }

    // MARK: - Exists (doex)

    public func handleExists(
        directObject: NSAppleEventDescriptor
    ) throws -> NSAppleEventDescriptor {
        let specifier = try ObjectSpecifierParsing.parse(directObject)
        do {
            let results = try resolver.resolve(specifier)
            return NSAppleEventDescriptor(boolean: !results.isEmpty)
        } catch {
            return NSAppleEventDescriptor(boolean: false)
        }
    }

    // MARK: - Move (move)

    public func handleMove(
        directObject: NSAppleEventDescriptor,
        insertionLocation: NSAppleEventDescriptor
    ) throws -> NSAppleEventDescriptor {
        let sourceSpec = try ObjectSpecifierParsing.parse(directObject)
        let destSpec = try ObjectSpecifierParsing.parse(insertionLocation)

        guard case .index(let classCode, let srcIndex, let srcContainer) = sourceSpec else {
            throw AppleEventError.eventNotHandled("Move requires an index specifier")
        }

        let srcContainers = try resolver.resolve(srcContainer ?? .application)
        let destContainers = try resolver.resolve(destSpec)

        guard let srcObj = srcContainers.first,
              let destObj = destContainers.first else {
            throw AppleEventError.noSuchObject("Source or destination not found")
        }

        let zeroIndex = srcIndex > 0 ? srcIndex - 1 : srcObj.scriptableElements(forCode: classCode).count + srcIndex
        let element = srcObj.scriptableElements(forCode: classCode)[zeroIndex]
        let destIndex = destObj.scriptableElements(forCode: classCode).count

        try pipeline.moveElement(
            element,
            classCode: classCode,
            from: srcObj,
            sourceIndex: zeroIndex,
            to: destObj,
            destIndex: destIndex
        )

        return DescriptorPacking.packObjectReference(element)
    }

    // MARK: - Duplicate (clon)

    public func handleDuplicate(
        directObject: NSAppleEventDescriptor,
        insertionLocation: NSAppleEventDescriptor?
    ) throws -> NSAppleEventDescriptor {
        let sourceSpec = try ObjectSpecifierParsing.parse(directObject)

        guard case .index(let classCode, let srcIndex, let srcContainer) = sourceSpec else {
            throw AppleEventError.eventNotHandled("Duplicate requires an index specifier")
        }

        let srcContainers = try resolver.resolve(srcContainer ?? .application)
        guard let srcObj = srcContainers.first else {
            throw AppleEventError.noSuchObject("Source not found")
        }

        let zeroIndex = srcIndex > 0 ? srcIndex - 1 : srcObj.scriptableElements(forCode: classCode).count + srcIndex
        let original = srcObj.scriptableElements(forCode: classCode)[zeroIndex]

        let destContainer: any ScriptableObject
        if let destDesc = insertionLocation {
            let destSpec = try ObjectSpecifierParsing.parse(destDesc)
            destContainer = try resolver.resolve(destSpec).first ?? srcObj
        } else {
            destContainer = srcObj
        }

        let copy = try pipeline.duplicateElement(
            original,
            classCode: classCode,
            in: destContainer
        )

        return DescriptorPacking.packObjectReference(copy)
    }
}
#endif
