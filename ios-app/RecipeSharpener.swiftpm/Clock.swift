import Foundation

protocol Clock: Sendable {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

struct FixedClock: Clock {
    let now: Date
    init(_ now: Date) { self.now = now }
}
