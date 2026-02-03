import Testing
import Foundation
@testable import SwiftScripting

private typealias FCC = SwiftScripting.FourCharCode

@Suite("FourCharCode Tests")
struct FourCharCodeTests {

    @Test("Initialize from string")
    func initFromString() {
        let code = FCC("pnam")
        #expect(code.stringValue == "pnam")
    }

    @Test("Initialize from string literal")
    func initFromStringLiteral() {
        let code: FCC = "docu"
        #expect(code.stringValue == "docu")
    }

    @Test("Initialize from integer literal")
    func initFromIntegerLiteral() {
        // "pnam" = 0x706E616D
        let code: FCC = 0x706E616D
        #expect(code.stringValue == "pnam")
    }

    @Test("Short strings are padded with spaces")
    func shortStringPadding() {
        let code = FCC("ab")
        #expect(code.stringValue == "ab  ")
    }

    @Test("Equality")
    func equality() {
        let a = FCC("pnam")
        let b = FCC("pnam")
        let c = FCC("ctxt")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Hashable")
    func hashable() {
        let a = FCC("pnam")
        let b = FCC("pnam")
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Description includes quotes")
    func description() {
        let code = FCC("core")
        #expect(code.description == "'core'")
    }

    @Test("Well-known codes")
    func wellKnownCodes() {
        #expect(FCC.propertyName.stringValue == "pnam")
        #expect(FCC.classDocument.stringValue == "docu")
        #expect(FCC.classApplication.stringValue == "capp")
        #expect(FCC.coreSuite.stringValue == "core")
    }

    @Test("Round-trip through rawValue")
    func rawValueRoundTrip() {
        let original = FCC("test")
        let restored = FCC(rawValue: original.rawValue)
        #expect(original == restored)
        #expect(original.stringValue == restored.stringValue)
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let original = FCC("pnam")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FCC.self, from: data)
        #expect(original == decoded)
    }
}
