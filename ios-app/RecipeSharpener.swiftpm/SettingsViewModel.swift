import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    private let store: RecipeStore
    let trace: AITraceLog

    var useMockAI: Bool = true
    var exportURL: URL?
    var errorMessage: String?

    init(store: RecipeStore, trace: AITraceLog) {
        self.store = store
        self.trace = trace
    }

    func loadFixtures() async {
        do {
            for r in Fixtures.allScenarios {
                try await store.save(r)
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func wipeAllData() async {
        do {
            try await store.wipeAll()
            trace.clear()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func exportAll() async {
        do {
            let all = try await store.allRecipes()
            exportURL = try RecipeExporter.writeTempFile(all)
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
