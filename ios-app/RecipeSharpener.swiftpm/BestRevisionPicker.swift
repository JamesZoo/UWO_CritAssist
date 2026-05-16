import Foundation

protocol RevisionedOwner {
    var revisions: [Revision] { get }
    var feedback: [Feedback] { get }
}

extension Recipe: RevisionedOwner {}
extension Variation: RevisionedOwner {}

enum BestRevisionPicker {
    static func bestRevision(for owner: RevisionedOwner) -> Revision? {
        guard !owner.revisions.isEmpty else { return nil }
        let feedbackByRev = Dictionary(grouping: owner.feedback, by: \.revisionID)
        let scored = owner.revisions.map { rev -> (Revision, Double) in
            (rev, score(revision: rev, feedback: feedbackByRev[rev.id] ?? []))
        }
        return scored.max { $0.1 < $1.1 }?.0
    }

    static func score(revision: Revision, feedback: [Feedback]) -> Double {
        let ratings = feedback.compactMap { $0.rating }
        if ratings.isEmpty {
            return Double(revision.index) * 0.01
        }
        let avg = Double(ratings.reduce(0, +)) / Double(ratings.count)
        return avg + Double(revision.index) * 0.001
    }
}
