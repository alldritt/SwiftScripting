import Observation

/// Marks a class as a scriptable object, generating:
/// - `ScriptableObject` protocol conformance
/// - `Observable` conformance (observation tracking)
/// - `@MainActor` isolation
///
/// Usage:
/// ```swift
/// @Scriptable
/// class Document {
///     @ScriptableProperty("name", code: "pnam")
///     var name: String = "Untitled"
/// }
/// ```
///
/// Note: The class must also explicitly conform to `ScriptableObject`
/// or the generated extension will add conformance.
@attached(member, names: named(scriptableID), named(scriptableName), named(scriptingClassDescription), named(scriptableValue), named(setScriptableValue), named(scriptableElements), named(insertScriptableElement), named(removeScriptableElement), named(_$observationRegistrar))
@attached(extension, conformances: Observable)
public macro Scriptable(_ classCode: String? = nil) = #externalMacro(module: "SwiftScriptingMacros", type: "ScriptableMacro")
