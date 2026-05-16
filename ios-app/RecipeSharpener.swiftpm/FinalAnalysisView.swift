import SwiftUI

struct FinalAnalysisView: View {
    @Bindable var vm: FinalAnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.isRunning {
                    ProgressView("Analyzing…")
                } else if let a = vm.analysis {
                    analysisContent(a)
                } else if let err = vm.errorMessage {
                    Text(err).foregroundStyle(.red).padding()
                } else {
                    ContentUnavailableView(
                        "Tap Analyze",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Produces a journey summary and the best base + best variation document.")
                    )
                }
            }
            .navigationTitle("Final analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if let analysis = vm.analysis {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: shareableText(for: analysis),
                            subject: Text(vm.recipe.name),
                            message: Text("Recipe Sharpener analysis")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(vm.analysis == nil ? "Analyze" : "Re-run") {
                        Task { await vm.run() }
                    }
                    .disabled(vm.isRunning)
                }
            }
        }
    }

    /// Compose the shareable text representation of the analysis.
    /// Markdown-formatted so that pasting into Notes, Messages, Mail, or
    /// any other text surface produces a readable artifact.
    private func shareableText(for analysis: RecipeAnalysis) -> String {
        var parts: [String] = []
        parts.append("# \(vm.recipe.name)")
        let summary = analysis.journeySummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            parts.append("## Journey\n\n\(summary)")
        }
        let document = analysis.finalDocument.trimmingCharacters(in: .whitespacesAndNewlines)
        if !document.isEmpty {
            parts.append(document)
        }
        let stats = """
        ---
        Base revisions: \(vm.recipe.revisions.count) · Variations: \(vm.recipe.variations.count) · Feedback: \(totalFeedback())
        """
        parts.append(stats)
        return parts.joined(separator: "\n\n")
    }

    private func analysisContent(_ a: RecipeAnalysis) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard(a)
                documentCard(a)
            }
            .padding()
        }
    }

    private func summaryCard(_ a: RecipeAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Journey summary")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(a.journeySummary).font(.callout)
            Divider().padding(.vertical, 4)
            statRow(label: "Base revisions", value: "\(vm.recipe.revisions.count)")
            statRow(label: "Variations", value: "\(vm.recipe.variations.count)")
            statRow(label: "Total feedback", value: "\(totalFeedback())")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    private func documentCard(_ a: RecipeAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Final document")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey(a.finalDocument))
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.caption)
    }

    private func totalFeedback() -> Int {
        vm.recipe.feedback.count + vm.recipe.variations.reduce(0) { $0 + $1.feedback.count }
    }
}
