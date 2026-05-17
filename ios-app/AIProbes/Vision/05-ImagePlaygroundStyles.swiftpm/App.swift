import SwiftUI
import ImagePlayground

// HYPOTHESIS: ImagePlayground.Style has at least two cases in iOS 26:
//   .animation  — confirmed working in probe 04 (cartoon style)
//   .illustration — documented alongside .animation at original launch;
//                   may render more like a detailed illustration than cartoon
//
// If either style name is wrong, the file will fail to compile (red markers).
// Screenshot the red markers and report which line fails.
//
// Goal: determine whether .illustration produces more photorealistic output
// than .animation for cookbook-style food images.

@main
struct VisionProbe05App: App {
    var body: some Scene {
        WindowGroup { Probe05View() }
    }
}

enum StyleChoice: String, CaseIterable, Identifiable {
    case animation    = ".animation"
    case illustration = ".illustration"
    var id: String { rawValue }
}

struct Probe05View: View {
    @State private var prompt: String = "Red-braised pork belly in a clay pot, dark glossy sauce, steam rising, close-up food photography"
    @State private var selectedStyle: StyleChoice = .illustration
    @State private var generatedImage: UIImage?
    @State private var status = "Select a style and tap Generate."
    @State private var ok = false
    @State private var failed = false
    @State private var isRunning = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Vision Probe 5").font(.title.weight(.semibold))
                Text("ImagePlayground — Style comparison")
                    .font(.callout.monospaced())
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

                Picker("Style", selection: $selectedStyle) {
                    ForEach(StyleChoice.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)

                if let generatedImage {
                    Image(uiImage: generatedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .frame(height: 260)
                        .overlay { Image(systemName: "photo.badge.plus").font(.largeTitle).foregroundStyle(.secondary) }
                }

                TextField("Prompt", text: $prompt, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)

                Button {
                    generatedImage = nil
                    ok = false
                    failed = false
                    Task { await run() }
                } label: {
                    if isRunning {
                        HStack { ProgressView(); Text("Generating…") }
                    } else {
                        Text("Generate (\(selectedStyle.rawValue))").frame(maxWidth: .infinity)
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
                .frame(minHeight: 80)
            }
            .padding()
        }
    }

    private var badge: String { ok ? "YES" : failed ? "NO" : "…" }
    private var badgeColor: Color { ok ? .green : failed ? .red : .secondary }

    private func run() async {
        isRunning = true
        defer { isRunning = false }
        do {
            let creator = try await ImageCreator()
            let style: ImagePlaygroundStyle = selectedStyle == .animation ? .animation : .illustration
            var captured: UIImage?
            for try await image in creator.images(
                for: [.text(prompt)],
                style: style,
                limit: 1
            ) {
                if let ui = UIImage(cgImage: image.cgImage) as UIImage? {
                    captured = ui
                    break
                }
            }
            if let captured {
                generatedImage = captured
                status = "Style \(selectedStyle.rawValue) — generated one image; rendering above."
                ok = true
            } else {
                status = "Style \(selectedStyle.rawValue) — creator returned no images."
                failed = true
            }
        } catch {
            status = """
            Style \(selectedStyle.rawValue)
            ERROR
            type: \(type(of: error))
            description: \(error)
            """
            failed = true
        }
    }
}
