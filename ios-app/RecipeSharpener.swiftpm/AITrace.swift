import Foundation
import Observation

enum AIBackendKind: String, Sendable, Codable { case mock, onDevice, cloudCompute, unknown }

struct AITraceEntry: Identifiable, Sendable, Codable, Hashable {
    let id: UUID
    let service: String
    let summary: String
    let result: String
    let backend: AIBackendKind
    let latencyMS: Int
    let timestamp: Date
    let errorDescription: String?
}

@Observable
@MainActor
final class AITraceLog {
    private(set) var entries: [AITraceEntry] = []
    private let cap: Int

    init(cap: Int = 200) { self.cap = cap }

    func record(_ entry: AITraceEntry) {
        entries.insert(entry, at: 0)
        if entries.count > cap {
            entries = Array(entries.prefix(cap))
        }
    }

    func clear() { entries = [] }
}

private func msElapsed(since start: Date) -> Int {
    Int(Date().timeIntervalSince(start) * 1000)
}

struct TracedRecipeGenerator: RecipeGenerator {
    let inner: RecipeGenerator
    let trace: AITraceLog
    let backend: AIBackendKind

    func generateInitialRecipe(dishName: String) async throws -> InitialRecipeDraft {
        let start = Date()
        do {
            let r = try await inner.generateInitialRecipe(dishName: dishName)
            await record(start: start, summary: "generate: '\(dishName)'", result: "name='\(r.name)', \(r.steps.count) steps", error: nil)
            return r
        } catch {
            await record(start: start, summary: "generate: '\(dishName)'", result: "error", error: error)
            throw error
        }
    }

    func parseRecipe(fromURL url: URL, expectedDish description: String?) async throws -> InitialRecipeDraft {
        let start = Date()
        let label = "parseURL: \(url.host() ?? url.absoluteString)"
        do {
            let r = try await inner.parseRecipe(fromURL: url, expectedDish: description)
            await record(start: start, summary: label, result: "name='\(r.name)', \(r.steps.count) steps", error: nil)
            return r
        } catch {
            await record(start: start, summary: label, result: "error", error: error)
            throw error
        }
    }

    func parseRecipe(fromText text: String, expectedDish description: String?) async throws -> InitialRecipeDraft {
        let start = Date()
        let label = "parseText: \(text.prefix(30))…"
        do {
            let r = try await inner.parseRecipe(fromText: text, expectedDish: description)
            await record(start: start, summary: label, result: "name='\(r.name)', \(r.ingredients.count) ing, \(r.steps.count) steps", error: nil)
            return r
        } catch {
            await record(start: start, summary: label, result: "error", error: error)
            throw error
        }
    }

    @MainActor
    private func record(start: Date, summary: String, result: String, error: Error?) {
        trace.record(AITraceEntry(
            id: UUID(),
            service: "RecipeGenerator",
            summary: summary,
            result: result,
            backend: backend,
            latencyMS: msElapsed(since: start),
            timestamp: Date(),
            errorDescription: error.map(String.init(describing:))
        ))
    }
}

struct TracedRecipeRefiner: RecipeRefiner {
    let inner: RecipeRefiner
    let trace: AITraceLog
    let backend: AIBackendKind

    func refine(recipeID: UUID, recipeName: String, previousRevision: Revision, newFeedback: [Feedback], feedbackHistory: [Feedback]) async throws -> RefinedRevisionDraft {
        let start = Date()
        let inputSummary = newFeedback.map(\.text).joined(separator: " | ")
        do {
            let r = try await inner.refine(recipeID: recipeID, recipeName: recipeName, previousRevision: previousRevision, newFeedback: newFeedback, feedbackHistory: feedbackHistory)
            await record(start: start, summary: "refine: '\(inputSummary)'", result: "\(r.changes.count) changes: \(r.rationale)", error: nil)
            return r
        } catch {
            await record(start: start, summary: "refine: '\(inputSummary)'", result: "error", error: error)
            throw error
        }
    }

    func resetContext(for recipeID: UUID) async {
        await inner.resetContext(for: recipeID)
    }

    @MainActor
    private func record(start: Date, summary: String, result: String, error: Error?) {
        trace.record(AITraceEntry(
            id: UUID(),
            service: "RecipeRefiner",
            summary: summary,
            result: result,
            backend: backend,
            latencyMS: msElapsed(since: start),
            timestamp: Date(),
            errorDescription: error.map(String.init(describing:))
        ))
    }
}

struct TracedVariationBrancher: VariationBrancher {
    let inner: VariationBrancher
    let trace: AITraceLog
    let backend: AIBackendKind

    func branch(from baseRevision: Revision, baseRecipeName: String, directive: String) async throws -> VariationDraft {
        let start = Date()
        do {
            let r = try await inner.branch(from: baseRevision, baseRecipeName: baseRecipeName, directive: directive)
            await record(start: start, summary: "branch: '\(baseRecipeName)' + '\(directive)'", result: "name='\(r.name)', \(r.changes.count) changes", error: nil)
            return r
        } catch {
            await record(start: start, summary: "branch: '\(baseRecipeName)' + '\(directive)'", result: "error", error: error)
            throw error
        }
    }

    @MainActor
    private func record(start: Date, summary: String, result: String, error: Error?) {
        trace.record(AITraceEntry(
            id: UUID(),
            service: "VariationBrancher",
            summary: summary,
            result: result,
            backend: backend,
            latencyMS: msElapsed(since: start),
            timestamp: Date(),
            errorDescription: error.map(String.init(describing:))
        ))
    }
}

struct TracedRecipeFinalizer: RecipeFinalizer {
    let inner: RecipeFinalizer
    let trace: AITraceLog
    let backend: AIBackendKind

    func finalize(recipe: Recipe, targetServings: Int) async throws -> RecipeAnalysis {
        let start = Date()
        do {
            let r = try await inner.finalize(recipe: recipe, targetServings: targetServings)
            await record(start: start, summary: "finalize: '\(recipe.name)' for \(targetServings)", result: r.journeySummary, error: nil)
            return r
        } catch {
            await record(start: start, summary: "finalize: '\(recipe.name)' for \(targetServings)", result: "error", error: error)
            throw error
        }
    }

    @MainActor
    private func record(start: Date, summary: String, result: String, error: Error?) {
        trace.record(AITraceEntry(
            id: UUID(),
            service: "RecipeFinalizer",
            summary: summary,
            result: result,
            backend: backend,
            latencyMS: msElapsed(since: start),
            timestamp: Date(),
            errorDescription: error.map(String.init(describing:))
        ))
    }
}
