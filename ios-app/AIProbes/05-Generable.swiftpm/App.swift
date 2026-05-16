import SwiftUI
import FoundationModels

@Generable
struct Greeting {
    @Guide(description: "A short friendly greeting, 3 to 5 words.")
    var text: String

    @Guide(description: "Word count of the greeting.")
    var wordCount: Int
}

@main
struct Probe05App: App {
    var body: some Scene {
        WindowGroup { Probe05View() }
    }
}

struct Probe05View: View {
    @State private var info: String = "Generating structured output…"
    @State private var ok: Bool = false
    @State private var failed: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Probe 5").font(.title.weight(.semibold))
            Text("@Generable + respond(to:, generating:)")
                .font(.callout.monospaced())
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .multilineTextAlignment(.center)
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
            Text("If YES: structured output via @Generable struct works.\nThe response box shows the model's parsed Greeting object.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            do {
                let session = LanguageModelSession(instructions: "You produce greetings.")
                let response = try await session.respond(
                    to: "Generate a friendly greeting.",
                    generating: Greeting.self
                )
                info = """
                response Swift type: \(type(of: response))
                full response: \(response)
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
