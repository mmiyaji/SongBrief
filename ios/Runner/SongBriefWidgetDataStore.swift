import Foundation
import WidgetKit

enum SongBriefWidgetDataStore {
  static let suiteName = "group.app.songbrief.songbrief"
  static let summaryKey = "songbrief.widget.summary.v1"
  private static let trendDayCount = 7
  private static let comparisonDayCount = trendDayCount * 2
  private static let widgetKinds = [
    "SongBriefWidget",
    "SongBriefWeeklyWidget",
    "SongBriefTodayWidget",
  ]

  static func update(summary: [String: Any]?) {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      return
    }
    if let summary {
      defaults.set(summary, forKey: summaryKey)
    } else {
      defaults.removeObject(forKey: summaryKey)
    }
    reloadWidgetTimelines()
  }

  static func updateAfterBackgroundCapture(snapshot: [String: Any]) {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      return
    }
    let snapshots = SongBriefSnapshotRefresh.localSnapshots()
    var summary = defaults.dictionary(forKey: summaryKey) ?? [:]
    summary["latestCapturedAtMillis"] = snapshot["capturedAtMillis"]
    summary["snapshotCount"] = snapshots.count
    let comparisonDeltas = dailyPlayDeltas(
      from: snapshots,
      dayCount: comparisonDayCount
    )
    let previousDeltas = Array(comparisonDeltas.prefix(trendDayCount))
    let recentDeltas = Array(comparisonDeltas.suffix(trendDayCount))
    summary["dailyPlayDeltas"] = recentDeltas
    summary["recent7PlayDelta"] = sum(
      recentDeltas,
      key: "playDelta"
    )
    summary["previous7PlayDelta"] = sum(
      previousDeltas,
      key: "playDelta"
    )
    summary["recent7ListeningSecondsDelta"] = sum(
      recentDeltas,
      key: "listeningSecondsDelta"
    )
    summary["recent7ObservedDays"] = observedDays(in: recentDeltas)
    summary["previous7ObservedDays"] = observedDays(in: previousDeltas)
    defaults.set(summary, forKey: summaryKey)
    reloadWidgetTimelines()
  }

  static func dailyPlayDeltas(
    from snapshots: [[String: Any]],
    dayCount: Int = 7
  ) -> [[String: Any]] {
    guard
      let latest = snapshots.max(by: {
        string($0["dateKey"]) < string($1["dateKey"])
      }),
      let latestDateKey = latest["dateKey"] as? String,
      let latestDate = date(from: latestDateKey)
    else {
      return []
    }

    let latestSignature = latest["filterSignature"] as? String
    let snapshotsByDate = Dictionary(
      uniqueKeysWithValues: snapshots.compactMap { snapshot -> (String, [String: Any])? in
        guard
          let dateKey = snapshot["dateKey"] as? String,
          (snapshot["filterSignature"] as? String) == latestSignature
        else {
          return nil
        }
        return (dateKey, snapshot)
      }
    )
    let calendar = Calendar.current

    return (0..<max(0, dayCount)).reversed().compactMap {
      dayOffset -> [String: Any]? in
      guard
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: latestDate),
        let previousDate = calendar.date(byAdding: .day, value: -1, to: date)
      else {
        return nil
      }
      let currentDateKey = dateKey(for: date)
      let previousDateKey = dateKey(for: previousDate)
      let current = snapshotsByDate[currentDateKey]
      let previous = snapshotsByDate[previousDateKey]
      let hasData = current != nil && previous != nil
      let playDelta = hasData
        ? max(
          0,
          integer(current?["totalPlayCount"]) -
            integer(previous?["totalPlayCount"])
        )
        : 0
      let listeningSecondsDelta = hasData
        ? max(
          0,
          integer(current?["totalListeningSeconds"]) -
            integer(previous?["totalListeningSeconds"])
        )
        : 0
      return [
        "dateKey": currentDateKey,
        "playDelta": playDelta,
        "listeningSecondsDelta": listeningSecondsDelta,
        "hasData": hasData,
      ]
    }
  }

  private static func sum(
    _ values: [[String: Any]],
    key: String
  ) -> Int {
    values.reduce(0) { total, value in
      guard value["hasData"] as? Bool == true else {
        return total
      }
      return total + integer(value[key])
    }
  }

  private static func observedDays(in values: [[String: Any]]) -> Int {
    values.filter { $0["hasData"] as? Bool == true }.count
  }

  private static func reloadWidgetTimelines() {
    for kind in widgetKinds {
      WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
  }

  private static func date(from dateKey: String) -> Date? {
    let parts = dateKey.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else {
      return nil
    }
    return Calendar.current.date(
      from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
    )
  }

  private static func dateKey(for date: Date) -> String {
    let components = Calendar.current.dateComponents(
      [.year, .month, .day],
      from: date
    )
    return String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
  }

  private static func integer(_ value: Any?) -> Int {
    if let value = value as? Int {
      return value
    }
    return (value as? NSNumber)?.intValue ?? 0
  }

  private static func string(_ value: Any?) -> String {
    value as? String ?? ""
  }
}
