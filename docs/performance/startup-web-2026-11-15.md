# Web startup measurement — 2026-11-15

実PC上のChromiumでprofileビルドを計測。修正後も画面切り替え時の停止は残る。

## 条件

- Windows、Intel Core i5-13400F、Chromium 157、390×844 CSS px、DPR 1。
- 本番アプリのWebデモ1,000曲。同一ブラウザーに保存された「再生中」タブへ遷移。iPhone実機の計測ではない。
- 各ビルド1回ウォームアップ後、修正前・修正後を交互に各3回。全サンプルでdocument visibilityはvisible。
- `loading_preview=1`でデータ読み込み後に4秒待機。アニメーションの安定区間を比較するための意図的な待機であり、実際の起動所要時間には使用できない。
- 修正前は3443d533を基に、現在のブランドアイコン・既存UI修正を適用。修正後との差はローダー更新方法とプラットフォームデータ変換。WebデモではMethodChannel/computeのネイティブ改善は検証できない。
- 同一の計測用entrypoint `tool/perf/startup_profile.dart`、ビルド成果物だけに注入した `browser_startup_probe.js` を使用。production main.dart / web/index.htmlは変更していない。
- `flutter build web --profile --no-wasm-dry-run -t tool/perf/startup_profile.dart --dart-define=SONGBRIEF_AD_MODE=off --dart-define=SONGBRIEF_FIREBASE_CRASHLYTICS_ENABLED=false --dart-define=SONGBRIEF_DEMO_TRACK_COUNT=1000 --output=build/startup-profile`

## 結果（ms）

| 条件 | 回 | データ準備→内容フレーム処理完了 | 切替区間の最大rAF間隔 | 切替区間の25ms超回数 |
|---|---:|---:|---:|---:|
| 修正前 | 1 | 117.7 | 186.7 | 3 |
| 修正前 | 2 | 100.5 | 146.7 | 3 |
| 修正前 | 3 | 121.7 | 173.1 | 2 |
| 修正後 | 1 | 92.9 | 133.3 | 2 |
| 修正後 | 2 | 96.6 | 133.5 | 3 |
| 修正後 | 3 | 79.7 | 120.1 | 2 |

最大rAF間隔の中央値は173.1→133.3ms（約23%短縮）。内容フレーム処理までの中央値は117.7→92.9ms。少数回の同一PC比較であり、統計的な有意差や他端末での改善率は保証しない。

読み込み安定区間は全6回で25ms超が0回、p95は13.4〜13.7ms。切替直後には修正後も123〜139msのlong taskと、続いて83〜92msのlong taskが記録された。切替時の画面構築・描画処理をさらに調査する余地がある。

## 指標と制約

安定区間はflutter-first-frameの500ms後からdata-readyの100ms前まで。切替区間はdata-readyの100ms前からcontent-frameの500ms後まで。content-frameはRiverpodのデータ取得完了後、Flutterのpost-frame callbackで記録し、画面への実提示時刻を直接示すものではない。

rAF間隔はブラウザーmain threadの描画機会を示す代理指標。Flutter/GPUフレーム時間やFPSそのものではない。ブラウザーは約13.3ms周期で動作しており、60Hz固定の想定は置いていない。長時間タスクはPerformanceObserverのlongtask（50ms以上）。ネイティブiOSのライブラリー取得と実ユーザーデータ、コールド起動、他タブは未計測。

生データ: [JSON](startup-web-2026-11-15.json)。先頭2件はウォームアップで集計対象外。計測後の表示: [スクリーンショット](startup-web-2026-11-15.jpg)。計測用JSはローカルbuild出力にのみ注入。
