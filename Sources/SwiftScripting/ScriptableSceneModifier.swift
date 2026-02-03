import SwiftUI

/// Environment key for the scripting registry.
private struct ScriptingRegistryKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: ScriptableObjectRegistry? = nil
}

extension EnvironmentValues {
    /// The active scripting object registry.
    public var scriptingRegistry: ScriptableObjectRegistry? {
        get { self[ScriptingRegistryKey.self] }
        set { self[ScriptingRegistryKey.self] = newValue }
    }
}

/// A view modifier that installs the scripting infrastructure on first appearance.
///
/// Applied via the `.scriptable()` view modifier. Sets up the scripting registry,
/// registers classes, and injects the registry into the environment.
public struct ScriptableViewModifier: ViewModifier {
    private let suite: ScriptSuite

    @State private var registry = ScriptableObjectRegistry()
    @State private var application = ScriptableApplication()
    @State private var isSetUp = false

    public init(suite: ScriptSuite) {
        self.suite = suite
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.scriptingRegistry, registry)
            .onAppear {
                guard !isSetUp else { return }
                isSetUp = true
                setupScripting()
            }
    }

    @MainActor
    private func setupScripting() {
        registry.setApplication(application)

        for classType in suite.classes {
            registry.registerClass(classType)
        }

        registry.registerClass(ScriptableApplication.self)
        registry.registerClass(ScriptableWindow.self)
    }
}

// MARK: - View Extension

extension View {
    /// Install scripting support using the provided suite configuration.
    ///
    /// Apply this to the root view of your app's scene to set up the
    /// scripting infrastructure.
    ///
    /// ```swift
    /// ContentView()
    ///     .scriptable(ScriptSuite("MyApp", code: "MyAp") {
    ///         Document.self
    ///     })
    /// ```
    public func scriptable(_ suite: ScriptSuite) -> some View {
        modifier(ScriptableViewModifier(suite: suite))
    }
}
