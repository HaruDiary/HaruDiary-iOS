import Foundation

/// How far a year's city has grown. Every 30 days with a diary raise the city one stage, from 0 (wasteland) to 12.
/// Counted from the diaries themselves; nothing extra is stored.
struct JourneyYearProgress: Equatable {
    static let daysPerStage = 30
    static let finalStage = 12

    let year: Int
    /// Days of the year with at least one diary; several diaries on one day count once.
    let daysWritten: Int

    var stage: Int {
        min(daysWritten / Self.daysPerStage, Self.finalStage)
    }

    /// Days still needed for the next stage; nil once the city is complete.
    var daysToNextStage: Int? {
        guard stage < Self.finalStage else { return nil }
        return (stage + 1) * Self.daysPerStage - daysWritten
    }

    /// 0...1 within the current stage, for a progress bar.
    var stageProgress: Double {
        guard stage < Self.finalStage else { return 1 }
        return Double(daysWritten - stage * Self.daysPerStage) / Double(Self.daysPerStage)
    }
}

extension JourneyRecord {
    func progress(ofYear year: Int) -> JourneyYearProgress {
        JourneyYearProgress(year: year, daysWritten: months.filter { $0.year == year }.reduce(0) { $0 + $1.days.count })
    }
}
