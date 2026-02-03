import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftScriptingMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ScriptableMacro.self,
    ]
}
