import SwiftUI
import FoundationModels

@main
struct Probe02App: App {
    var body: some Scene {
        WindowGroup { Probe02View() }
    }
}

struct Probe02View: View {
    @State private var info: String = "Checking…"

    var body: some View {
        VStack(spacing: 20) {
            Text("Probe 2").font(.title.weight(.semibold))
            Text("SystemLanguageModel.default.availability")
                .font(.callout.monospaced())
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .multilineTextAlignment(.center)
            Text("YES")
                .font(.system(size: 100, weight: .heavy))
                .foregroundStyle(.green)
            ScrollView {
                Text(info)
                    .font(.callout.monospaced())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            Text("If this app built, SystemLanguageModel.default.availability exists. The text box above shows the current availability value and its Swift type — note both.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            let availability = SystemLanguageModel.default.availability
            info = """
            value = \(availability)
            type  = \(type(of: availability))
            """
        }
    }
}
