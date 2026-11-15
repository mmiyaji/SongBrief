# Opus consultation — 2026-11-15

Claude Codeの`--model opus`で読み取り専用の相談を2回実施。CLIのモデル利用記録はclaude-opus-5-5。以下は2回目の回答であり、最終実装前の静的な見解を含む。

対応: 空イベントの早期returnと空区間の照合省略を採用。背景ぼかしの除去は効果が確認できず不採用。遅延構築はKeepAliveと安定キー、子インデックスの追跡を追加した上で採用し、歌詞の展開状態保持をテストした。カレンダーの履歴準備は4ms目安の小分け処理を追加。測定結果は別の最終レポートを参照。

---

## 結論

起動の数字が変わらなかったのは自然な結果です。今回の2つの修正は、どちらも起動フレームの処理を削っていません。

- **events 空の早期 return**：起動時に開く「再生中」タブはこの処理を通りません。効いたのは概要タブで、初回 387ms → 93ms はこの修正の効果とみています。
- **再生中タブの lazy SliverList**：390×844 の画面では、表示域＋cacheExtent 250px の範囲に Hero・Trend・Lyrics・Recent がほぼ収まります。そのため起動時に省かれている項目は実質ありません。
- **data-ready → post-frame（94ms）の中身**：Web ではラスタライズも同じフレーム内で同期実行されます。つまりこの区間は、ローディング画面から全体シェルへ切り替わるフレームの build・layout・paint・raster をすべて含みます。Dart の集計処理ではなく、初回のウィジェット・RenderObject 生成、テキストのシェーピング、blur・影の描画が主体と推定しています（未計測）。

## 起動フレームの候補（小さい順）

**1. 下部クローム（ミニプレイヤーとタブ）の BackdropFilter**（`home_screen.dart:657-658`）
- data フレームで初めて登場する、ほぼ全幅の blur（sigma 22）です。さらに影（blurRadius 30）と ClipRRect が重なっています。CanvasKit では初回の blur がシェーダー準備を含めて高くつく典型パターンです。
- 背景の不透明度はライトテーマで 0.97、ダークテーマで 0.86 なので、blur の見た目への寄与はごくわずかです。
- まず計測専用ビルドで blur だけ外して差を見るのを勧めます。製品コードの変更は、差が大きいと確認できてから検討してください。

**2. 内訳の計測**
- `tool/perf/startup_profile.dart` の `main()` で `debugProfileBuildsEnabled`、`debugProfileBuildsEnabledUserWidgets`、`debugProfileLayoutsEnabled`、`debugProfilePaintsEnabled` を true にします。
- これでウィジェット名つきで BUILD・LAYOUT・PAINT に分解できます。94ms のうちラスタ（GPU 側）がどれだけかもここで分かります。

**3. `_TrendPanel` の初回計算**（`playing_section.dart:1117-1145`、`shared_helpers.dart:2782-2798`）
- 初回は `_trackSnapshotById` が90スナップショット×最大1,000件を線形に探索します。データのある範囲が見つかるまで、最大3つの range を計算します。
- `_snapshotsWithProvisionalCurrent` は90件のコピーとソートを1回の build で最大4回行います（:1135 と range ごと）。
- 数ms程度の見込みです。安全な最小修正は、ソート済みスナップショットを `_updateTrendCache` で1回だけ作って State に保持することです。
- tracks を id の二分探索にする案もありますが、`library_snapshot_store_io.dart:619/650` の生成経路で id 順になっているか未確認なので、今は勧めません。

**4. 計測区間外だがデモ起動に効く処理**（`music_stats_repository.dart:565-571`）
- `_sampleSnapshotHistory` は、スナップショットのために `LibraryOverview.fromTracks`（全件ソートを複数回）を90回実行しています。使っているのは tracks と合計値だけです。
- data-ready より前の処理なので今回の指標には出ませんが、Web デモの実際の起動時間には効いています。

空白表示を出さずに確実に効くのは1（の計測）です。2で内訳を見ないまま、表示を遅延させる方向の変更はしないほうがよいです。

## 変更ファイルの回帰レビュー

**`listening_activity.dart:70-72, 116`**：問題なし。
- events が空なら結果は必ず空で、返している const リストも変更不可なので、以前の `List.unmodifiable` と同じ扱いになります。
- `intervalEvents.isEmpty` での `continue` も、budget は区間内でしか使われず、`remainingTotal` も区間ごとなので結果は変わりません。

**`playing_section.dart:9-25`（lazy SliverList）**：⚠️ 実際の挙動回帰があります。
- **画面外で State が破棄されます。**
  - SliverList は cacheExtent の外に出た項目を dispose します。KeepAlive の指定がありません。
  - 以前の Column では全項目が保持されていました。
  - 例：Recent で「さらに表示」を重ねて深くスクロールすると、`_TrendPanelState` の選択 range（:1062）と `_CollapsibleLyricsTextState` の展開状態（:3127）が失われます。
  - 戻ったときは Trend を最初から計算し直すので、スクロール中のカクつきも新たに起きます。
  - 逆に Recent まで行ってから上に戻ると、`_RecentTracksPanelState._visibleCount`（:1459）がリセットされます。
- **index ずれで State がずれます。** `_OutsideLibraryNotice` や Trend の有無（:72-87）で項目の位置が変わります。キーがないため、Column よりも State の取り違えや作り直しが起きやすくなっています。
- **最小の対処**：起動時の効果がないので、元の Column ＋ SliverToBoxAdapter に戻すのが一番安全です。lazy を残すなら、3つの State に `AutomaticKeepAliveClientMixin` を付け、各パネルに `ValueKey` を付けて `findChildIndexCallback` を指定してください。

## 追加すべきテスト
- 再生中タブで Trend の range を変える → 歌詞を展開する → Recent で「さらに表示」を押す → 最下部までスクロールして最上部に戻る。この後、3つの状態がすべて残っていることを確認する widget test。
- outsideLibrary が切り替わり、項目の index がずれても Trend や Recent の State が混ざらないこと。
- events 空の早期 return：履歴があっても uncovered・relocations が空であること。区間内に events がない区間を挟んでも、既存の relocation の期待値が変わらないこと。

今回も静的な読解のみです。ファイルの変更、ビルド、計測は行っていません。