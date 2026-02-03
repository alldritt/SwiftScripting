#if canImport(Carbon)
import Foundation
import Carbon
import SwiftScripting

/// Registers Apple Event handlers with `NSAppleEventManager` and coordinates
/// object resolution and command dispatch.
@MainActor
public final class AppleEventInterface: NSObject, Sendable {
    private let registry: ScriptableObjectRegistry
    private let resolver: ObjectResolver
    private let pipeline: MutationPipeline
    private let handlers: CoreSuiteHandlers

    public init(registry: ScriptableObjectRegistry, pipeline: MutationPipeline) {
        self.registry = registry
        self.resolver = ObjectResolver(registry: registry)
        self.pipeline = pipeline
        self.handlers = CoreSuiteHandlers(resolver: self.resolver, pipeline: pipeline, registry: registry)
        super.init()
    }

    /// Install all Core Suite Apple Event handlers.
    public func install() {
        let mgr = NSAppleEventManager.shared()

        let events: [(AEEventClass, AEEventID)] = [
            (AEEventClass(kAECoreSuite), AEEventID(kAEGetData)),
            (AEEventClass(kAECoreSuite), AEEventID(kAESetData)),
            (AEEventClass(kAECoreSuite), AEEventID(kAECountElements)),
            (AEEventClass(kAECoreSuite), AEEventID(kAECreateElement)),
            (AEEventClass(kAECoreSuite), AEEventID(kAEDelete)),
            (AEEventClass(kAECoreSuite), AEEventID(kAEDoObjectsExist)),
            (AEEventClass(kAECoreSuite), AEEventID(kAEMove)),
            (AEEventClass(kAECoreSuite), AEEventID(kAEClone)),
        ]

        for (eventClass, eventID) in events {
            mgr.setEventHandler(
                self,
                andSelector: #selector(handleAppleEvent(_:withReply:)),
                forEventClass: eventClass,
                andEventID: eventID
            )
        }
    }

    /// Uninstall all registered Apple Event handlers.
    public func uninstall() {
        let mgr = NSAppleEventManager.shared()

        let events: [(AEEventClass, AEEventID)] = [
            (AEEventClass(kAECoreSuite), AEEventID(kAEGetData)),
            (AEEventClass(kAECoreSuite), AEEventID(kAESetData)),
            (AEEventClass(kAECoreSuite), AEEventID(kAECountElements)),
            (AEEventClass(kAECoreSuite), AEEventID(kAECreateElement)),
            (AEEventClass(kAECoreSuite), AEEventID(kAEDelete)),
            (AEEventClass(kAECoreSuite), AEEventID(kAEDoObjectsExist)),
            (AEEventClass(kAECoreSuite), AEEventID(kAEMove)),
            (AEEventClass(kAECoreSuite), AEEventID(kAEClone)),
        ]

        for (eventClass, eventID) in events {
            mgr.removeEventHandler(forEventClass: eventClass, andEventID: eventID)
        }
    }

    // MARK: - Event Dispatch

    @objc private func handleAppleEvent(
        _ event: NSAppleEventDescriptor,
        withReply reply: NSAppleEventDescriptor
    ) {
        let eventID = event.attributeDescriptor(forKeyword: AEKeyword(keyEventIDAttr))?.typeCodeValue ?? 0

        do {
            let result: NSAppleEventDescriptor

            switch eventID {
            case AEEventID(kAEGetData):
                let directObject = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))
                    ?? NSAppleEventDescriptor.null()
                result = try handlers.handleGet(directObject: directObject)

            case AEEventID(kAESetData):
                let directObject = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))
                    ?? NSAppleEventDescriptor.null()
                let data = event.paramDescriptor(forKeyword: AEKeyword(keyAEData))
                    ?? NSAppleEventDescriptor.null()
                result = try handlers.handleSet(directObject: directObject, data: data)

            case AEEventID(kAECountElements):
                let directObject = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))
                    ?? NSAppleEventDescriptor.null()
                let objectClass = event.paramDescriptor(forKeyword: AEKeyword(keyAEObjectClass))
                result = try handlers.handleCount(directObject: directObject, objectClass: objectClass)

            case AEEventID(kAECreateElement):
                let objectClass = event.paramDescriptor(forKeyword: AEKeyword(keyAEObjectClass))
                    ?? NSAppleEventDescriptor.null()
                let location = event.paramDescriptor(forKeyword: AEKeyword(keyAEInsertHere))
                let properties = event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))
                result = try handlers.handleMake(
                    objectClass: objectClass,
                    insertionLocation: location,
                    withProperties: properties
                )

            case AEEventID(kAEDelete):
                let directObject = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))
                    ?? NSAppleEventDescriptor.null()
                result = try handlers.handleDelete(directObject: directObject)

            case AEEventID(kAEDoObjectsExist):
                let directObject = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))
                    ?? NSAppleEventDescriptor.null()
                result = try handlers.handleExists(directObject: directObject)

            case AEEventID(kAEMove):
                let directObject = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))
                    ?? NSAppleEventDescriptor.null()
                let location = event.paramDescriptor(forKeyword: AEKeyword(keyAEInsertHere))
                    ?? NSAppleEventDescriptor.null()
                result = try handlers.handleMove(directObject: directObject, insertionLocation: location)

            case AEEventID(kAEClone):
                let directObject = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))
                    ?? NSAppleEventDescriptor.null()
                let location = event.paramDescriptor(forKeyword: AEKeyword(keyAEInsertHere))
                result = try handlers.handleDuplicate(directObject: directObject, insertionLocation: location)

            default:
                reply.setDescriptor(
                    NSAppleEventDescriptor(int32: Int32(errAEEventNotHandled)),
                    forKeyword: AEKeyword(keyErrorNumber)
                )
                return
            }

            reply.setDescriptor(result, forKeyword: AEKeyword(keyDirectObject))

        } catch let error as AppleEventError {
            reply.setDescriptor(
                NSAppleEventDescriptor(int32: Int32(error.code)),
                forKeyword: AEKeyword(keyErrorNumber)
            )
            reply.setDescriptor(
                NSAppleEventDescriptor(string: error.message),
                forKeyword: AEKeyword(keyErrorString)
            )
        } catch let error as ScriptingError {
            let aeError = AppleEventError.from(error)
            reply.setDescriptor(
                NSAppleEventDescriptor(int32: Int32(aeError.code)),
                forKeyword: AEKeyword(keyErrorNumber)
            )
            reply.setDescriptor(
                NSAppleEventDescriptor(string: error.description),
                forKeyword: AEKeyword(keyErrorString)
            )
        } catch {
            reply.setDescriptor(
                NSAppleEventDescriptor(int32: Int32(errAEEventNotHandled)),
                forKeyword: AEKeyword(keyErrorNumber)
            )
            reply.setDescriptor(
                NSAppleEventDescriptor(string: error.localizedDescription),
                forKeyword: AEKeyword(keyErrorString)
            )
        }
    }
}
#endif
