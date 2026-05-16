import SwiftUI
import FoundationModels

@main
struct Probe03App: App {
    var body: some Scene {
        WindowGroup { Probe03View() }
    }
}

struct Probe03View: View {
    @State private var info: String = "Creating session…"
    @State private var ok: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Probe 3").font(.title.weight(.semibold))
            Text("LanguageModelSession(instructions:)")
                .font(.callout.monospaced())
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            Text(ok ? "YES" : "…")
                .font(.system(size: 100, weight: .heavy))
                .foregroundStyle(ok ? .green : .secondary)
            ScrollView {
                Text(info)
                    .font(.callout.monospaced())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            Text("If YES: the initializer takes 'instructions: String' and produces a usable session object.\nThe box shows its Swift type.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            let session = LanguageModelSession(instructions: "You are a test assistant.")
            info = """
            Session created.
            Swift type: \(type(of: session))
            """
            ok = true
        }
    }
}
