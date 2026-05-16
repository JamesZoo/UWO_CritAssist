import SwiftUI
import FoundationModels

@main
struct Probe04App: App {
    var body: some Scene {
        WindowGroup { Probe04View() }
    }
}

struct Probe04View: View {
    @State private var info: String = "Asking the model…"
    @State private var ok: Bool = false
    @State private var failed: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Probe 4").font(.title.weight(.semibold))
            Text("session.respond(to: \"Say hi\")")
                .font(.callout.monospaced())
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            Text(badge)
                .font(.system(size: 100, weight: .heavy))
                .foregroundStyle(badgeColor)
            ScrollView {
                Text(info)
                    .font(.callout.monospaced())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            Text("If YES: respond(to:) returns a value, and the model actually answered.\nIf NO: see the error text.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            do {
                let session = LanguageModelSession(instructions: "You answer briefly.")
                let response = try await session.respond(to: "Say hi in five words.")
                info = """
                response Swift type: \(type(of: response))
                response value: \(response)
                """
                ok = true
            } catch {
                info = """
                ERROR
                type: \(type(of: error))
                description: \(error)
                """
                failed = true
            }
        }
    }

    private var badge: String {
        if ok { return "YES" }
        if failed { return "NO" }
        return "…"
    }

    private var badgeColor: Color {
        if ok { return .green }
        if failed { return .red }
        return .secondary
    }
}
