import SwiftUI
import UIKit
import WidgetKit

private let suiteName = "group.app.songbrief.songbrief"
private let summaryKey = "songbrief.widget.summary.v1"

struct SongBriefWidgetEntry: TimelineEntry {
  let date: Date
  let summary: SongBriefWidgetSummary?
}

struct SongBriefWidgetSummary {
  let latestCapturedAt: Date
  let snapshotCount: Int
  let playDelta: Int
  let listeningSecondsDelta: Int
  let observedDays: Int
  let topTrackTitle: String?
  let topTrackArtist: String?
  let topTrackPlayDelta: Int

  init?(dictionary: [String: Any]) {
    guard let capturedAtMillis = Self.int(dictionary["latestCapturedAtMillis"]) else {
      return nil
    }
    latestCapturedAt = Date(timeIntervalSince1970: Double(capturedAtMillis) / 1000)
    snapshotCount = Self.int(dictionary["snapshotCount"]) ?? 0
    playDelta = Self.int(dictionary["playDelta"]) ?? 0
    listeningSecondsDelta = Self.int(dictionary["listeningSecondsDelta"]) ?? 0
    observedDays = Self.int(dictionary["observedDays"]) ?? 0
    topTrackTitle = dictionary["topTrackTitle"] as? String
    topTrackArtist = dictionary["topTrackArtist"] as? String
    topTrackPlayDelta = Self.int(dictionary["topTrackPlayDelta"]) ?? 0
  }

  private static func int(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    if let value = value as? NSNumber { return value.intValue }
    return nil
  }
}

struct SongBriefWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> SongBriefWidgetEntry {
    SongBriefWidgetEntry(date: Date(), summary: nil)
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (SongBriefWidgetEntry) -> Void
  ) {
    completion(entry())
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<SongBriefWidgetEntry>) -> Void
  ) {
    let current = entry()
    let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    completion(Timeline(entries: [current], policy: .after(nextRefresh)))
  }

  private func entry() -> SongBriefWidgetEntry {
    let dictionary = UserDefaults(suiteName: suiteName)?.dictionary(forKey: summaryKey)
    return SongBriefWidgetEntry(
      date: Date(),
      summary: dictionary.flatMap(SongBriefWidgetSummary.init(dictionary:))
    )
  }
}

struct SongBriefWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SongBriefWidgetEntry

  var body: some View {
    widgetBackground {
      if let summary = entry.summary {
        content(summary)
      } else {
        emptyContent
      }
    }
  }

  @ViewBuilder
  private func content(_ summary: SongBriefWidgetSummary) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("SongBrief", systemImage: "music.note.list")
          .font(.headline.weight(.bold))
        Spacer(minLength: 4)
        Text(summary.latestCapturedAt, style: .date)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
      }

      HStack(alignment: .firstTextBaseline, spacing: 5) {
        Text("+\(summary.playDelta)")
          .font(.system(size: family == .systemSmall ? 32 : 36, weight: .black, design: .rounded))
          .foregroundStyle(Color(red: 0.08, green: 0.56, blue: 0.48))
        Text(localized("plays", "再生"))
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
      }

      if family == .systemMedium {
        HStack(spacing: 18) {
          metric(
            localized("Listening", "聴取時間"),
            value: hours(summary.listeningSecondsDelta)
          )
          metric(
            localized("Window", "集計期間"),
            value: localized("\(summary.observedDays)d", "\(summary.observedDays)日")
          )
          if let title = summary.topTrackTitle {
            VStack(alignment: .leading, spacing: 2) {
              Text(localized("Top song", "トップ曲"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
              Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
              Text("+\(summary.topTrackPlayDelta)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      } else {
        Text(localized("\(summary.snapshotCount) recorded days", "記録 \(summary.snapshotCount)日"))
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
  }

  private var emptyContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: "music.note.list")
        .font(.title2)
        .foregroundStyle(Color(red: 0.08, green: 0.56, blue: 0.48))
      Text("SongBrief")
        .font(.headline.weight(.bold))
      Text(localized("Open the app to create a listening record.", "アプリを開いて聴取記録を作成してください。"))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func metric(_ label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption.weight(.bold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func hours(_ seconds: Int) -> String {
    String(format: "%.1fh", Double(seconds) / 3600)
  }

  private func localized(_ english: String, _ japanese: String) -> String {
    Locale.current.languageCode == "ja" ? japanese : english
  }

  @ViewBuilder
  private func widgetBackground<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content()
        .containerBackground(.fill.tertiary, for: .widget)
    } else {
      content()
        .padding()
        .background(Color(.systemBackground))
    }
  }
}

@main
struct SongBriefWidget: Widget {
  let kind = "SongBriefWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SongBriefWidgetProvider()) { entry in
      SongBriefWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("SongBrief")
    .description(localized("Your latest listening record.", "最新の聴取記録を表示します。"))
    .supportedFamilies([.systemSmall, .systemMedium])
  }

  private func localized(_ english: String, _ japanese: String) -> String {
    Locale.current.languageCode == "ja" ? japanese : english
  }
}
