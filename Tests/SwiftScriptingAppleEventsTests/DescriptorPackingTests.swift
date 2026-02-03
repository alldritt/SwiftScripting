#if canImport(Carbon)
import Testing
import Foundation
@testable import SwiftScripting
@testable import SwiftScriptingAppleEvents

@Suite("DescriptorPacking Tests")
@MainActor
struct DescriptorPackingTests {

    @Test("Pack and unpack String")
    func stringRoundTrip() {
        let original = "Hello, World!"
        let descriptor = DescriptorPacking.pack(original)
        let unpacked = DescriptorPacking.unpack(descriptor, as: .text) as? String
        #expect(unpacked == original)
    }

    @Test("Pack and unpack Int")
    func intRoundTrip() {
        let original = 42
        let descriptor = DescriptorPacking.pack(original)
        let unpacked = DescriptorPacking.unpack(descriptor, as: .integer) as? Int
        #expect(unpacked == original)
    }

    @Test("Pack and unpack Double")
    func doubleRoundTrip() {
        let original = 3.14159
        let descriptor = DescriptorPacking.pack(original)
        let unpacked = DescriptorPacking.unpack(descriptor, as: .real) as? Double
        #expect(unpacked == original)
    }

    @Test("Pack and unpack Bool true")
    func boolTrueRoundTrip() {
        let descriptor = DescriptorPacking.pack(true)
        let unpacked = DescriptorPacking.unpack(descriptor, as: .boolean) as? Bool
        #expect(unpacked == true)
    }

    @Test("Pack and unpack Bool false")
    func boolFalseRoundTrip() {
        let descriptor = DescriptorPacking.pack(false)
        let unpacked = DescriptorPacking.unpack(descriptor, as: .boolean) as? Bool
        #expect(unpacked == false)
    }

    @Test("Pack and unpack Date")
    func dateRoundTrip() {
        let original = Date(timeIntervalSinceReferenceDate: 700000000)
        let descriptor = DescriptorPacking.pack(original)
        let unpacked = DescriptorPacking.unpack(descriptor, as: .date) as? Date
        #expect(unpacked != nil)
        if let unpacked {
            // Allow small rounding differences
            #expect(abs(unpacked.timeIntervalSinceReferenceDate - original.timeIntervalSinceReferenceDate) < 1.0)
        }
    }

    @Test("Pack and unpack URL")
    func urlRoundTrip() {
        let original = URL(string: "file:///Users/test/doc.txt")!
        let descriptor = DescriptorPacking.pack(original)
        let unpacked = DescriptorPacking.unpack(descriptor, as: .fileURL) as? URL
        #expect(unpacked?.absoluteString == original.absoluteString)
    }

    @Test("Automatic type detection for String descriptor")
    func autoDetectString() {
        let descriptor = NSAppleEventDescriptor(string: "auto")
        let value = DescriptorPacking.unpackAuto(descriptor) as? String
        #expect(value == "auto")
    }

    @Test("Automatic type detection for Int descriptor")
    func autoDetectInt() {
        let descriptor = NSAppleEventDescriptor(int32: 99)
        let value = DescriptorPacking.unpackAuto(descriptor) as? Int
        #expect(value == 99)
    }

    @Test("Automatic type detection for Bool descriptor")
    func autoDetectBool() {
        let descriptor = NSAppleEventDescriptor(boolean: true)
        let value = DescriptorPacking.unpackAuto(descriptor) as? Bool
        #expect(value == true)
    }
}
#endif
