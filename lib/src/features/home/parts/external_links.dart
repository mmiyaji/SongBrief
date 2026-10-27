part of '../home_screen.dart';

Future<void> _openAppleMusicTrack(
  BuildContext context,
  LibraryTrack track,
) async {
  await _openExternalUrl(context, appleMusicUrlForTrack(track).toString());
}

Future<void> _openWebSearch(
  BuildContext context,
  String query,
  String subject,
) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_t(context, 'Open web search?', 'Web検索を開きますか？')),
      content: Text(
        _t(
          context,
          'SongBrief will open an external browser and search for "$trimmedQuery" about "$subject". The search terms may include song, artist, or album names and will be sent to the search service.',
          '外部ブラウザで「$subject」について「$trimmedQuery」を検索します。検索語句には曲名、アーティスト名、アルバム名などが含まれ、検索サービスへ送信されます。',
          zh: 'SongBrief 将在外部浏览器中搜索与“$subject”相关的“$trimmedQuery”。搜索词可能包含歌曲、艺人或专辑名称，并会发送到搜索服务。',
          ko: 'SongBrief가 외부 브라우저에서 "$subject"에 대해 "$trimmedQuery"를 검색합니다. 검색어에는 곡명, 아티스트명, 앨범명이 포함될 수 있으며 검색 서비스로 전송됩니다.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(_t(context, 'Cancel', 'キャンセル')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(_t(context, 'Open', '開く')),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  await _openExternalUrl(context, _webSearchUri(trimmedQuery).toString());
}

Future<void> _openExternalUrl(
  BuildContext context,
  String url, {
  bool requireConfirmation = false,
}) async {
  if (requireConfirmation) {
    final confirmed = await _confirmExternalNavigation(context, url);
    if (confirmed != true || !context.mounted) {
      return;
    }
  }

  final uri = Uri.parse(url);
  final messenger = ScaffoldMessenger.maybeOf(context);

  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) {
      return;
    }
  } on Exception {
    // Fall through to the user-facing error below.
  }

  if (!context.mounted) {
    return;
  }

  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        _t(
          context,
          'Could not open $url',
          '$url を開けませんでした',
          zh: '无法打开 $url',
          ko: '$url을 열 수 없습니다',
        ),
      ),
    ),
  );
}

Future<bool> _confirmExternalNavigation(
  BuildContext context,
  String url,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        _t(
          context,
          'Open external site?',
          '外部サイトを開きますか？',
          zh: '打开外部网站？',
          ko: '외부 사이트를 열까요?',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(
              context,
              'SongBrief will open the following link in an external browser.',
              'SongBriefから外部ブラウザで次のリンクを開きます。',
              zh: 'SongBrief 将在外部浏览器中打开以下链接。',
              ko: 'SongBrief에서 외부 브라우저로 다음 링크를 엽니다.',
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            url,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(_t(context, 'Cancel', 'キャンセル')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(_t(context, 'Open', '開く')),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
