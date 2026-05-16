import Testing
import Foundation
@testable import AppModule

@Suite("ChangeAttribution")
struct ChangeAttributionTests {

    private func revision(index: Int, changes: [Change], addressed: [UUID] = []) -> Revision {
        Revision(index: index, rationale: "", changes: changes, addressedFeedbackIDs: addressed)
    }

    @Test("collects all changes caused by a single feedback across revisions")
    func aggregatesAcrossRevisions() {
        let fid = UUID()
        let other = UUID()
        let revs = [
            revision(index: 1, changes: [
                Change(kind: .stepEdited, summary: "Reduced vinegar", feedbackID: fid),
                Change(kind: .ingredientAdded, summary: "Add ginger", feedbackID: other)
            ]),
            revision(index: 2, changes: [
                Change(kind: .stepAdded, summary: "Soak meat", feedbackID: fid)
            ])
        ]

        let found = ChangeAttribution.changes(causedBy: fid, in: revs)

        #expect(found.count == 2)
        #expect(found.allSatisfy { $0.feedbackID == fid })
    }

    @Test("ignores changes with no feedbackID (initial creation changes)")
    func ignoresUnattributedChanges() {
        let fid = UUID()
        let revs = [
            revision(index: 1, changes: [
                Change(kind: .stepAdded, summary: "Initial step", feedbackID: nil)
            ]),
            revision(index: 2, changes: [
                Change(kind: .stepEdited, summary: "Tweak", feedbackID: fid)
            ])
        ]

        let found = ChangeAttribution.changes(causedBy: fid, in: revs)

        #expect(found.count == 1)
        #expect(found.first?.summary == "Tweak")
    }

    @Test("looks up the feedback that caused a specific change")
    func looksUpCausingFeedback() {
        let fid = UUID()
        let fb = Feedback(id: fid, text: "Too sour", revisionID: UUID())
        let change = Change(kind: .stepEdited, summary: "Less vinegar", feedbackID: fid)

        let result = ChangeAttribution.feedback(for: change, in: [fb])

        #expect(result?.id == fid)
    }

    @Test("returns nil for changes with no feedbackID")
    func returnsNilForUnattributed() {
        let change = Change(kind: .stepAdded, summary: "Initial", feedbackID: nil)
        let fb = Feedback(text: "X", revisionID: UUID())

        #expect(ChangeAttribution.feedback(for: change, in: [fb]) == nil)
    }

    @Test("groups changes by feedback, omitting feedback with no resulting changes")
    func groupsAndOmitsEmpty() {
        let fb1 = Feedback(text: "Too salty", revisionID: UUID())
        let fb2 = Feedback(text: "Looked great", revisionID: UUID())
        let revs = [
            revision(index: 2, changes: [
                Change(kind: .ingredientEdited, summary: "Less soy", feedbackID: fb1.id)
            ])
        ]

        let grouped = ChangeAttribution.changesGrouped(by: [fb1, fb2], in: revs)

        #expect(grouped.count == 1)
        #expect(grouped.first?.0.id == fb1.id)
        #expect(grouped.first?.1.count == 1)
    }

    @Test("finds revisions whose addressedFeedbackIDs include a given feedback")
    func findsRevisionsAddressingFeedback() {
        let fid = UUID()
        let revs = [
            revision(index: 1, changes: []),
            revision(index: 2, changes: [], addressed: [fid]),
            revision(index: 3, changes: [], addressed: [UUID()])
        ]

        let found = ChangeAttribution.revisionsAddressing(feedbackID: fid, in: revs)

        #expect(found.count == 1)
        #expect(found.first?.index == 2)
    }
}
