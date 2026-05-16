import SwiftUI
import FoundationModels

@main
struct Probe01App: App {
    var body: some Scene {
        WindowGroup { Probe01View() }
    }
}

struct Probe01View: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Probe 1")
                .font(.title.weight(.semibold))
            Text("import FoundationModels")
                .font(.callout.monospaced())
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            Text("YES")
                .font(.system(size: 120, weight: .heavy))
                .foregroundStyle(.green)
            Text("If you see this, the framework imports cleanly.\nIf the app failed to build instead, FoundationModels isn't reachable from Swift Playgrounds.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
