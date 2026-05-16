import SwiftUI
import FoundationModels

@main
struct Probe01App: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 24) {
                Text("Probe 1")
                    .font(.title.weight(.semibold))
                Text("YES")
                    .font(.system(size: 120, weight: .heavy))
                    .foregroundStyle(.green)
                Text("import FoundationModels works.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
