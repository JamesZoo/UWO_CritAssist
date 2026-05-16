import SwiftUI
import PhotosUI
import Vision

@main
struct VisionProbe02App: App {
    var body: some Scene {
        WindowGroup { Probe02View() }
    }
}

struct Probe02View: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var status = "Pick a photo, then tap Run."
    @State private var ok = false
    @State private var failed = false
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Vision Probe 2").font(.title.weight(.semibold))
            Text("Vision.VNClassifyImageRequest")
                .font(.callout.monospaced())
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

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
        guard let image, let cg = image.cgImage else {
            status = "Image has no CGImage backing — try another photo."
            failed = true
            return
        }
        isRunning = true
        defer { isRunning = false }
        do {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])
            guard let observations = request.results as? [VNClassificationObservation] else {
                status = "No observations returned (results = \(String(describing: request.results)))."
                failed = true
                return
            }
            let top = observations
                .filter { $0.confidence > 0.05 }
                .prefix(15)
            if top.isEmpty {
                status = "Classifier returned \(observations.count) observations, but none above 5% confidence."
                failed = true
                return
            }
            var out = "Top labels (label · confidence):\n\n"
            for obs in top {
                out += "\(obs.identifier) · \(String(format: "%.0f%%", obs.confidence * 100))\n"
            }
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
