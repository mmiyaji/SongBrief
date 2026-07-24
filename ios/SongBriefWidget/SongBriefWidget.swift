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
  let dailyPlayDeltas: [SongBriefWidgetDailyPlayDelta]
  let recent7PlayDelta: Int
  let previous7PlayDelta: Int
  let recent7ListeningSecondsDelta: Int
  let recent7ObservedDays: Int
  let previous7ObservedDays: Int
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
    dailyPlayDeltas = (dictionary["dailyPlayDeltas"] as? [[String: Any]] ?? [])
      .compactMap(SongBriefWidgetDailyPlayDelta.init(dictionary:))
    recent7PlayDelta = Self.int(dictionary["recent7PlayDelta"]) ?? 0
    previous7PlayDelta = Self.int(dictionary["previous7PlayDelta"]) ?? 0
    recent7ListeningSecondsDelta =
      Self.int(dictionary["recent7ListeningSecondsDelta"]) ?? 0
    recent7ObservedDays = Self.int(dictionary["recent7ObservedDays"]) ?? 0
    previous7ObservedDays = Self.int(dictionary["previous7ObservedDays"]) ?? 0
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

struct SongBriefWidgetDailyPlayDelta: Identifiable {
  let dateKey: String
  let playDelta: Int
  let listeningSecondsDelta: Int
  let hasData: Bool

  var id: String { dateKey }

  init?(dictionary: [String: Any]) {
    guard let dateKey = dictionary["dateKey"] as? String else {
      return nil
    }
    self.dateKey = dateKey
    if let value = dictionary["playDelta"] as? Int {
      playDelta = value
    } else {
      playDelta = (dictionary["playDelta"] as? NSNumber)?.intValue ?? 0
    }
    if let value = dictionary["listeningSecondsDelta"] as? Int {
      listeningSecondsDelta = value
    } else {
      listeningSecondsDelta =
        (dictionary["listeningSecondsDelta"] as? NSNumber)?.intValue ?? 0
    }
    if let value = dictionary["hasData"] as? Bool {
      hasData = value
    } else {
      hasData = (dictionary["hasData"] as? NSNumber)?.boolValue ?? false
    }
  }

  var dayLabel: String {
    guard let day = dateKey.split(separator: "-").last else {
      return ""
    }
    return String(Int(day) ?? 0)
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

      if family == .systemMedium {
        HStack(alignment: .bottom, spacing: 14) {
          playDelta(summary, size: 30)
            .frame(maxWidth: 105, alignment: .leading)
          dailyTrend(summary.dailyPlayDeltas)
        }

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
        playDelta(summary, size: 32)
        Text(localized("\(summary.snapshotCount) recorded days", "記録 \(summary.snapshotCount)日"))
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
  }

  private func playDelta(
    _ summary: SongBriefWidgetSummary,
    size: CGFloat
  ) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 5) {
      Text("+\(summary.playDelta)")
        .font(.system(size: size, weight: .black, design: .rounded))
        .foregroundStyle(Color(red: 0.08, green: 0.56, blue: 0.48))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(localized("plays", "再生"))
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
    }
  }

  private func dailyTrend(
    _ values: [SongBriefWidgetDailyPlayDelta]
  ) -> some View {
    let maximum = max(
      values.filter(\.hasData).map(\.playDelta).max() ?? 0,
      1
    )
    let hasTrend = values.contains(where: \.hasData)

    return VStack(alignment: .leading, spacing: 4) {
      Text(localized("Daily gains", "日ごとの増加"))
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)

      if hasTrend {
        HStack(alignment: .bottom, spacing: 4) {
          ForEach(values) { value in
            VStack(spacing: 2) {
              Spacer(minLength: 0)
              if value.hasData {
                Capsule()
                  .fill(
                    value.id == values.last?.id
                      ? Color(red: 0.08, green: 0.56, blue: 0.48)
                      : Color(red: 0.08, green: 0.56, blue: 0.48).opacity(0.35)
                  )
                  .frame(
                    height: max(
                      3,
                      CGFloat(value.playDelta) / CGFloat(maximum) * 27
                    )
                  )
              } else {
                Capsule()
                  .stroke(
                    Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                  )
                  .frame(height: 3)
              }
              Text(value.dayLabel)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
          }
        }
        .frame(height: 41)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trendAccessibilityLabel(values))
      } else {
        Text(localized(
          "Record two consecutive days to show a trend.",
          "連続2日分の記録で表示します"
        ))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 41, alignment: .center)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func trendAccessibilityLabel(
    _ values: [SongBriefWidgetDailyPlayDelta]
  ) -> String {
    let entries = values.compactMap { value in
      value.hasData ? "\(value.dayLabel): +\(value.playDelta)" : nil
    }
    return localized(
      "Daily play gains. \(entries.joined(separator: ", "))",
      "日ごとの再生増加。\(entries.joined(separator: "、"))"
    )
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

struct SongBriefWeeklyWidgetEntryView: View {
  let entry: SongBriefWidgetEntry

  var body: some View {
    widgetBackground {
      if let summary = entry.summary {
        weeklyContent(summary)
      } else {
        emptyContent
      }
    }
  }

  private func weeklyContent(
    _ summary: SongBriefWidgetSummary
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(
          localized("7-day summary", "直近7日のサマリー"),
          systemImage: "chart.bar.xaxis"
        )
        .font(.headline.weight(.bold))
        Spacer(minLength: 4)
        Text(summary.latestCapturedAt, style: .date)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
      }

      HStack(alignment: .bottom, spacing: 14) {
        VStack(alignment: .leading, spacing: 1) {
          Text(localized("Recent 7 days", "直近7日"))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          if summary.recent7ObservedDays > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
              Text("+\(summary.recent7PlayDelta)")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
              Text(localized("plays", "再生"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            }
          } else {
            Text("—")
              .font(.system(size: 32, weight: .black, design: .rounded))
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: 112, alignment: .leading)

        VStack(alignment: .leading, spacing: 2) {
          Text(localized("Previous 7 days", "その前の7日"))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(
            summary.previous7ObservedDays > 0
              ? "+\(summary.previous7PlayDelta)"
              : "—"
          )
          .font(.title3.weight(.bold))
          .foregroundStyle(.primary)
        }
        .frame(maxWidth: 88, alignment: .leading)

        weeklyChart(summary.dailyPlayDeltas)
      }

      HStack(spacing: 12) {
        Label(
          hours(summary.recent7ListeningSecondsDelta),
          systemImage: "headphones"
        )
        Spacer(minLength: 4)
        Label(
          localized(
            "\(summary.recent7ObservedDays)/7 recorded",
            "\(summary.recent7ObservedDays)/7日記録"
          ),
          systemImage: "calendar.badge.checkmark"
        )
      }
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)
    }
  }

  private func weeklyChart(
    _ values: [SongBriefWidgetDailyPlayDelta]
  ) -> some View {
    let maximum = max(
      values.filter(\.hasData).map(\.playDelta).max() ?? 0,
      1
    )

    return HStack(alignment: .bottom, spacing: 3) {
      ForEach(values) { value in
        VStack(spacing: 2) {
          Spacer(minLength: 0)
          if value.hasData {
            Capsule()
              .fill(
                value.id == values.last?.id
                  ? accent
                  : accent.opacity(0.35)
              )
              .frame(
                height: max(
                  3,
                  CGFloat(value.playDelta) / CGFloat(maximum) * 31
                )
              )
          } else {
            Capsule()
              .stroke(
                Color.secondary.opacity(0.3),
                style: StrokeStyle(lineWidth: 1, dash: [2, 2])
              )
              .frame(height: 3)
          }
          Text(value.dayLabel)
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 47)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(trendAccessibilityLabel(values))
  }

  private var emptyContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(
        localized("7-day summary", "直近7日のサマリー"),
        systemImage: "chart.bar.xaxis"
      )
      .font(.headline.weight(.bold))
      Text(localized(
        "Open SongBrief to create listening records.",
        "SongBriefを開いて聴取記録を作成してください。"
      ))
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private var accent: Color {
    Color(red: 0.08, green: 0.56, blue: 0.48)
  }

  private func hours(_ seconds: Int) -> String {
    String(format: "%.1fh", Double(seconds) / 3600)
  }

  private func trendAccessibilityLabel(
    _ values: [SongBriefWidgetDailyPlayDelta]
  ) -> String {
    let entries = values.compactMap { value in
      value.hasData ? "\(value.dayLabel): +\(value.playDelta)" : nil
    }
    return localized(
      "Daily play gains. \(entries.joined(separator: ", "))",
      "日ごとの再生増加。\(entries.joined(separator: "、"))"
    )
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

struct SongBriefTodayWidgetEntryView: View {
  let entry: SongBriefWidgetEntry

  var body: some View {
    widgetBackground {
      if let summary = entry.summary {
        todayContent(summary)
      } else {
        emptyContent
      }
    }
  }

  private func todayContent(
    _ summary: SongBriefWidgetSummary
  ) -> some View {
    let recordedToday = Calendar.current.isDateInToday(
      summary.latestCapturedAt
    )
    let todayDelta = summary.dailyPlayDeltas.last

    return VStack(alignment: .leading, spacing: 8) {
      Label(localized("Today", "今日の記録"), systemImage: "calendar")
        .font(.headline.weight(.bold))

      Spacer(minLength: 0)

      if recordedToday, let todayDelta, todayDelta.hasData {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text("+\(todayDelta.playDelta)")
            .font(.system(size: 34, weight: .black, design: .rounded))
            .foregroundStyle(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          Text(localized("plays", "再生"))
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
        }
        Text(localized("Since yesterday", "昨日の記録から"))
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
      } else if recordedToday {
        Label(
          localized("Recorded today", "本日記録済み"),
          systemImage: "checkmark.circle.fill"
        )
        .font(.title3.weight(.bold))
        .foregroundStyle(accent)
        Text(localized(
          "A previous-day record is needed for comparison.",
          "比較には前日の記録が必要です"
        ))
        .font(.caption2)
        .foregroundStyle(.secondary)
      } else {
        Label(
          localized("Waiting for today's record", "本日の記録待ち"),
          systemImage: "clock"
        )
        .font(.title3.weight(.bold))
        Text(localized("Last record", "最終記録"))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)

      HStack {
        Image(systemName: "arrow.clockwise")
        if recordedToday {
          Text(summary.latestCapturedAt, style: .time)
        } else {
          Text(summary.latestCapturedAt, style: .date)
        }
      }
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)
    }
  }

  private var emptyContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: "calendar")
        .font(.title2)
        .foregroundStyle(accent)
      Text(localized("Today", "今日の記録"))
        .font(.headline.weight(.bold))
      Text(localized(
        "Open SongBrief to create a listening record.",
        "SongBriefを開いて聴取記録を作成してください。"
      ))
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private var accent: Color {
    Color(red: 0.08, green: 0.56, blue: 0.48)
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

struct SongBriefWeeklyWidget: Widget {
  let kind = "SongBriefWeeklyWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SongBriefWidgetProvider()) { entry in
      SongBriefWeeklyWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(
      localized("SongBrief 7-day summary", "SongBrief 直近7日のサマリー")
    )
    .description(localized(
      "Compare recent listening activity with the previous seven days.",
      "直近7日の聴取活動を、その前の7日と比較します。"
    ))
    .supportedFamilies([.systemMedium])
  }

  private func localized(_ english: String, _ japanese: String) -> String {
    Locale.current.languageCode == "ja" ? japanese : english
  }
}

struct SongBriefTodayWidget: Widget {
  let kind = "SongBriefTodayWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SongBriefWidgetProvider()) { entry in
      SongBriefTodayWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(
      localized("SongBrief today", "SongBrief 今日の記録")
    )
    .description(localized(
      "See today's listening increase and latest record time.",
      "今日の再生増加と最終記録時刻を表示します。"
    ))
    .supportedFamilies([.systemSmall])
  }

  private func localized(_ english: String, _ japanese: String) -> String {
    Locale.current.languageCode == "ja" ? japanese : english
  }
}

@main
struct SongBriefWidgetBundle: WidgetBundle {
  var body: some Widget {
    SongBriefWidget()
    SongBriefWeeklyWidget()
    SongBriefTodayWidget()
  }
}
