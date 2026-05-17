import SwiftUI
import UIKit
import CoreText
import UniformTypeIdentifiers

// MARK: - Transferable export

/// A single share item that offers two representations to the system share
/// sheet: a PDF file (for Files, AirDrop, Mail attachments, Print) and plain
/// text (for Notes, iMessage, WeChat, and other text-accepting targets).
/// iOS picks the best representation for each receiving app automatically.
struct RecipeAnalysisExport: Transferable {
    let text: String
    let recipeName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { export in
            guard let data = Self.makePDFData(text: export.text, recipeName: export.recipeName) else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
        ProxyRepresentation(exporting: \.text)
    }

    // MARK: PDF generation — US Letter, multi-page via Core Text framesetter

    static func makePDFData(text: String, recipeName: String) -> Data? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 54
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageWidth - 2 * margin,
            height: pageHeight - 2 * margin
        )
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let attributed = buildAttributedString(from: text)
        guard attributed.length > 0 else { return nil }

        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            var index = 0
            let total = attributed.length
            repeat {
                ctx.beginPage()
                let cgCtx = ctx.cgContext
                // UIGraphicsPDFRenderer uses UIKit coordinates (top-left, Y↓).
                // Core Text expects standard PDF coordinates (bottom-left, Y↑).
                // Flip the CTM so text renders right-way-up at the correct position.
                cgCtx.saveGState()
                cgCtx.translateBy(x: 0, y: pageHeight)
                cgCtx.scaleBy(x: 1, y: -1)
                let path = CGPath(rect: contentRect, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRange(location: index, length: 0),
                    path,
                    nil
                )
                CTFrameDraw(frame, cgCtx)
                cgCtx.restoreGState()
                let visible = CTFrameGetVisibleStringRange(frame)
                guard visible.length > 0 else { break }
                index += visible.length
            } while index < total
        }
    }

    private static func buildAttributedString(from markdown: String) -> NSAttributedString {
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let h1Font = UIFont.systemFont(ofSize: 18, weight: .bold)
        let h2Font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let h3Font = UIFont.systemFont(ofSize: 12, weight: .medium)
        let bodyStyle = makeStyle(lineSpacing: 3, spacingBefore: 0, paragraphSpacing: 4)
        let headingStyle = makeStyle(lineSpacing: 2, spacingBefore: 10, paragraphSpacing: 4)

        let result = NSMutableAttributedString()
        for line in markdown.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            let content: String
            let font: UIFont
            let style: NSParagraphStyle
            if t.hasPrefix("### ") {
                content = String(t.dropFirst(4))
                font = h3Font
                style = headingStyle
            } else if t.hasPrefix("## ") {
                content = String(t.dropFirst(3))
                font = h2Font
                style = headingStyle
            } else if t.hasPrefix("# ") {
                content = String(t.dropFirst(2))
                font = h1Font
                style = headingStyle
            } else if t.hasPrefix("---") {
                content = String(repeating: "─", count: 44)
                font = bodyFont
                style = bodyStyle
            } else {
                content = line
                font = bodyFont
                style = bodyStyle
            }
            result.append(NSAttributedString(
                string: content + "\n",
                attributes: [.font: font, .foregroundColor: UIColor.black, .paragraphStyle: style]
            ))
        }
        return result
    }

    private static func makeStyle(
        lineSpacing: CGFloat,
        spacingBefore: CGFloat,
        paragraphSpacing: CGFloat
    ) -> NSParagraphStyle {
        let s = NSMutableParagraphStyle()
        s.lineSpacing = lineSpacing
        s.paragraphSpacingBefore = spacingBefore
        s.paragraphSpacing = paragraphSpacing
        return s
    }
}

// MARK: - View

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
                    errorView(err)
                } else {
                    servingPickerView()
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
                            item: RecipeAnalysisExport(
                                text: shareableText(for: analysis),
                                recipeName: vm.recipe.name
                            ),
                            preview: SharePreview(vm.recipe.name)
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Re-analyze") {
                            Task { await vm.run() }
                        }
                        .disabled(vm.isRunning)
                    }
                }
            }
        }
    }

    // MARK: - Serving count picker (shown before first analysis)

    private func servingPickerView() -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("For how many people?")
                        .font(.title2.weight(.semibold))
                    Text("adults")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 28) {
                    Button {
                        if vm.targetServings > 1 { vm.targetServings -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(vm.targetServings > 1 ? Color.accentColor : .secondary)
                    }
                    .disabled(vm.targetServings <= 1)

                    Text("\(vm.targetServings)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 90)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: vm.targetServings)

                    Button {
                        if vm.targetServings < 24 { vm.targetServings += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(vm.targetServings < 24 ? Color.accentColor : .secondary)
                    }
                    .disabled(vm.targetServings >= 24)
                }

                if let orig = vm.recipe.servings, orig != vm.targetServings {
                    let factor = Double(vm.targetServings) / Double(orig)
                    let factorStr = factor == factor.rounded() ? "×\(Int(factor))" : String(format: "×%.1f", factor)
                    Text("Original: \(orig) \(orig == 1 ? "person" : "people") · Scale \(factorStr)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                        .animation(.easeInOut, value: vm.targetServings)
                }
            }
            .padding(28)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 32)

            Spacer()

            Button {
                Task { await vm.run() }
            } label: {
                Text("Analyze")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Analysis result

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try again") {
                Task { await vm.run() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Journey summary")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(a.journeySummary).font(.callout)
            Divider().padding(.vertical, 2)

            // Serving count stepper — change and tap Re-analyze to rescale
            HStack {
                Text(servingsLabel(langIsCJK: langIsCJK)).foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $vm.targetServings, in: 1...24) {
                    Text("\(vm.targetServings)")
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
            .font(.caption)

            if vm.targetServings != a.targetServings {
                Text(reanalyzeHint(langIsCJK: langIsCJK))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

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
            markdownBody(a.finalDocument)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func markdownBody(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                markdownLine(line)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func markdownLine(_ line: String) -> some View {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("### ") {
            Text(LocalizedStringKey(String(t.dropFirst(4))))
                .font(.subheadline.weight(.semibold))
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if t.hasPrefix("## ") {
            Text(LocalizedStringKey(String(t.dropFirst(3))))
                .font(.headline)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if t.hasPrefix("# ") {
            Text(LocalizedStringKey(String(t.dropFirst(2))))
                .font(.title3.weight(.bold))
                .padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if t.hasPrefix("---") || t.hasPrefix("===") {
            Divider().padding(.vertical, 4)
        } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•").font(.callout).foregroundStyle(.secondary)
                Text(LocalizedStringKey(String(t.dropFirst(2)))).font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if t.isEmpty {
            Color.clear.frame(height: 4)
        } else {
            Text(LocalizedStringKey(line)).font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.caption)
    }

    // MARK: - Helpers

    private var langIsCJK: Bool {
        LanguageHeuristics.isMostlyCJK(vm.recipe.name)
    }

    private func servingsLabel(langIsCJK: Bool) -> String {
        langIsCJK ? "份量" : "Serves"
    }

    private func reanalyzeHint(langIsCJK: Bool) -> String {
        langIsCJK ? "已修改份量 — 点击「重新分析」更新" : "Serving count changed — tap Re-analyze to update"
    }

    private func totalFeedback() -> Int {
        vm.recipe.feedback.count + vm.recipe.variations.reduce(0) { $0 + $1.feedback.count }
    }

    private func shareableText(for analysis: RecipeAnalysis) -> String {
        let summary = analysis.journeySummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = analysis.finalDocument.trimmingCharacters(in: .whitespacesAndNewlines)
        let revisionCount = vm.recipe.revisions.count
        let variationCount = vm.recipe.variations.count
        let feedbackCount = totalFeedback()
        var parts: [String] = ["# \(vm.recipe.name)"]
        if !summary.isEmpty { parts.append("## Journey\n\n\(summary)") }
        if !document.isEmpty { parts.append(document) }
        parts.append("---\nBase revisions: \(revisionCount) · Variations: \(variationCount) · Feedback: \(feedbackCount)")
        return parts.joined(separator: "\n\n")
    }
}
