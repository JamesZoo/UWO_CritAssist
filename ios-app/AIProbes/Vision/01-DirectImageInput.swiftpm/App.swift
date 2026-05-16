import SwiftUI
import PhotosUI
import FoundationModels

@main
struct VisionProbe01App: App {
    var body: some Scene {
        WindowGroup { Probe01View() }
    }
}

struct Probe01View: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var status = "Pick a photo, then tap Run."
    @State private var ok = false
    @State private var failed = false
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Vision Probe 1").font(.title.weight(.semibold))
            Text("LanguageModelSession.respond(to:image:)")
                .font(.callout.monospaced())
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .multilineTextAlignment(.center)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(height: 220)
                    .overlay { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
            }

            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label("Pick a photo", systemImage: "photo.on.rectangle")
            }
            .onChange(of: pickedItem) { _, newItem in
                Task {
                    guard let newItem,
                          let data = try? await newItem.loadTransferable(type: Data.self),
                          let img = UIImage(data: data) else { return }
                    image = img
                    ok = false
                    failed = false
                    status = "Image loaded. Tap Run probe."
                }
            }

            Button {
                Task { await run() }
            } label: {
                if isRunning {
                    HStack { ProgressView(); Text("Running…") }
                } else {
                    Text("Run probe").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(image == nil || isRunning)

            Text(badge)
                .font(.system(size: 60, weight: .heavy))
                .foregroundStyle(badgeColor)

            ScrollView {
                Text(status)
                    .font(.callout.monospaced())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }

    private var badge: String { ok ? "YES" : failed ? "NO" : "…" }
    private var badgeColor: Color { ok ? .green : failed ? .red : .secondary }

    private func run() async {
        guard let image else { return }
        isRunning = true
        defer { isRunning = false }
        do {
            let session = LanguageModelSession(instructions: "You briefly describe what's in an image, focused on food and dishes.")
            // HYPOTHESIS: LanguageModelSession.respond has an overload that
            // accepts a UIImage. If this name is wrong, the file won't compile
            // and the user will see red markers — that's also useful data.
            let response = try await session.respond(
                to: "What food or dish is shown in this image? Be specific and concise.",
                image: image
            )
            status = """
            Response Swift type: \(type(of: response))
            Response value:
            \(response)
            """
            ok = true
        } catch {
            status = """
            ERROR (compiled, threw at runtime)
            type: \(type(of: error))
            description: \(error)
            """
            failed = true
        }
    }
}
