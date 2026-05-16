import SwiftUI

struct SettingsView: View {
    @Bindable var vm: SettingsViewModel
    var onAIBackendChange: (Bool) -> Void = { _ in }
    var onListNeedsRefresh: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                aboutSection
                aiSection
                testingSection
                traceSection
                if let err = vm.errorMessage {
                    Section { Text(err).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: BuildInfo.fullVersionLine)
            LabeledContent("Build date", value: BuildInfo.buildDate)
            LabeledContent("AI backend", value: vm.useMockAI ? "mock" : "FoundationModels")
        }
    }

    private var aiSection: some View {
        Section {
            Toggle("Use mock AI (deterministic)", isOn: Binding(
                get: { vm.useMockAI },
                set: { newValue in
                    vm.useMockAI = newValue
                    onAIBackendChange(newValue)
                }
            ))
        } header: {
            Text("Model")
        } footer: {
            Text("Switch off to use Apple Intelligence on-device (FoundationModels). Requires an Apple Intelligence-capable device running iOS 26+.")
        }
    }

    private var testingSection: some View {
        Section {
            Button {
                Task {
                    await vm.loadFixtures()
                    onListNeedsRefresh()
                }
            } label: {
                Label("Load fixture scenarios", systemImage: "shippingbox")
            }

            Button {
                Task { await vm.exportAll() }
            } label: {
                Label("Export all recipes as JSON", systemImage: "square.and.arrow.up.on.square")
            }

            if let url = vm.exportURL {
                ShareLink(item: url) {
                    Label("Share export…", systemImage: "square.and.arrow.up")
                }
            }

            Button(role: .destructive) {
                Task {
                    await vm.wipeAllData()
                    onListNeedsRefresh()
                }
            } label: {
                Label("Wipe all data", systemImage: "trash")
            }
        } header: {
            Text("Black-box testing")
        } footer: {
            Text("Fixtures load preset scenarios (e.g. 宫爆鸡丁) so test cases are reproducible. Export captures the full state for sharing or comparing across runs.")
        }
    }

    private var traceSection: some View {
        Section {
            if vm.trace.entries.isEmpty {
                Text("No AI calls yet.").foregroundStyle(.secondary).font(.callout)
            } else {
                ForEach(vm.trace.entries) { entry in
                    traceRow(entry)
                }
                Button("Clear trace") { vm.trace.clear() }
                    .foregroundStyle(.red)
            }
        } header: {
            Text("AI trace")
        } footer: {
            Text("Each AI call's input, output, latency, and backend (mock / on-device / cloud-compute).")
        }
    }

    private func traceRow(_ e: AITraceEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(e.service).font(.caption.weight(.semibold))
                Spacer()
                Text(e.backend.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(backendColor(e.backend).opacity(0.20), in: Capsule())
                Text("\(e.latencyMS) ms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(e.summary).font(.caption).foregroundStyle(.secondary)
            Text(e.result).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            if let err = e.errorDescription {
                Text(err).font(.caption2).foregroundStyle(.red).lineLimit(2)
            }
        }
    }

    private func backendColor(_ b: AIBackendKind) -> Color {
        switch b {
        case .mock: return .gray
        case .onDevice: return .green
        case .cloudCompute: return .blue
        case .unknown: return .orange
        }
    }
}
