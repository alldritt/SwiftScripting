import Testing
import Foundation
@testable import SwiftScripting

private typealias FCC = SwiftScripting.FourCharCode

@Suite("ScriptableValue Tests")
struct ScriptableValueTests {

    @Test("String scripting type is text")
    func stringType() {
        #expect(String.scriptingType == .text)
    }

    @Test("Int scripting type is integer")
    func intType() {
        #expect(Int.scriptingType == .integer)
    }

    @Test("Double scripting type is real")
    func doubleType() {
        #expect(Double.scriptingType == .real)
    }

    @Test("Bool scripting type is boolean")
    func boolType() {
        #expect(Bool.scriptingType == .boolean)
    }

    @Test("Date scripting type is date")
    func dateType() {
        #expect(Date.scriptingType == .date)
    }

    @Test("Data scripting type is data")
    func dataType() {
        #expect(Data.scriptingType == .data)
    }

    @Test("URL scripting type is fileURL")
    func urlType() {
        #expect(URL.scriptingType == .fileURL)
    }

    @Test("Array scripting type is list")
    func arrayType() {
        let type = [String].scriptingType
        #expect(type == .list(.text))
    }

    @Test("Optional scripting type is optional")
    func optionalType() {
        let type = String?.scriptingType
        #expect(type == .optional(.text))
    }

    @Test("ScriptingType AE type codes")
    func aeTypeCodes() {
        #expect(ScriptingType.text.aeTypeCode == FCC("utxt"))
        #expect(ScriptingType.integer.aeTypeCode == FCC("long"))
        #expect(ScriptingType.real.aeTypeCode == FCC("doub"))
        #expect(ScriptingType.boolean.aeTypeCode == FCC("bool"))
    }
}
