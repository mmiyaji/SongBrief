import Foundation
import WidgetKit

enum SongBriefWidgetDataStore {
  static let suiteName = "group.app.songbrief.songbrief"
  static let summaryKey = "songbrief.widget.summary.v1"

  static func update(summary: [String: Any]?) {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      return
    }
    if let summary {
      defaults.set(summary, forKey: summaryKey)
    } else {
      defaults.removeObject(forKey: summaryKey)
    }
    WidgetCenter.shared.reloadTimelines(ofKind: "SongBriefWidget")
  }

  static func updateAfterBackgroundCapture(snapshot: [String: Any]) {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      return
    }
    var summary = defaults.dictionary(forKey: summaryKey) ?? [:]
    summary["latestCapturedAtMillis"] = snapshot["capturedAtMillis"]
    summary["snapshotCount"] = SongBriefSnapshotRefresh.localSnapshots().count
    defaults.set(summary, forKey: summaryKey)
    WidgetCenter.shared.reloadTimelines(ofKind: "SongBriefWidget")
  }
}
