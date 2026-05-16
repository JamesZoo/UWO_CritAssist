import Foundation

struct StepDiff: Sendable, Hashable {
    enum Kind: String, Sendable, Hashable {
        case added
        case removed
        case edited
        case moved
    }
    var kind: Kind
    var before: Step?
    var after: Step?
}

struct IngredientDiff: Sendable, Hashable {
    enum Kind: String, Sendable, Hashable {
        case added
        case removed
        case edited
    }
    var kind: Kind
    var before: Ingredient?
    var after: Ingredient?
}

struct RevisionDiff: Sendable, Hashable {
    var stepDiffs: [StepDiff]
    var ingredientDiffs: [IngredientDiff]

    var isEmpty: Bool { stepDiffs.isEmpty && ingredientDiffs.isEmpty }
}

enum RevisionDiffer {
    static func diff(from previous: Revision, to next: Revision) -> RevisionDiff {
        RevisionDiff(
            stepDiffs: diffSteps(previous: previous.steps, next: next.steps),
            ingredientDiffs: diffIngredients(previous: previous.ingredients, next: next.ingredients)
        )
    }

    static func diffSteps(previous: [Step], next: [Step]) -> [StepDiff] {
        var diffs: [StepDiff] = []
        let prevByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        let nextByID = Dictionary(uniqueKeysWithValues: next.map { ($0.id, $0) })

        for n in next {
            if let p = prevByID[n.id] {
                if p == n { continue }
                let contentEqual = p.text == n.text
                    && p.technique == n.technique
                    && p.estimatedMinutes == n.estimatedMinutes
                if contentEqual && p.index != n.index {
                    diffs.append(StepDiff(kind: .moved, before: p, after: n))
                } else {
                    diffs.append(StepDiff(kind: .edited, before: p, after: n))
                }
            } else {
                diffs.append(StepDiff(kind: .added, before: nil, after: n))
            }
        }
        for p in previous where nextByID[p.id] == nil {
            diffs.append(StepDiff(kind: .removed, before: p, after: nil))
        }
        return diffs
    }

    static func diffIngredients(previous: [Ingredient], next: [Ingredient]) -> [IngredientDiff] {
        var diffs: [IngredientDiff] = []
        let prevByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        let nextByID = Dictionary(uniqueKeysWithValues: next.map { ($0.id, $0) })

        for n in next {
            if let p = prevByID[n.id] {
                if p == n { continue }
                diffs.append(IngredientDiff(kind: .edited, before: p, after: n))
            } else {
                diffs.append(IngredientDiff(kind: .added, before: nil, after: n))
            }
        }
        for p in previous where nextByID[p.id] == nil {
            diffs.append(IngredientDiff(kind: .removed, before: p, after: nil))
        }
        return diffs
    }
}
