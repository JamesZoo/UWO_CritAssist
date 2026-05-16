import Foundation

enum ChangeAttribution {
    static func changes(causedBy feedbackID: UUID, in revisions: [Revision]) -> [Change] {
        revisions.flatMap(\.changes).filter { $0.feedbackID == feedbackID }
    }

    static func revisionsAddressing(feedbackID: UUID, in revisions: [Revision]) -> [Revision] {
        revisions.filter { $0.addressedFeedbackIDs.contains(feedbackID) }
    }

    static func feedback(for change: Change, in feedbacks: [Feedback]) -> Feedback? {
        guard let fid = change.feedbackID else { return nil }
        return feedbacks.first { $0.id == fid }
    }

    static func changesGrouped(by feedbacks: [Feedback], in revisions: [Revision]) -> [(Feedback, [Change])] {
        let allChanges = revisions.flatMap(\.changes)
        var result: [(Feedback, [Change])] = []
        for fb in feedbacks {
            let related = allChanges.filter { $0.feedbackID == fb.id }
            if !related.isEmpty {
                result.append((fb, related))
            }
        }
        return result
    }
}
