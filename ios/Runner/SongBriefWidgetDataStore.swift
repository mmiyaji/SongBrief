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
    let persistedSnapshots = SnapshotFileStore.readRecentSnapshots(
      limit: comparisonDayCount + 1
    )
    let persistedSnapshotCount = SnapshotFileStore.snapshotCount()
    guard let summary = buildSummary(
      from: persistedSnapshots,
      including: snapshot,
      snapshotCount: persistedSnapshotCount
    ) else {
      defaults.removeObject(forKey: summaryKey)
      reloadWidgetTimelines()
      return
    }
    defaults.set(summary, forKey: summaryKey)
    reloadWidgetTimelines()
  }

  /// Rebuilds every widget field from snapshot history. The supplied snapshot
  /// is merged into persisted history because the file may have been read
  /// before the final max-merge completed.
  static func buildSummary(
    from persistedSnapshots: [[String: Any]],
    including suppliedSnapshot: [String: Any]? = nil,
    snapshotCount totalSnapshotCount: Int? = nil
  ) -> [String: Any]? {
    var snapshotsByDate: [String: [String: Any]] = [:]
    for snapshot in persistedSnapshots {
      guard let dateKey = snapshot["dateKey"] as? String else {
        continue
      }
      snapshotsByDate[dateKey] = mergeSnapshots(
        snapshotsByDate[dateKey],
        with: snapshot
      )
    }
    if let suppliedSnapshot,
       let dateKey = suppliedSnapshot["dateKey"] as? String {
      if let persisted = snapshotsByDate[dateKey] {
        // The file write already applied the active profile's merge policy.
        // A raw capture from the caller can be stale (especially after a
        // profile change), so it may extend an equivalent persisted profile
        // but never replace a persisted profile for the same day.
        let persistedSignature = persisted["filterSignature"] as? String
        let suppliedSignature = suppliedSnapshot["filterSignature"] as? String
        if persistedSignature == suppliedSignature {
          snapshotsByDate[dateKey] = mergeSnapshots(
            persisted,
            with: suppliedSnapshot
          )
        }
      } else {
        snapshotsByDate[dateKey] = suppliedSnapshot
      }
    }

    let snapshots = snapshotsByDate.values.sorted {
      string($0["dateKey"]) < string($1["dateKey"])
    }
    guard let latest = snapshots.last,
          latest["dateKey"] as? String != nil else {
      return nil
    }

    let comparison = snapshots.dropLast().last.flatMap {
      comparableDelta(previous: $0, current: latest)
    }
    let comparisonDeltas = dailyPlayDeltas(
      from: snapshots,
      dayCount: comparisonDayCount
    )
    let previousDeltas = Array(comparisonDeltas.prefix(trendDayCount))
    let recentDeltas = Array(comparisonDeltas.suffix(trendDayCount))

    var summary: [String: Any] = [
      "latestCapturedAtMillis": integer(latest["capturedAtMillis"]),
      "snapshotCount": totalSnapshotCount ?? snapshots.count,
      "hasComparableDelta": comparison != nil,
      "playDelta": comparison?["playDelta"] ?? 0,
      "skipDelta": comparison?["skipDelta"] ?? 0,
      "listeningSecondsDelta": comparison?["listeningSecondsDelta"] ?? 0,
      "observedDays": comparison?["observedDays"] ?? 0,
      "dailyPlayDeltas": recentDeltas,
      "recent7PlayDelta": sum(recentDeltas, key: "playDelta"),
      "previous7PlayDelta": sum(previousDeltas, key: "playDelta"),
      "recent7ListeningSecondsDelta": sum(
        recentDeltas,
        key: "listeningSecondsDelta"
      ),
      "recent7ObservedDays": observedDays(in: recentDeltas),
      "previous7ObservedDays": observedDays(in: previousDeltas),
    ]
    if let topTrack = comparison?["topTrack"] as? [String: Any] {
      summary["topTrackTitle"] = topTrack["title"] as? String ?? ""
      summary["topTrackArtist"] = topTrack["artist"] as? String ?? ""
      summary["topTrackPlayDelta"] = integer(topTrack["playDelta"])
    }
    return summary
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
    var snapshotsByDate: [String: [String: Any]] = [:]
    for snapshot in snapshots {
      guard
        let dateKey = snapshot["dateKey"] as? String,
        (snapshot["filterSignature"] as? String) == latestSignature
      else {
        continue
      }
      snapshotsByDate[dateKey] = mergeSnapshots(
        snapshotsByDate[dateKey],
        with: snapshot
      )
    }
    let calendar = gregorianCalendar

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

  private static func mergeSnapshots(
    _ existing: [String: Any]?,
    with incoming: [String: Any]
  ) -> [String: Any] {
    guard let existing else {
      return incoming
    }
    return SnapshotMerge.merge(existing, incoming)
  }

  private static func comparableDelta(
    previous: [String: Any],
    current: [String: Any]
  ) -> [String: Any]? {
    guard
      (previous["filterSignature"] as? String) ==
        (current["filterSignature"] as? String)
    else {
      return nil
    }
    let previousDateKey = previous["dateKey"] as? String
    let currentDateKey = current["dateKey"] as? String
    let observedDays: Int
    if let previousDateKey,
       let currentDateKey,
       let previousDate = date(from: previousDateKey),
       let currentDate = date(from: currentDateKey) {
      observedDays = abs(
        gregorianCalendar.dateComponents(
          [.day],
          from: previousDate,
          to: currentDate
        ).day ?? 0
      )
    } else {
      observedDays = 0
    }

    let previousTracks = Dictionary(
      uniqueKeysWithValues: (previous["tracks"] as? [[String: Any]] ?? [])
        .compactMap { track -> (String, [String: Any])? in
          guard let id = track["id"] as? String else {
            return nil
          }
          return (id, track)
        }
    )
    var trackDeltas: [[String: Any]] = []
    for track in current["tracks"] as? [[String: Any]] ?? [] {
      guard
        let id = track["id"] as? String,
        let previousTrack = previousTracks[id]
      else {
        continue
      }
      let playDelta = positiveDifference(
        integer(track["playCount"]),
        integer(previousTrack["playCount"])
      )
      let skipDelta = positiveDifference(
        integer(track["skipCount"]),
        integer(previousTrack["skipCount"])
      )
      guard playDelta > 0 || skipDelta > 0 else {
        continue
      }
      trackDeltas.append([
        "id": id,
        "title": track["title"] as? String ?? "",
        "artist": track["artist"] as? String ?? "",
        "playDelta": playDelta,
        "skipDelta": skipDelta,
        "listeningSecondsDelta": positiveDifference(
          integer(track["listeningSeconds"]),
          integer(previousTrack["listeningSeconds"])
        ),
      ])
    }
    trackDeltas.sort {
      let playOrder = integer($0["playDelta"]) - integer($1["playDelta"])
      if playOrder != 0 {
        return playOrder > 0
      }
      let skipOrder = integer($0["skipDelta"]) - integer($1["skipDelta"])
      if skipOrder != 0 {
        return skipOrder > 0
      }
      return string($0["title"]) < string($1["title"])
    }

    var result: [String: Any] = [
      "playDelta": positiveDifference(
        integer(current["totalPlayCount"]),
        integer(previous["totalPlayCount"])
      ),
      "skipDelta": positiveDifference(
        integer(current["totalSkipCount"]),
        integer(previous["totalSkipCount"])
      ),
      "listeningSecondsDelta": positiveDifference(
        integer(current["totalListeningSeconds"]),
        integer(previous["totalListeningSeconds"])
      ),
      "observedDays": observedDays,
    ]
    if let topTrack = trackDeltas.first {
      result["topTrack"] = topTrack
    }
    return result
  }

  private static func positiveDifference(_ current: Int, _ previous: Int) -> Int {
    max(0, current - previous)
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
    return gregorianCalendar.date(
      from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
    )
  }

  private static func dateKey(for date: Date) -> String {
    let components = gregorianCalendar.dateComponents(
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

  private static var gregorianCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
  }
}
