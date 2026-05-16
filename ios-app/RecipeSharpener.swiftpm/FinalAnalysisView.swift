import SwiftUI
import UIKit
import CoreText

struct FinalAnalysisView: View {
    @Bindable var vm: FinalAnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showShareOptions = false

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
                    ProgressView("Analyzing…")
                }
            }
            .navigationTitle("Final analysis")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard vm.analysis == nil, !vm.isRunning else { return }
                await vm.run()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if vm.analysis != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showShareOptions = true
                        } label: {
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
            .sheet(isPresented: $showShareOptions) {
                if let analysis = vm.analysis {
                    ShareOptionsSheet(
                        text: shareableText(for: analysis),
                        recipeName: vm.recipe.name
                    )
                }
            }
        }
    }

    // MARK: - Subviews

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

    // MARK: - Helpers

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

// MARK: - Share options sheet

private struct ShareOptionsSheet: View {
    let text: String
    let recipeName: String
    @Environment(\.dismiss) private var dismiss

    @State private var pdfURL: URL?
    @State private var pdfReady = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ShareLink(
                        item: text,
                        subject: Text(recipeName),
                        message: Text("Recipe Sharpener analysis")
                    ) {
                        Label("Share as formatted text", systemImage: "text.alignleft")
                    }

                    if !pdfReady {
                        HStack {
                            Label("Preparing PDF…", systemImage: "doc.richtext")
                            Spacer()
                            ProgressView()
                        }
                        .foregroundStyle(.secondary)
                    } else if let url = pdfURL {
                        ShareLink(item: url) {
                            Label("Save / share as PDF", systemImage: "doc.richtext")
                        }
                    } else {
                        Label("PDF unavailable", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("\"Share as formatted text\" works with Notes, iMessage, WeChat, and other apps. \"Save / share as PDF\" opens the system share sheet where you can save to Files, AirDrop, print, or attach to Mail.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Share analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                // Run PDF generation off the main actor — UIGraphicsPDFRenderer
                // and Core Text are safe on background threads for data-only work.
                let url = await Task.detached(priority: .userInitiated) {
                    Self.makePDF(text: text, recipeName: recipeName)
                }.value
                pdfURL = url
                pdfReady = true
            }
        }
    }

    // MARK: PDF generation — US Letter, multi-page via Core Text framesetter

    static func makePDF(text: String, recipeName: String) -> URL? {
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

        let data = renderer.pdfData { ctx in
            var index = 0
            let total = attributed.length
            repeat {
                ctx.beginPage()
                let cgCtx = ctx.cgContext
                // UIGraphicsPDFRenderer uses UIKit coordinates (top-left origin, Y↓).
                // Core Text expects standard PDF coordinates (bottom-left origin, Y↑).
                // Flip the CTM so CTFrameDraw renders text right-way-up at the correct
                // position: content rect at y=margin from top in UIKit terms.
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

        let safe = recipeName
            .components(separatedBy: CharacterSet.alphanumerics
                .union(.init(charactersIn: " -_")).inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
        let name = safe.isEmpty ? "recipe-analysis" : safe
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // Converts the Markdown-formatted shareableText into an NSAttributedString
    // with styled headings, body text, and horizontal rules.  Intentionally
    // simple: handles # / ## / ### prefix and --- dividers; everything else
    // is body text.  Inline Markdown (bold, italic) is left as literal characters
    // — the PDF is for sharing/archival, not for display in a Markdown renderer.
    private static func buildAttributedString(from markdown: String) -> NSAttributedString {
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let h1Font = UIFont.systemFont(ofSize: 18, weight: .bold)
        let h2Font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let h3Font = UIFont.systemFont(ofSize: 12, weight: .medium)
        let bodyStyle = makeParagraphStyle(lineSpacing: 3, spacingBefore: 0, paragraphSpacing: 4)
        let headingStyle = makeParagraphStyle(lineSpacing: 2, spacingBefore: 10, paragraphSpacing: 4)

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

    private static func makeParagraphStyle(
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
