import Testing
import Foundation
@testable import AppModule

@Suite("RevisionDiffer")
struct RevisionDiffTests {

    private func makeStep(_ id: UUID, index: Int, text: String, technique: String? = nil, minutes: Int? = nil) -> Step {
        Step(id: id, index: index, text: text, technique: technique, estimatedMinutes: minutes)
    }

    private func makeIngredient(_ id: UUID, name: String, quantity: String) -> Ingredient {
        Ingredient(id: id, name: name, quantity: quantity)
    }

    private func revision(steps: [Step] = [], ingredients: [Ingredient] = []) -> Revision {
        Revision(index: 1, ingredients: ingredients, steps: steps)
    }

    @Test("identical revisions produce empty diff")
    func emptyDiff() {
        let id = UUID()
        let a = revision(steps: [makeStep(id, index: 1, text: "Sear meat")])
        let b = revision(steps: [makeStep(id, index: 1, text: "Sear meat")])

        let diff = RevisionDiffer.diff(from: a, to: b)

        #expect(diff.isEmpty)
    }

    @Test("step added is classified as .added")
    func stepAdded() {
        let stableID = UUID()
        let newID = UUID()
        let before = revision(steps: [makeStep(stableID, index: 1, text: "Sear meat")])
        let after = revision(steps: [
            makeStep(stableID, index: 1, text: "Sear meat"),
            makeStep(newID, index: 2, text: "Soak in cold water for 15 min")
        ])

        let diff = RevisionDiffer.diff(from: before, to: after)

        #expect(diff.stepDiffs.count == 1)
        #expect(diff.stepDiffs.first?.kind == .added)
        #expect(diff.stepDiffs.first?.after?.id == newID)
    }

    @Test("step removed is classified as .removed")
    func stepRemoved() {
        let keptID = UUID()
        let goneID = UUID()
        let before = revision(steps: [
            makeStep(keptID, index: 1, text: "Sear meat"),
            makeStep(goneID, index: 2, text: "Old step")
        ])
        let after = revision(steps: [makeStep(keptID, index: 1, text: "Sear meat")])

        let diff = RevisionDiffer.diff(from: before, to: after)

        #expect(diff.stepDiffs.count == 1)
        #expect(diff.stepDiffs.first?.kind == .removed)
        #expect(diff.stepDiffs.first?.before?.id == goneID)
    }

    @Test("step text change is classified as .edited")
    func stepEdited() {
        let id = UUID()
        let before = revision(steps: [makeStep(id, index: 1, text: "Use 2 tbsp vinegar")])
        let after = revision(steps: [makeStep(id, index: 1, text: "Use 1 tbsp vinegar")])

        let diff = RevisionDiffer.diff(from: before, to: after)

        #expect(diff.stepDiffs.count == 1)
        #expect(diff.stepDiffs.first?.kind == .edited)
    }

    @Test("step reordered with same content is classified as .moved")
    func stepMoved() {
        let aID = UUID()
        let bID = UUID()
        let before = revision(steps: [
            makeStep(aID, index: 1, text: "Marinate"),
            makeStep(bID, index: 2, text: "Sear")
        ])
        let after = revision(steps: [
            makeStep(bID, index: 1, text: "Sear"),
            makeStep(aID, index: 2, text: "Marinate")
        ])

        let diff = RevisionDiffer.diff(from: before, to: after)

        #expect(diff.stepDiffs.count == 2)
        #expect(diff.stepDiffs.allSatisfy { $0.kind == .moved })
    }

    @Test("ingredient quantity change is classified as .edited")
    func ingredientEdited() {
        let id = UUID()
        let before = revision(ingredients: [makeIngredient(id, name: "Chinkiang vinegar", quantity: "2 tbsp")])
        let after = revision(ingredients: [makeIngredient(id, name: "Chinkiang vinegar", quantity: "1 tbsp")])

        let diff = RevisionDiffer.diff(from: before, to: after)

        #expect(diff.ingredientDiffs.count == 1)
        #expect(diff.ingredientDiffs.first?.kind == .edited)
        #expect(diff.ingredientDiffs.first?.after?.quantity == "1 tbsp")
    }

    @Test("new ingredient appears as .added")
    func ingredientAdded() {
        let keepID = UUID()
        let newID = UUID()
        let before = revision(ingredients: [makeIngredient(keepID, name: "Chicken", quantity: "300g")])
        let after = revision(ingredients: [
            makeIngredient(keepID, name: "Chicken", quantity: "300g"),
            makeIngredient(newID, name: "Shaoxing wine", quantity: "1 tsp")
        ])

        let diff = RevisionDiffer.diff(from: before, to: after)

        #expect(diff.ingredientDiffs.count == 1)
        #expect(diff.ingredientDiffs.first?.kind == .added)
        #expect(diff.ingredientDiffs.first?.after?.name == "Shaoxing wine")
    }
}
