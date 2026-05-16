import SwiftUI
import ImagePlayground

@main
struct VisionProbe04App: App {
    var body: some Scene {
        WindowGroup { Probe04View() }
    }
}

struct Probe04View: View {
    @State private var prompt: String = "A bowl of red-braised pork belly, top-down photo"
    @State private var generatedImage: UIImage?
    @State private var status = "Edit the prompt, then tap Generate."
    @State private var ok = false
    @State private var failed = false
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 14) {
            Text("Vision Probe 4").font(.title.weight(.semibold))
            Text("ImagePlayground.ImageCreator")
                .font(.callout.monospaced())
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            if let generatedImage {
                Image(uiImage: generatedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(height: 220)
                    .overlay { Image(systemName: "wand.and.stars").font(.largeTitle).foregroundStyle(.secondary) }
            }

            TextField("Prompt", text: $prompt, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await run() }
            } label: {
                if isRunning {
                    HStack { ProgressView(); Text("Generating…") }
                } else {
                    Text("Generate image").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(prompt.isEmpty || isRunning)

            Text(badge)
                .font(.system(size: 48, weight: .heavy))
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
        isRunning = true
        defer { isRunning = false }
        do {
            // HYPOTHESIS: ImagePlayground exposes an `ImageCreator` type with
            // an async `images(for:concepts:style:)`-style method that returns
            // a sequence of generated images. If any of these symbol names is
            // wrong, the file won't compile — that's diagnostic data too.
            let creator = try await ImageCreator()
            var captured: UIImage?
            for try await image in creator.images(
                for: [.text(prompt)],
                style: .animation,
                limit: 1
            ) {
                if let ui = UIImage(cgImage: image.cgImage) as UIImage? {
                    captured = ui
                    break
                }
            }
            if let captured {
                generatedImage = captured
                status = "Generated one image; rendering above."
                ok = true
            } else {
                status = "Creator returned no images."
                failed = true
            }
        } catch {
            status = """
            ERROR
            type: \(type(of: error))
            description: \(error)
            """
            failed = true
        }
    }
}
