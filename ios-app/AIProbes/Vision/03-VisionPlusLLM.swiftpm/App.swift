import SwiftUI
import PhotosUI
import Vision
import FoundationModels

@main
struct VisionProbe03App: App {
    var body: some Scene {
        WindowGroup { Probe03View() }
    }
}

struct Probe03View: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var dishGuess: String = ""
    @State private var status = "Pick a photo, type the dish you think it is, then tap Run."
    @State private var ok = false
    @State private var failed = false
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 14) {
            Text("Vision Probe 3").font(.title.weight(.semibold))
            Text("Vision labels → LanguageModelSession")
                .font(.callout.monospaced())
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(height: 180)
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
                    status = "Image loaded. Enter dish name (e.g. 红烧排骨), then Run."
                }
            }

            TextField("Dish name to check (e.g. 红烧排骨)", text: $dishGuess)
                .textFieldStyle(.roundedBorder)

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
            .disabled(image == nil || dishGuess.isEmpty || isRunning)

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
        guard let image, let cg = image.cgImage else {
            status = "Image has no CGImage."
            failed = true
            return
        }
        isRunning = true
        defer { isRunning = false }
        do {
            // Step 1: Vision classification → labels
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])
            let observations = (request.results as? [VNClassificationObservation]) ?? []
            let topLabels = observations
                .filter { $0.confidence > 0.10 }
                .prefix(10)
                .map { "\($0.identifier) (\(String(format: "%.0f%%", $0.confidence * 100)))" }

            // Step 2: pass labels into the language model and ask if they
            // depict the named dish
            let session = LanguageModelSession(instructions: """
            You judge whether a set of image classification labels likely describe a specific dish. \
            Be conservative — only say matches=true if the labels clearly point at the named dish.
            """)
            let labelText = topLabels.joined(separator: ", ")
            let prompt = "Image labels: \(labelText)\n\nDoes this image likely show the dish: \(dishGuess)?"
            let response = try await session.respond(
                to: prompt,
                generating: ImageMatchAnswer.self
            )

            var out = "Vision labels:\n\(topLabels.joined(separator: "\n"))\n\n"
            out += "Model judgment:\n"
            out += "matches = \(response.content.matches)\n"
            out += "reason  = \(response.content.reason)\n"
            status = out
            ok = true
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

@Generable
struct ImageMatchAnswer {
    @Guide(description: "True only if the image labels clearly point at the named dish; false otherwise.")
    var matches: Bool
    @Guide(description: "Brief reason for the judgment.")
    var reason: String
}
