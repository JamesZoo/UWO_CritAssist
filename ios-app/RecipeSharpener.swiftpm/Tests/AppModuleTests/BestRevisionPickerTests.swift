import Testing
import Foundation
@testable import AppModule

@Suite("BestRevisionPicker")
struct BestRevisionPickerTests {

    private func makeRevision(index: Int) -> Revision {
        Revision(index: index)
    }

    @Test("returns nil for owner with no revisions")
    func nilWhenEmpty() {
        let r = Recipe(name: "X", revisions: [])
        #expect(BestRevisionPicker.bestRevision(for: r) == nil)
    }

    @Test("returns the only revision when there is one")
    func singleRevision() {
        let rev = makeRevision(index: 1)
        let r = Recipe(name: "X", revisions: [rev])
        #expect(BestRevisionPicker.bestRevision(for: r)?.id == rev.id)
    }

    @Test("without ratings, the latest-index revision wins")
    func latestWinsWithoutRatings() {
        let r1 = makeRevision(index: 1)
        let r2 = makeRevision(index: 2)
        let r3 = makeRevision(index: 3)
        let r = Recipe(name: "X", revisions: [r1, r2, r3])
        #expect(BestRevisionPicker.bestRevision(for: r)?.id == r3.id)
    }

    @Test("higher average rating wins over later revision")
    func ratingTrumpsRecency() {
        let r1 = makeRevision(index: 1)
        let r2 = makeRevision(index: 2)
        let feedback = [
            Feedback(text: "Great", rating: 5, revisionID: r1.id),
            Feedback(text: "Meh", rating: 2, revisionID: r2.id)
        ]
        let recipe = Recipe(name: "X", revisions: [r1, r2], feedback: feedback)
        #expect(BestRevisionPicker.bestRevision(for: recipe)?.id == r1.id)
    }

    @Test("average across multiple feedbacks is used")
    func averagesRatings() {
        let r1 = makeRevision(index: 1)
        let r2 = makeRevision(index: 2)
        let feedback = [
            Feedback(text: "Good", rating: 4, revisionID: r1.id),
            Feedback(text: "Good", rating: 4, revisionID: r1.id),
            Feedback(text: "OK", rating: 3, revisionID: r2.id),
            Feedback(text: "OK", rating: 5, revisionID: r2.id)
        ]
        // r1 avg = 4.0, r2 avg = 4.0 — tie broken by higher index
        let recipe = Recipe(name: "X", revisions: [r1, r2], feedback: feedback)
        #expect(BestRevisionPicker.bestRevision(for: recipe)?.id == r2.id)
    }

    @Test("variation uses its own feedback chain")
    func variationIndependent() {
        let r1 = makeRevision(index: 1)
        let r2 = makeRevision(index: 2)
        let v = Variation(
            name: "chili",
            directive: "add chili",
            revisions: [r1, r2],
            feedback: [Feedback(text: "Loved it", rating: 5, revisionID: r1.id)]
        )
        #expect(BestRevisionPicker.bestRevision(for: v)?.id == r1.id)
    }
}
