import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

String appText(
  BuildContext context,
  String en,
  String ja, {
  String? zh,
  String? ko,
}) {
  final languageTag = _localizationLanguageTag(context);
  return switch (languageTag) {
    'ja' => ja,
    'zh-Hans' => zh ?? _copyTranslations[en]?.zh ?? en,
    'ko' => ko ?? _copyTranslations[en]?.ko ?? en,
    _ => en,
  };
}

String _localizationLanguageTag(BuildContext context) {
  final localizations = Localizations.of<AppLocalizations>(
    context,
    AppLocalizations,
  );
  if (localizations != null) {
    return localizations.localeName.replaceAll('_', '-');
  }
  return Localizations.localeOf(context).toLanguageTag();
}

String localizeRuntimeMessage(BuildContext context, String message) {
  final translation = _runtimeMessages[message];
  if (translation == null) {
    return message;
  }
  return appText(
    context,
    message,
    translation.ja,
    zh: translation.zh,
    ko: translation.ko,
  );
}

class _LocalizedCopy {
  const _LocalizedCopy({required this.ja, required this.zh, required this.ko});

  final String ja;
  final String zh;
  final String ko;
}

const _runtimeMessages = <String, _LocalizedCopy>{
  'Premium is unlocked by launch mode.': _LocalizedCopy(
    ja: '起動モードによりプレミアムが有効です。',
    zh: '当前启动模式已解锁高级版。',
    ko: '실행 모드로 프리미엄이 활성화되어 있습니다.',
  ),
  'Purchase is waiting for store confirmation.': _LocalizedCopy(
    ja: 'ストアの購入確認を待っています。',
    zh: '正在等待商店确认购买。',
    ko: '스토어의 구매 확인을 기다리고 있습니다.',
  ),
  'Restore request sent to the store.': _LocalizedCopy(
    ja: 'ストアへ復元リクエストを送信しました。',
    zh: '已向商店发送恢复请求。',
    ko: '스토어에 복원 요청을 보냈습니다.',
  ),
  'Premium is active. Ads are removed.': _LocalizedCopy(
    ja: 'プレミアムが有効です。広告は表示されません。',
    zh: '高级版已启用，广告已移除。',
    ko: '프리미엄이 활성화되어 광고가 제거되었습니다.',
  ),
  'Purchase is pending.': _LocalizedCopy(
    ja: '購入処理が保留中です。',
    zh: '购买处理中。',
    ko: '구매가 대기 중입니다.',
  ),
  'Purchase failed.': _LocalizedCopy(
    ja: '購入に失敗しました。',
    zh: '购买失败。',
    ko: '구매에 실패했습니다.',
  ),
  'Store is not available.': _LocalizedCopy(
    ja: 'ストアを利用できません。',
    zh: '商店当前不可用。',
    ko: '스토어를 사용할 수 없습니다.',
  ),
  'Configure the premium product in App Store Connect.': _LocalizedCopy(
    ja: 'App Store Connectで非消耗型の商品を設定すると購入が有効になります。',
    zh: '在 App Store Connect 中设置非消耗型商品后即可购买。',
    ko: 'App Store Connect에서 비소모성 상품을 설정하면 구매가 활성화됩니다.',
  ),
};

const _copyTranslations = <String, _LocalizedCopy>{
  'Demo': _LocalizedCopy(ja: 'デモ', zh: '演示', ko: '데모'),
  'Allow': _LocalizedCopy(ja: '許可', zh: '允许', ko: '허용'),
  'Refresh': _LocalizedCopy(ja: '更新', zh: '刷新', ko: '새로 고침'),
  'Cancel': _LocalizedCopy(ja: 'キャンセル', zh: '取消', ko: '취소'),
  'Add': _LocalizedCopy(ja: '追加', zh: '添加', ko: '추가'),
  'None': _LocalizedCopy(ja: 'なし', zh: '无', ko: '없음'),
  'Open': _LocalizedCopy(ja: '開く', zh: '打开', ko: '열기'),
  'Manage': _LocalizedCopy(ja: '管理', zh: '管理', ko: '관리'),
  'Off': _LocalizedCopy(ja: 'オフ', zh: '关闭', ko: '끔'),
  'On': _LocalizedCopy(ja: 'オン', zh: '开启', ko: '켬'),
  'System': _LocalizedCopy(ja: 'システム', zh: '系统', ko: '시스템'),
  'Dark': _LocalizedCopy(ja: 'ダーク', zh: '深色', ko: '다크'),
  'Light': _LocalizedCopy(ja: 'ライト', zh: '浅色', ko: '라이트'),
  'English': _LocalizedCopy(ja: '英語', zh: '英语', ko: '영어'),
  'Japanese': _LocalizedCopy(ja: '日本語', zh: '日语', ko: '일본어'),
  'Simplified Chinese': _LocalizedCopy(ja: '簡体字中国語', zh: '简体中文', ko: '중국어 간체'),
  'Korean': _LocalizedCopy(ja: '韓国語', zh: '韩语', ko: '한국어'),
  'Playing': _LocalizedCopy(ja: '再生中', zh: '播放中', ko: '재생 중'),
  'Playing now': _LocalizedCopy(ja: '再生中', zh: '正在播放', ko: '재생 중'),
  'Paused': _LocalizedCopy(ja: '一時停止中', zh: '已暂停', ko: '일시 정지됨'),
  'Play': _LocalizedCopy(ja: '再生', zh: '播放', ko: '재생'),
  'Pause': _LocalizedCopy(ja: '一時停止', zh: '暂停', ko: '일시 정지'),
  'Next': _LocalizedCopy(ja: '次へ', zh: '下一首', ko: '다음'),
  'Previous': _LocalizedCopy(ja: '前へ', zh: '上一首', ko: '이전'),
  'More': _LocalizedCopy(ja: 'その他', zh: '更多', ko: '더보기'),
  'Overview': _LocalizedCopy(ja: '概要', zh: '概览', ko: '개요'),
  'Rankings': _LocalizedCopy(ja: 'ランキング', zh: '排行', ko: '순위'),
  'Library': _LocalizedCopy(ja: 'ライブラリ', zh: '资料库', ko: '라이브러리'),
  'Settings': _LocalizedCopy(ja: '設定', zh: '设置', ko: '설정'),
  'Songs': _LocalizedCopy(ja: '曲', zh: '歌曲', ko: '곡'),
  'Tracks': _LocalizedCopy(ja: '曲', zh: '曲目', ko: '트랙'),
  'Artists': _LocalizedCopy(ja: 'アーティスト', zh: '艺人', ko: '아티스트'),
  'Albums': _LocalizedCopy(ja: 'アルバム', zh: '专辑', ko: '앨범'),
  'Genres': _LocalizedCopy(ja: 'ジャンル', zh: '流派', ko: '장르'),
  'Playlists': _LocalizedCopy(ja: 'プレイリスト', zh: '播放列表', ko: '플레이리스트'),
  'Recent': _LocalizedCopy(ja: '最近', zh: '最近', ko: '최근'),
  'Recently Played': _LocalizedCopy(ja: '最近再生した曲', zh: '最近播放', ko: '최근 재생'),
  'Recently played songs': _LocalizedCopy(
    ja: '最近再生した曲',
    zh: '最近播放的歌曲',
    ko: '최근 재생한 곡',
  ),
  'Top Songs': _LocalizedCopy(ja: 'トップ曲', zh: '热门歌曲', ko: '인기 곡'),
  'Top Artists': _LocalizedCopy(ja: 'トップアーティスト', zh: '热门艺人', ko: '인기 아티스트'),
  'Top Albums': _LocalizedCopy(ja: 'トップアルバム', zh: '热门专辑', ko: '인기 앨범'),
  'Top song': _LocalizedCopy(ja: 'トップ曲', zh: '热门歌曲', ko: '인기 곡'),
  'Plays': _LocalizedCopy(ja: '再生回数', zh: '播放次数', ko: '재생 횟수'),
  'Skips': _LocalizedCopy(ja: 'スキップ', zh: '跳过', ko: '건너뛰기'),
  'Last played': _LocalizedCopy(ja: '最終再生', zh: '上次播放', ko: '마지막 재생'),
  'Recent play': _LocalizedCopy(ja: '直近再生', zh: '最近播放', ko: '최근 재생'),
  'Hours': _LocalizedCopy(ja: '時間', zh: '小时', ko: '시간'),
  'Cloud': _LocalizedCopy(ja: 'クラウド', zh: '云端', ko: '클라우드'),
  'Lyrics': _LocalizedCopy(ja: '歌詞', zh: '歌词', ko: '가사'),
  'Show all lyrics': _LocalizedCopy(
    ja: '歌詞をすべて表示',
    zh: '显示全部歌词',
    ko: '가사 모두 보기',
  ),
  'Show less': _LocalizedCopy(ja: '折りたたむ', zh: '收起', ko: '접기'),
  'This week trend': _LocalizedCopy(ja: '今週の傾向', zh: '本周趋势', ko: '이번 주 추세'),
  'About this trend': _LocalizedCopy(
    ja: 'この傾向について',
    zh: '关于此趋势',
    ko: '이 추세 정보',
  ),
  'How this trend is calculated': _LocalizedCopy(
    ja: 'この傾向の計算方法',
    zh: '此趋势的计算方式',
    ko: '이 추세 계산 방식',
  ),
  'Daily listening records': _LocalizedCopy(
    ja: '日々の聴取記録',
    zh: '每日收听记录',
    ko: '일일 청취 기록',
  ),
  'Listening records': _LocalizedCopy(ja: '聴取記録', zh: '收听记录', ko: '청취 기록'),
  'Listening insights': _LocalizedCopy(
    ja: 'リスニング洞察',
    zh: '收听洞察',
    ko: '청취 인사이트',
  ),
  'Library distribution': _LocalizedCopy(
    ja: 'ライブラリ分布',
    zh: '资料库分布',
    ko: '라이브러리 분포',
  ),
  'Total Plays': _LocalizedCopy(ja: '総再生回数', zh: '总播放次数', ko: '총 재생 횟수'),
  'Searchable track details with play controls': _LocalizedCopy(
    ja: '検索可能な曲詳細と再生コントロール',
    zh: '可搜索的曲目详情和播放控制',
    ko: '검색 가능한 곡 상세와 재생 컨트롤',
  ),
  'Sort': _LocalizedCopy(ja: '並び替え', zh: '排序', ko: '정렬'),
  'Recently played': _LocalizedCopy(ja: '最近再生', zh: '最近播放', ko: '최근 재생'),
  'Most played': _LocalizedCopy(ja: '再生回数順', zh: '播放最多', ko: '가장 많이 재생'),
  'Most skipped': _LocalizedCopy(ja: 'スキップ順', zh: '跳过最多', ko: '가장 많이 건너뜀'),
  'Title': _LocalizedCopy(ja: 'タイトル', zh: '标题', ko: '제목'),
  'Music Access': _LocalizedCopy(ja: 'ミュージックアクセス', zh: '音乐访问权限', ko: '음악 접근'),
  'Authorization': _LocalizedCopy(ja: '認証状態', zh: '授权状态', ko: '인증 상태'),
  'Data source': _LocalizedCopy(ja: 'データソース', zh: '数据来源', ko: '데이터 소스'),
  'Last record': _LocalizedCopy(ja: '最終記録', zh: '最后记录', ko: '마지막 기록'),
  'Display & Operation': _LocalizedCopy(
    ja: '表示と操作',
    zh: '显示与操作',
    ko: '표시 및 조작',
  ),
  'Theme': _LocalizedCopy(ja: 'テーマ', zh: '主题', ko: '테마'),
  'Appearance': _LocalizedCopy(ja: '外観', zh: '外观', ko: '외관'),
  'Language': _LocalizedCopy(ja: '言語', zh: '语言', ko: '언어'),
  'Security': _LocalizedCopy(ja: 'セキュリティ', zh: '安全', ko: '보안'),
  'App Lock': _LocalizedCopy(ja: 'アプリロック', zh: '应用锁', ko: '앱 잠금'),
  'Export & Exclusions': _LocalizedCopy(
    ja: 'エクスポートと除外',
    zh: '导出与隐藏',
    ko: '내보내기 및 제외',
  ),
  'Display & Exclusions': _LocalizedCopy(
    ja: '表示と除外',
    zh: '显示与隐藏',
    ko: '표시 및 제외',
  ),
  'Data Management': _LocalizedCopy(ja: 'データ管理', zh: '数据管理', ko: '데이터 관리'),
  'Premium': _LocalizedCopy(ja: 'プレミアム', zh: '高级版', ko: '프리미엄'),
  'App Info': _LocalizedCopy(ja: 'アプリ情報', zh: '应用信息', ko: '앱 정보'),
  'Application': _LocalizedCopy(ja: 'アプリケーション', zh: '应用', ko: '애플리케이션'),
  'Version': _LocalizedCopy(ja: 'バージョン', zh: '版本', ko: '버전'),
  'Privacy Policy': _LocalizedCopy(
    ja: 'プライバシーポリシー',
    zh: '隐私政策',
    ko: '개인정보 처리방침',
  ),
  'Terms of Use': _LocalizedCopy(ja: '利用規約', zh: '使用条款', ko: '이용 약관'),
  'Licenses': _LocalizedCopy(ja: 'ライセンス', zh: '许可', ko: '라이선스'),
  'Library rows': _LocalizedCopy(ja: 'ライブラリ行', zh: '资料库行数', ko: '라이브러리 행'),
  'Temporary caches': _LocalizedCopy(ja: '一時キャッシュ', zh: '临时缓存', ko: '임시 캐시'),
  'Clear caches': _LocalizedCopy(ja: 'キャッシュを削除', zh: '删除缓存', ko: '캐시 삭제'),
  'Listening record history': _LocalizedCopy(
    ja: '聴取記録の履歴',
    zh: '收听记录历史',
    ko: '청취 기록 이력',
  ),
  'No records': _LocalizedCopy(ja: '記録なし', zh: '无记录', ko: '기록 없음'),
  'Active exclusions': _LocalizedCopy(ja: '除外ルール', zh: '隐藏规则', ko: '제외 규칙'),
  'Manage hidden items': _LocalizedCopy(
    ja: '非表示項目を管理',
    zh: '管理隐藏项目',
    ko: '숨김 항목 관리',
  ),
  'Hidden playlists': _LocalizedCopy(
    ja: '非表示プレイリスト',
    zh: '隐藏的播放列表',
    ko: '숨긴 플레이리스트',
  ),
  'Hidden genres': _LocalizedCopy(ja: '非表示ジャンル', zh: '隐藏的流派', ko: '숨긴 장르'),
  'Hidden keywords': _LocalizedCopy(ja: '非表示キーワード', zh: '隐藏的关键词', ko: '숨긴 키워드'),
  'Add hidden playlist': _LocalizedCopy(
    ja: '非表示プレイリストを追加',
    zh: '添加隐藏播放列表',
    ko: '숨길 플레이리스트 추가',
  ),
  'Add hidden genre': _LocalizedCopy(
    ja: '非表示ジャンルを追加',
    zh: '添加隐藏流派',
    ko: '숨길 장르 추가',
  ),
  'Add hidden keyword': _LocalizedCopy(
    ja: '非表示キーワードを追加',
    zh: '添加隐藏关键词',
    ko: '숨길 키워드 추가',
  ),
  'Playlist name': _LocalizedCopy(ja: 'プレイリスト名', zh: '播放列表名称', ko: '플레이리스트 이름'),
  'Genre name': _LocalizedCopy(ja: 'ジャンル名', zh: '流派名称', ko: '장르 이름'),
  'Keyword': _LocalizedCopy(ja: 'キーワード', zh: '关键词', ko: '키워드'),
  'Save CSV': _LocalizedCopy(ja: 'CSVを保存', zh: '保存 CSV', ko: 'CSV 저장'),
  'Save JSON': _LocalizedCopy(ja: 'JSONを保存', zh: '保存 JSON', ko: 'JSON 저장'),
  'Prism': _LocalizedCopy(ja: 'プリズム', zh: '棱镜', ko: '프리즘'),
  'Flux': _LocalizedCopy(ja: 'フラックス', zh: '流光', ko: '플럭스'),
  'Ember': _LocalizedCopy(ja: 'エンバー', zh: '余烬', ko: '엠버'),
  'Mono': _LocalizedCopy(ja: 'モノ', zh: '单色', ko: '모노'),
  'Aurora': _LocalizedCopy(ja: 'オーロラ', zh: '极光', ko: '오로라'),
  'Grove': _LocalizedCopy(ja: 'グローブ', zh: '林地', ko: '그로브'),
  'Pulse': _LocalizedCopy(ja: 'パルス', zh: '脉冲', ko: '펄스'),
  'Muse': _LocalizedCopy(ja: 'ミューズ', zh: '缪斯', ko: '뮤즈'),
  'Access and recording settings': _LocalizedCopy(
    ja: 'アクセスと記録設定',
    zh: '访问与记录设置',
    ko: '접근 및 기록 설정',
  ),
  'Active days': _LocalizedCopy(ja: '活動日', zh: '活跃天数', ko: '활동일'),
  'Activity heatmap': _LocalizedCopy(ja: '再生ヒートマップ', zh: '播放热力图', ko: '재생 히트맵'),
  'Activity appears after daily listening records are available.':
      _LocalizedCopy(
        ja: '日々の聴取記録が利用可能になると表示されます。',
        zh: '每日收听记录可用后将显示。',
        ko: '일일 청취 기록을 사용할 수 있으면 표시됩니다.',
      ),
  'Ad mode': _LocalizedCopy(ja: '広告モード', zh: '广告模式', ko: '광고 모드'),
  'Ads removed': _LocalizedCopy(ja: '広告を非表示', zh: '广告已移除', ko: '광고 제거됨'),
  'Album': _LocalizedCopy(ja: 'アルバム', zh: '专辑', ko: '앨범'),
  'Album artist': _LocalizedCopy(ja: 'アルバムアーティスト', zh: '专辑艺人', ko: '앨범 아티스트'),
  'Album artist songs': _LocalizedCopy(
    ja: 'アルバムアーティストの曲',
    zh: '专辑艺人的歌曲',
    ko: '앨범 아티스트의 곡',
  ),
  'Album completion': _LocalizedCopy(ja: 'アルバム制覇率', zh: '专辑完成度', ko: '앨범 완청률'),
  'Album songs': _LocalizedCopy(ja: 'アルバムの曲', zh: '专辑歌曲', ko: '앨범 곡'),
  'All songs': _LocalizedCopy(ja: 'すべての曲', zh: '所有歌曲', ko: '모든 곡'),
  'All songs are in playlists': _LocalizedCopy(
    ja: 'すべての曲がプレイリストに含まれています',
    zh: '所有歌曲都在播放列表中',
    ko: '모든 곡이 플레이리스트에 포함되어 있습니다',
  ),
  'Artist': _LocalizedCopy(ja: 'アーティスト', zh: '艺人', ko: '아티스트'),
  'Artist songs': _LocalizedCopy(ja: 'アーティストの曲', zh: '艺人的歌曲', ko: '아티스트의 곡'),
  'Authorized': _LocalizedCopy(ja: '許可済み', zh: '已授权', ko: '허용됨'),
  'Available': _LocalizedCopy(ja: '利用可能', zh: '可用', ko: '사용 가능'),
  'Available after iOS Music access is granted.': _LocalizedCopy(
    ja: 'iOSミュージックへのアクセス許可後に利用できます。',
    zh: '授予 iOS 音乐访问权限后可用。',
    ko: 'iOS 음악 접근 권한이 허용되면 사용할 수 있습니다.',
  ),
  'Available on devices with Face ID, Touch ID, or passcode authentication.':
      _LocalizedCopy(
        ja: 'Face ID、Touch ID、またはパスコード認証が使える端末で利用できます。',
        zh: '可在支持 Face ID、Touch ID 或密码认证的设备上使用。',
        ko: 'Face ID, Touch ID 또는 암호 인증을 지원하는 기기에서 사용할 수 있습니다.',
      ),
  'Avg plays': _LocalizedCopy(ja: '平均再生', zh: '平均播放', ko: '평균 재생'),
  'Baseline': _LocalizedCopy(ja: '基準', zh: '基准', ko: '기준'),
  'Best weekday': _LocalizedCopy(ja: '最も聴いた曜日', zh: '最佳星期', ko: '가장 많이 들은 요일'),
  'Biggest increases since the previous daily record.': _LocalizedCopy(
    ja: '前回の聴取記録から大きく伸びた曲です。',
    zh: '自上次每日记录以来增长最大的歌曲。',
    ko: '이전 일일 기록 이후 가장 크게 늘어난 곡입니다.',
  ),
  'Buy premium': _LocalizedCopy(ja: 'プレミアムを購入', zh: '购买高级版', ko: '프리미엄 구매'),
  'Calendar': _LocalizedCopy(ja: 'カレンダー', zh: '日历', ko: '캘린더'),
  'Checking...': _LocalizedCopy(ja: '確認中...', zh: '检查中...', ko: '확인 중...'),
  'Clean data': _LocalizedCopy(ja: 'データを削除', zh: '清理数据', ko: '데이터 정리'),
  'Clean generated data': _LocalizedCopy(
    ja: '生成データを全削除',
    zh: '删除生成数据',
    ko: '생성 데이터 삭제',
  ),
  'Clean generated data?': _LocalizedCopy(
    ja: '生成データを削除しますか？',
    zh: '要删除生成数据吗？',
    ko: '생성 데이터를 삭제할까요?',
  ),
  'Clear all': _LocalizedCopy(ja: 'すべて削除', zh: '全部清除', ko: '모두 지우기'),
  'Clear search': _LocalizedCopy(ja: '検索をクリア', zh: '清除搜索', ko: '검색 지우기'),
  'Clear temporary caches?': _LocalizedCopy(
    ja: '一時キャッシュを削除しますか？',
    zh: '要删除临时缓存吗？',
    ko: '임시 캐시를 삭제할까요?',
  ),
  'Cloud items': _LocalizedCopy(ja: 'クラウド項目', zh: '云端项目', ko: '클라우드 항목'),
  'Cloud library items': _LocalizedCopy(
    ja: 'クラウドライブラリ項目',
    zh: '云端资料库项目',
    ko: '클라우드 라이브러리 항목',
  ),
  'Could not clean generated data.': _LocalizedCopy(
    ja: '生成データを削除できませんでした。',
    zh: '无法删除生成数据。',
    ko: '생성 데이터를 삭제할 수 없었습니다.',
  ),
  'Could not delete listening records.': _LocalizedCopy(
    ja: '聴取記録を削除できませんでした。',
    zh: '无法删除收听记录。',
    ko: '청취 기록을 삭제할 수 없었습니다.',
  ),
  'Could not load the music library.': _LocalizedCopy(
    ja: 'ミュージックライブラリを読み込めませんでした。',
    zh: '无法加载音乐资料库。',
    ko: '음악 라이브러리를 불러올 수 없었습니다.',
  ),
  'Could not save the export file.': _LocalizedCopy(
    ja: 'エクスポートファイルを保存できませんでした。',
    zh: '无法保存导出文件。',
    ko: '내보내기 파일을 저장할 수 없었습니다.',
  ),
  'Current streak': _LocalizedCopy(ja: '現在の連続記録', zh: '当前连续记录', ko: '현재 연속 기록'),
  'Delete all listening records?': _LocalizedCopy(
    ja: 'すべての聴取記録を削除しますか？',
    zh: '要删除所有收听记录吗？',
    ko: '모든 청취 기록을 삭제할까요?',
  ),
  'Delete all records': _LocalizedCopy(
    ja: 'すべての記録を削除',
    zh: '删除所有记录',
    ko: '모든 기록 삭제',
  ),
  'Delete old listening records?': _LocalizedCopy(
    ja: '古い聴取記録を削除しますか？',
    zh: '要删除旧的收听记录吗？',
    ko: '오래된 청취 기록을 삭제할까요?',
  ),
  'Delete old records': _LocalizedCopy(
    ja: '古い記録を削除',
    zh: '删除旧记录',
    ko: '오래된 기록 삭제',
  ),
  'Delete records': _LocalizedCopy(ja: '記録を削除', zh: '删除记录', ko: '기록 삭제'),
  'Demo mode': _LocalizedCopy(ja: 'デモモード', zh: '演示模式', ko: '데모 모드'),
  'Denied': _LocalizedCopy(ja: '拒否', zh: '已拒绝', ko: '거부됨'),
  'Device authentication is not available.': _LocalizedCopy(
    ja: '端末認証を利用できません。',
    zh: '设备认证不可用。',
    ko: '기기 인증을 사용할 수 없습니다.',
  ),
  'Diversity score': _LocalizedCopy(
    ja: '聴取多様性スコア',
    zh: '收听多样性分数',
    ko: '청취 다양성 점수',
  ),
  'Duration': _LocalizedCopy(ja: '曲の長さ', zh: '时长', ko: '길이'),
  'Expand listening maps': _LocalizedCopy(
    ja: 'リスニングマップを拡大',
    zh: '展开收听地图',
    ko: '청취 맵 확대',
  ),
  'Explorer': _LocalizedCopy(ja: '探検家', zh: '探索者', ko: '탐험가'),
  'Export was cancelled.': _LocalizedCopy(
    ja: 'エクスポートをキャンセルしました。',
    zh: '已取消导出。',
    ko: '내보내기를 취소했습니다.',
  ),
  'Favorite album': _LocalizedCopy(ja: 'よく聴くアルバム', zh: '最常听专辑', ko: '즐겨 듣는 앨범'),
  'Favorite artist': _LocalizedCopy(
    ja: 'よく聴くアーティスト',
    zh: '最常听艺人',
    ko: '즐겨 듣는 아티스트',
  ),
  'Favorites not played in 90+ days': _LocalizedCopy(
    ja: '90日以上聴いていないお気に入り',
    zh: '90 天以上未播放的常听歌曲',
    ko: '90일 이상 듣지 않은 즐겨 듣던 곡',
  ),
  'Focused': _LocalizedCopy(ja: '一途', zh: '专注', ko: '집중형'),
  'Focused listener to explorer': _LocalizedCopy(
    ja: '一途リスナーから探検家まで',
    zh: '从专注听众到探索者',
    ko: '집중형 리스너부터 탐험가까지',
  ),
  'Genre': _LocalizedCopy(ja: 'ジャンル', zh: '流派', ko: '장르'),
  'Genre songs': _LocalizedCopy(ja: 'ジャンルの曲', zh: '流派歌曲', ko: '장르 곡'),
  'Highlights': _LocalizedCopy(ja: 'ハイライト', zh: '亮点', ko: '하이라이트'),
  'iOS Music library': _LocalizedCopy(
    ja: 'iOSミュージックライブラリ',
    zh: 'iOS 音乐资料库',
    ko: 'iOS 음악 라이브러리',
  ),
  'Keep 180 days': _LocalizedCopy(
    ja: '180日分を保持',
    zh: '保留 180 天',
    ko: '180일 유지',
  ),
  'Keep 30 days': _LocalizedCopy(ja: '30日分を保持', zh: '保留 30 天', ko: '30일 유지'),
  'Keep 90 days': _LocalizedCopy(ja: '90日分を保持', zh: '保留 90 天', ko: '90일 유지'),
  'Keywords': _LocalizedCopy(ja: 'キーワード', zh: '关键词', ko: '키워드'),
  'Latest': _LocalizedCopy(ja: '直近', zh: '最新', ko: '최근'),
  'Less': _LocalizedCopy(ja: '少ない', zh: '较少', ko: '적음'),
  'Library browser': _LocalizedCopy(ja: 'ライブラリ', zh: '资料库浏览', ko: '라이브러리 탐색'),
  'Library tracks': _LocalizedCopy(ja: 'ライブラリの曲', zh: '资料库曲目', ko: '라이브러리 곡'),
  'Listening curve': _LocalizedCopy(ja: '聴き方の変化', zh: '收听曲线', ko: '청취 곡선'),
  'Listening maps': _LocalizedCopy(ja: 'リスニングマップ', zh: '收听地图', ko: '청취 맵'),
  'Listening record changes': _LocalizedCopy(
    ja: '聴取記録の変化',
    zh: '收听记录变化',
    ko: '청취 기록 변화',
  ),
  'Listening record summary': _LocalizedCopy(
    ja: '聴取記録サマリー',
    zh: '收听记录摘要',
    ko: '청취 기록 요약',
  ),
  'Listening record trend': _LocalizedCopy(
    ja: '聴取記録の傾向',
    zh: '收听记录趋势',
    ko: '청취 기록 추세',
  ),
  'Listening time': _LocalizedCopy(ja: '再生時間', zh: '收听时间', ko: '청취 시간'),
  'Local': _LocalizedCopy(ja: 'ローカル', zh: '本地', ko: '로컬'),
  'Local library items': _LocalizedCopy(
    ja: 'ローカルライブラリ項目',
    zh: '本地资料库项目',
    ko: '로컬 라이브러리 항목',
  ),
  'Lock now': _LocalizedCopy(ja: '今すぐロック', zh: '立即锁定', ko: '지금 잠그기'),
  'Longest streak': _LocalizedCopy(ja: '最長連続記録', zh: '最长连续记录', ko: '최장 연속 기록'),
  'Monthly and yearly movement from daily listening records': _LocalizedCopy(
    ja: '日々の聴取記録から月間・年間の動きを表示します。',
    zh: '根据每日收听记录显示月度和年度变化。',
    ko: '일일 청취 기록으로 월간 및 연간 변화를 표시합니다.',
  ),
  'More rankings': _LocalizedCopy(ja: 'ランキングを深掘り', zh: '更多排行', ko: '더 많은 순위'),
  'Music library': _LocalizedCopy(
    ja: 'ミュージックライブラリ',
    zh: '音乐资料库',
    ko: '음악 라이브러리',
  ),
  'My SongBrief listening recap': _LocalizedCopy(
    ja: '私のSongBriefリスニングリキャップ',
    zh: '我的 SongBrief 收听回顾',
    ko: '나의 SongBrief 청취 리캡',
  ),
  'New artists': _LocalizedCopy(
    ja: '新しく聴いたアーティスト',
    zh: '新发现艺人',
    ko: '새로 들은 아티스트',
  ),
  'New plays': _LocalizedCopy(ja: '増加再生', zh: '新增播放', ko: '새 재생'),
  'New skips': _LocalizedCopy(ja: '増加スキップ', zh: '新增跳过', ko: '새 건너뛰기'),
  'Next milestone': _LocalizedCopy(ja: '次の節目', zh: '下一个里程碑', ko: '다음 마일스톤'),
  'No activity yet': _LocalizedCopy(
    ja: 'まだ活動がありません',
    zh: '暂无活动',
    ko: '아직 활동 없음',
  ),
  'No dormant favorites': _LocalizedCopy(
    ja: '該当する曲はありません',
    zh: '没有沉睡的常听歌曲',
    ko: '잠든 즐겨 듣던 곡이 없습니다',
  ),
  'No entries yet.': _LocalizedCopy(
    ja: 'まだ項目がありません。',
    zh: '暂无项目。',
    ko: '아직 항목이 없습니다.',
  ),
  'No plays yet': _LocalizedCopy(ja: 'まだ再生がありません', zh: '尚无播放', ko: '아직 재생 없음'),
  'No sharp change': _LocalizedCopy(ja: '大きな変化なし', zh: '无明显变化', ko: '큰 변화 없음'),
  'No underplayed songs': _LocalizedCopy(
    ja: '該当する曲はありません',
    zh: '没有低播放歌曲',
    ko: '적게 재생한 곡이 없습니다',
  ),
  'Not configured': _LocalizedCopy(ja: '未設定', zh: '未设置', ko: '설정되지 않음'),
  'Not in playlists': _LocalizedCopy(
    ja: 'プレイリスト未所属',
    zh: '不在播放列表中',
    ko: '플레이리스트에 없음',
  ),
  'Not requested': _LocalizedCopy(ja: '未リクエスト', zh: '未请求', ko: '요청 전'),
  'Observed': _LocalizedCopy(ja: '集計期間', zh: '观测范围', ko: '관찰 기간'),
  'Open current track': _LocalizedCopy(
    ja: '再生中の曲を開く',
    zh: '打开当前曲目',
    ko: '현재 곡 열기',
  ),
  'Open song in Apple Music': _LocalizedCopy(
    ja: '曲をApple Musicで開く',
    zh: '在 Apple Music 中打开歌曲',
    ko: 'Apple Music에서 곡 열기',
  ),
  'Pause this track': _LocalizedCopy(
    ja: 'この曲を一時停止',
    zh: '暂停此曲目',
    ko: '이 곡 일시 정지',
  ),
  'Period movers': _LocalizedCopy(ja: '期間別ランキング', zh: '期间变化', ko: '기간별 변동'),
  'Play this track': _LocalizedCopy(ja: 'この曲を再生', zh: '播放此曲目', ko: '이 곡 재생'),
  'Played-track coverage by album': _LocalizedCopy(
    ja: 'アルバム内の再生済み曲の割合',
    zh: '按专辑统计已播放曲目比例',
    ko: '앨범별 재생한 곡 비율',
  ),
  'Premium purchase is not available yet.': _LocalizedCopy(
    ja: 'プレミアム購入は現在準備中です。',
    zh: '高级版购买功能尚未开放。',
    ko: '프리미엄 구매는 아직 사용할 수 없습니다.',
  ),
  'Rank changes': _LocalizedCopy(ja: '順位変動', zh: '排名变化', ko: '순위 변동'),
  'Ranked by play count': _LocalizedCopy(
    ja: '再生回数順',
    zh: '按播放次数排序',
    ko: '재생 횟수순',
  ),
  'Recent 30 days': _LocalizedCopy(ja: '直近30日', zh: '最近 30 天', ko: '최근 30일'),
  'Recent 30d': _LocalizedCopy(ja: '直近30日', zh: '最近 30 天', ko: '최근 30일'),
  'Recap highlights': _LocalizedCopy(ja: 'リキャップ', zh: '回顾亮点', ko: '리캡 하이라이트'),
  'Rediscovery': _LocalizedCopy(ja: '再発見', zh: '重新发现', ko: '재발견'),
  'Restricted': _LocalizedCopy(ja: '制限中', zh: '受限', ko: '제한됨'),
  'Rising now': _LocalizedCopy(ja: '急上昇', zh: '正在上升', ko: '급상승'),
  'Sample library': _LocalizedCopy(
    ja: 'サンプルライブラリ',
    zh: '示例资料库',
    ko: '샘플 라이브러리',
  ),
  'Aggregated across each artist': _LocalizedCopy(
    ja: 'アーティストごとの合計',
    zh: '按艺人汇总',
    ko: '아티스트별 합계',
  ),
  'Aggregated across each album': _LocalizedCopy(
    ja: 'アルバムごとの合計',
    zh: '按专辑汇总',
    ko: '앨범별 합계',
  ),
  'Sorted by last played date': _LocalizedCopy(
    ja: '最後に再生した日時順',
    zh: '按最后播放日期排序',
    ko: '마지막 재생일순',
  ),
  'Search in Apple Music': _LocalizedCopy(
    ja: 'Apple Musicで検索',
    zh: '在 Apple Music 中搜索',
    ko: 'Apple Music에서 검색',
  ),
  'Search the web': _LocalizedCopy(ja: 'Webで検索', zh: '网页搜索', ko: '웹에서 검색'),
  'Open web search?': _LocalizedCopy(
    ja: 'Web検索を開きますか？',
    zh: '打开网页搜索？',
    ko: '웹 검색을 열까요?',
  ),
  'Show details': _LocalizedCopy(ja: '詳細を見る', zh: '查看详情', ko: '상세 보기'),
  'See all': _LocalizedCopy(ja: 'すべて見る', zh: '查看全部', ko: '모두 보기'),
  'Show position in ranking': _LocalizedCopy(
    ja: 'ランキング内の位置を見る',
    zh: '查看在排行中的位置',
    ko: '순위 내 위치 보기',
  ),
  'Sleeping favorites': _LocalizedCopy(
    ja: '眠っているお気に入り',
    zh: '沉睡的常听歌曲',
    ko: '잠든 즐겨 듣던 곡',
  ),
  'Smart lists': _LocalizedCopy(ja: 'スマートリスト', zh: '智能列表', ko: '스마트 리스트'),
  'Source': _LocalizedCopy(ja: 'ソース', zh: '来源', ko: '소스'),
  'Store product': _LocalizedCopy(ja: 'ストア商品', zh: '商店商品', ko: '스토어 상품'),
  'Taste and collection': _LocalizedCopy(
    ja: '好みとコレクション',
    zh: '品味与收藏',
    ko: '취향과 컬렉션',
  ),
  'This month': _LocalizedCopy(ja: '今月', zh: '本月', ko: '이번 달'),
  'This chart appears after records from at least two different days are available.':
      _LocalizedCopy(
        ja: '別の日の記録がもう1回分たまると、このグラフを表示できます。',
        zh: '至少有两个不同日期的记录后会显示此图表。',
        ko: '서로 다른 날짜의 기록이 2일 이상 있으면 이 차트를 표시합니다.',
      ),
  'This week': _LocalizedCopy(ja: '今週', zh: '本周', ko: '이번 주'),
  'This year': _LocalizedCopy(ja: '今年', zh: '今年', ko: '올해'),
  'Today': _LocalizedCopy(ja: '今日', zh: '今天', ko: '오늘'),
  '#1 Song': _LocalizedCopy(ja: '#1 曲', zh: '#1 歌曲', ko: '#1 곡'),
  '7 days': _LocalizedCopy(ja: '7日間', zh: '7天', ko: '7일'),
  '4 weeks': _LocalizedCopy(ja: '4週間', zh: '4周', ko: '4주'),
  '1 year': _LocalizedCopy(ja: '1年間', zh: '1年', ko: '1년'),
  '7 days uses daily buckets, 4 weeks uses weekly buckets, and 1 year uses monthly buckets.':
      _LocalizedCopy(
        ja: '7日間は日別、4週間は週別、1年間は月別のバケットで集計します。',
        zh: '7天按天汇总，4周按周汇总，1年按月汇总。',
        ko: '7일은 일별, 4주는 주별, 1년은 월별 단위로 집계합니다.',
      ),
  'No local lyrics were found for this song.': _LocalizedCopy(
    ja: 'この曲のローカル歌詞は見つかりませんでした。',
    zh: '未找到此歌曲的本地歌词。',
    ko: '이 곡의 로컬 가사를 찾을 수 없습니다.',
  ),
  'Open SongBrief on another day to build a listening trend.': _LocalizedCopy(
    ja: '別の日にもSongBriefを開くと、日々の変化を表示できます。',
    zh: '在其他日期打开 SongBrief 后即可生成收听趋势。',
    ko: '다른 날에도 SongBrief를 열면 청취 추세를 만들 수 있습니다.',
  ),
  'Play-count changes for this song from daily listening records.':
      _LocalizedCopy(
        ja: '日々の聴取記録から、この曲の再生回数の増分を表示します。',
        zh: '根据每日收听记录显示这首歌播放次数的变化。',
        ko: '일별 청취 기록을 바탕으로 이 곡의 재생 횟수 변화를 표시합니다.',
      ),
  'Light-split accents for a data-first surface.': _LocalizedCopy(
    ja: '光の分解をイメージした、データ重視のテーマです。',
    zh: '以光的分解为灵感、偏重数据呈现的主题。',
    ko: '빛의 분해를 떠올리게 하는 데이터 중심 테마입니다.',
  ),
  'Blue and mint accents with a crisp, calm look.': _LocalizedCopy(
    ja: 'ブルーとミントを基調にした、すっきりしたテーマです。',
    zh: '以蓝色和薄荷色为主的清爽主题。',
    ko: '블루와 민트를 바탕으로 한 선명하고 차분한 테마입니다.',
  ),
  'Pink and amber music-focused theme.': _LocalizedCopy(
    ja: 'ピンクとアンバーを基調にした音楽向けテーマです。',
    zh: '以粉色和琥珀色为主的音乐感主题。',
    ko: '핑크와 앰버를 강조한 음악 중심 테마입니다.',
  ),
  'High-contrast monochrome theme.': _LocalizedCopy(
    ja: '白黒を基調にした高コントラストテーマです。',
    zh: '以黑白为主的高对比度主题。',
    ko: '흑백을 바탕으로 한 고대비 테마입니다.',
  ),
  'Magenta, ice blue, and amber accents with a polar-night feel.':
      _LocalizedCopy(
        ja: 'マゼンタ、アイスブルー、アンバーで極夜の光をイメージしたテーマです。',
        zh: '以洋红、冰蓝和琥珀色营造极夜光感的主题。',
        ko: '마젠타, 아이스 블루, 앰버로 극야의 빛을 표현한 테마입니다.',
      ),
  'Natural green with cyan and coral accents.': _LocalizedCopy(
    ja: '自然なグリーンにシアンとコーラルを添えたテーマです。',
    zh: '自然绿色搭配青色和珊瑚色的主题。',
    ko: '자연스러운 그린에 시안과 코랄을 더한 테마입니다.',
  ),
  'Blue, teal, and rose accents for crisp contrast.': _LocalizedCopy(
    ja: 'ブルー、ティール、ローズで明快に見せるテーマです。',
    zh: '以蓝色、蓝绿色和玫瑰色形成清晰对比的主题。',
    ko: '블루, 티일, 로즈로 또렷한 대비를 주는 테마입니다.',
  ),
  'Violet, teal, and amber accents with a softer tone.': _LocalizedCopy(
    ja: 'バイオレット、ティール、アンバーを柔らかく組み合わせたテーマです。',
    zh: '柔和组合紫罗兰、蓝绿色和琥珀色的主题。',
    ko: '바이올렛, 티일, 앰버를 부드럽게 조합한 테마입니다.',
  ),
  'Uses a dark appearance.': _LocalizedCopy(
    ja: 'ダーク表示を使用します。',
    zh: '使用深色外观。',
    ko: '다크 화면을 사용합니다.',
  ),
  'Uses a light appearance.': _LocalizedCopy(
    ja: 'ライト表示を使用します。',
    zh: '使用浅色外观。',
    ko: '라이트 화면을 사용합니다.',
  ),
  'Follows the device appearance setting.': _LocalizedCopy(
    ja: '端末の外観設定に合わせます。',
    zh: '跟随设备外观设置。',
    ko: '기기의 화면 설정을 따릅니다.',
  ),
  'Allow Music access to read play counts and skip counts.': _LocalizedCopy(
    ja: '再生回数とスキップ回数を読むためにミュージックアクセスを許可してください。',
    zh: '请允许访问音乐，以读取播放次数和跳过次数。',
    ko: '재생 횟수와 스킵 횟수를 읽기 위해 음악 접근을 허용하세요.',
  ),
  'Demo data shown until iOS Music access is available.': _LocalizedCopy(
    ja: 'iOSのミュージックアクセスが利用可能になるまでデモデータを表示しています。',
    zh: '在 iOS 音乐访问可用前显示演示数据。',
    ko: 'iOS 음악 접근을 사용할 수 있을 때까지 데모 데이터를 표시합니다.',
  ),
  'The main ranking stays above. These views add period, momentum, rediscovery, and movement context.':
      _LocalizedCopy(
        ja: 'メインランキングは上に残し、期間、勢い、再発見、順位変動の視点を追加します。',
        zh: '主排行榜保留在上方，这里补充期间、趋势、重新发现和排名变化。',
        ko: '기본 순위는 위에 유지하고 기간, 상승세, 재발견, 순위 변동 관점을 더합니다.',
      ),
  'Period, rising, and rank-change rankings appear after records from two different days are available.':
      _LocalizedCopy(
        ja: '期間、急上昇、順位変動のランキングは、別の日の記録がそろうと表示されます。',
        zh: '期间、上升和排名变化排行榜会在有两个不同日期的记录后显示。',
        ko: '기간, 급상승, 순위 변동 순위는 서로 다른 날짜의 기록이 있으면 표시됩니다.',
      ),
  'Tracks ranked by play-count increases within the selected record range.':
      _LocalizedCopy(
        ja: '選択した記録期間で再生回数が増えた曲を順位付けします。',
        zh: '按所选记录范围内播放次数的增加量排序。',
        ko: '선택한 기록 기간 동안 재생 횟수가 증가한 곡을 순위로 표시합니다.',
      ),
  'No play-count increases were found in this range yet.': _LocalizedCopy(
    ja: 'この範囲ではまだ再生回数の増加が見つかりません。',
    zh: '此范围内尚未发现播放次数增加。',
    ko: '이 범위에서는 아직 재생 횟수 증가가 없습니다.',
  ),
  'period gain': _LocalizedCopy(ja: '期間増分', zh: '期间增加', ko: '기간 증가'),
  'No recent increases were found yet.': _LocalizedCopy(
    ja: '直近の増加はまだ見つかりません。',
    zh: '尚未发现最近的增加。',
    ko: '최근 증가가 아직 없습니다.',
  ),
  'since previous record': _LocalizedCopy(
    ja: '前回の記録から',
    zh: '相较上一条记录',
    ko: '이전 기록 이후',
  ),
  'High-play favorites that have been quiet for 90 days or more.':
      _LocalizedCopy(
        ja: 'よく聴いていたのに90日以上再生されていない曲です。',
        zh: '曾经常听但 90 天以上未播放的歌曲。',
        ko: '자주 들었지만 90일 이상 재생되지 않은 곡입니다.',
      ),
  'No rediscovery candidates right now.': _LocalizedCopy(
    ja: '今は再発見候補がありません。',
    zh: '目前没有重新发现候选。',
    ko: '지금은 재발견 후보가 없습니다.',
  ),
  'not played': _LocalizedCopy(ja: '未再生', zh: '未播放', ko: '재생 안 함'),
  'Largest ranking movements compared with the previous record.':
      _LocalizedCopy(
        ja: '前回の記録と比べて順位が大きく動いた曲です。',
        zh: '与上一条记录相比排名变化最大的歌曲。',
        ko: '이전 기록과 비교해 순위가 크게 움직인 곡입니다.',
      ),
  'No ranking movement was found yet.': _LocalizedCopy(
    ja: '順位変動はまだ見つかりません。',
    zh: '尚未发现排名变化。',
    ko: '순위 변동이 아직 없습니다.',
  ),
  'rank movement': _LocalizedCopy(ja: '順位変動', zh: '排名变化', ko: '순위 변동'),
  'Search songs, artists, albums, genres, or playlists': _LocalizedCopy(
    ja: '曲、アーティスト、アルバム、ジャンル、プレイリストを検索',
    zh: '搜索歌曲、艺人、专辑、流派或播放列表',
    ko: '곡, 아티스트, 앨범, 장르, 플레이리스트 검색',
  ),
  'No songs matched the current search.': _LocalizedCopy(
    ja: '現在の検索に一致する曲はありません。',
    zh: '当前搜索没有匹配的歌曲。',
    ko: '현재 검색과 일치하는 곡이 없습니다.',
  ),
  'Grouped library content with drill-down details': _LocalizedCopy(
    ja: 'ライブラリを分類し、詳細へ掘り下げられます。',
    zh: '按类别整理资料库，并可继续查看详情。',
    ko: '라이브러리를 그룹화하고 세부 정보로 들어갈 수 있습니다.',
  ),
  'CSV is suited for spreadsheets. JSON includes listening record summaries for backup or analysis.':
      _LocalizedCopy(
        ja: 'CSVは表計算向け、JSONは記録の概要を含む分析・バックアップ向けです。',
        zh: 'CSV 适合表格处理，JSON 包含收听记录摘要，适合备份或分析。',
        ko: 'CSV는 스프레드시트용, JSON은 기록 요약을 포함해 백업이나 분석에 적합합니다.',
      ),
  'Matching songs are hidden from SongBrief rankings, library, exports, and future records. Your Apple Music library is not changed.':
      _LocalizedCopy(
        ja: '一致する曲はSongBriefのランキング、ライブラリ、エクスポート、今後の記録から非表示になります。Apple Musicライブラリは変更されません。',
        zh: '匹配的歌曲会从 SongBrief 的排行榜、资料库、导出和今后的记录中隐藏。Apple Music 资料库不会被修改。',
        ko: '일치하는 곡은 SongBrief의 순위, 라이브러리, 내보내기, 향후 기록에서 숨겨집니다. Apple Music 라이브러리는 변경되지 않습니다.',
      ),
  'Edit exclusion rules without changing your Apple Music library.':
      _LocalizedCopy(
        ja: 'Apple Musicライブラリを変更せずに非表示ルールを編集します。',
        zh: '不修改 Apple Music 资料库即可编辑隐藏规则。',
        ko: 'Apple Music 라이브러리를 변경하지 않고 제외 규칙을 편집합니다.',
      ),
  'Hide songs that belong to selected playlists.': _LocalizedCopy(
    ja: '選択したプレイリストに含まれる曲を非表示にします。',
    zh: '隐藏属于所选播放列表的歌曲。',
    ko: '선택한 플레이리스트에 포함된 곡을 숨깁니다.',
  ),
  'No hidden playlists': _LocalizedCopy(
    ja: '非表示プレイリストなし',
    zh: '没有隐藏的播放列表',
    ko: '숨긴 플레이리스트 없음',
  ),
  'Add playlist': _LocalizedCopy(
    ja: 'プレイリストを追加',
    zh: '添加播放列表',
    ko: '플레이리스트 추가',
  ),
  'Hide songs with selected genre names.': _LocalizedCopy(
    ja: '選択したジャンル名の曲を非表示にします。',
    zh: '隐藏所选流派名称的歌曲。',
    ko: '선택한 장르 이름의 곡을 숨깁니다.',
  ),
  'No hidden genres': _LocalizedCopy(
    ja: '非表示ジャンルなし',
    zh: '没有隐藏的流派',
    ko: '숨긴 장르 없음',
  ),
  'Add genre': _LocalizedCopy(ja: 'ジャンルを追加', zh: '添加流派', ko: '장르 추가'),
  'Hide songs whose title, artist, album, genre, or playlist contains a keyword.':
      _LocalizedCopy(
        ja: 'タイトル、アーティスト、アルバム、ジャンル、プレイリストにキーワードを含む曲を非表示にします。',
        zh: '隐藏标题、艺人、专辑、流派或播放列表包含关键词的歌曲。',
        ko: '제목, 아티스트, 앨범, 장르, 플레이리스트에 키워드가 포함된 곡을 숨깁니다.',
      ),
  'No hidden keywords': _LocalizedCopy(
    ja: '非表示キーワードなし',
    zh: '没有隐藏关键词',
    ko: '숨긴 키워드 없음',
  ),
  'Add keyword': _LocalizedCopy(ja: 'キーワードを追加', zh: '添加关键词', ko: '키워드 추가'),
  'Suggestions': _LocalizedCopy(ja: '候補', zh: '建议', ko: '추천'),
  'Songs in matching playlists will be hidden.': _LocalizedCopy(
    ja: '一致するプレイリスト内の曲が非表示になります。',
    zh: '匹配播放列表中的歌曲将被隐藏。',
    ko: '일치하는 플레이리스트의 곡이 숨겨집니다.',
  ),
  'Songs with a matching genre will be hidden.': _LocalizedCopy(
    ja: '一致するジャンルの曲が非表示になります。',
    zh: '匹配流派的歌曲将被隐藏。',
    ko: '일치하는 장르의 곡이 숨겨집니다.',
  ),
  'Title, artist, album, genre, and playlist names are checked.':
      _LocalizedCopy(
        ja: 'タイトル、アーティスト、アルバム、ジャンル、プレイリスト名を確認します。',
        zh: '会检查标题、艺人、专辑、流派和播放列表名称。',
        ko: '제목, 아티스트, 앨범, 장르, 플레이리스트 이름을 확인합니다.',
      ),
  'Deleting listening records requires confirmation. App settings and purchase status are kept.':
      _LocalizedCopy(
        ja: '聴取記録の削除には確認が必要です。アプリ設定と購入状態は保持されます。',
        zh: '删除收听记录需要确认。应用设置和购买状态会保留。',
        ko: '청취 기록 삭제에는 확인이 필요합니다. 앱 설정과 구매 상태는 유지됩니다.',
      ),
  'Save daily listening records': _LocalizedCopy(
    ja: '日次の聴取記録を保存',
    zh: '保存每日收听记录',
    ko: '일별 청취 기록 저장',
  ),
  'Record-based trends and recaps are visible.': _LocalizedCopy(
    ja: '記録を使った傾向とリキャップを表示します。',
    zh: '显示基于记录的趋势和回顾。',
    ko: '기록 기반 추세와 리캡을 표시합니다.',
  ),
  'Record-based trends and recaps are hidden.': _LocalizedCopy(
    ja: '記録を使った傾向とリキャップは非表示です。',
    zh: '基于记录的趋势和回顾已隐藏。',
    ko: '기록 기반 추세와 리캡은 숨겨집니다.',
  ),
  'I understand this clears temporary caches.': _LocalizedCopy(
    ja: '一時キャッシュが削除されることを理解しました。',
    zh: '我了解这会清除临时缓存。',
    ko: '임시 캐시가 삭제되는 것을 이해했습니다.',
  ),
  'Temporary caches were cleared.': _LocalizedCopy(
    ja: '一時キャッシュを削除しました。',
    zh: '已清除临时缓存。',
    ko: '임시 캐시를 삭제했습니다.',
  ),
  'No matching listening records were deleted.': _LocalizedCopy(
    ja: '対象の聴取記録はありませんでした。',
    zh: '没有删除匹配的收听记录。',
    ko: '삭제할 청취 기록이 없었습니다.',
  ),
  'Artwork caches and all listening records will be cleared. App settings and purchase status are kept.':
      _LocalizedCopy(
        ja: 'アートワークキャッシュとすべての聴取記録を削除します。アプリ設定と購入状態は保持されます。',
        zh: '将清除封面缓存和所有收听记录。应用设置和购买状态会保留。',
        ko: '아트워크 캐시와 모든 청취 기록을 삭제합니다. 앱 설정과 구매 상태는 유지됩니다.',
      ),
  'I understand this deletes listening records.': _LocalizedCopy(
    ja: '聴取記録が削除されることを理解しました。',
    zh: '我了解这会删除收听记录。',
    ko: '청취 기록이 삭제되는 것을 이해했습니다.',
  ),
  'Unavailable': _LocalizedCopy(ja: '利用不可', zh: '不可用', ko: '사용 불가'),
  'Require device authentication when opening SongBrief.': _LocalizedCopy(
    ja: 'SongBriefを開くときに端末認証を要求します。',
    zh: '打开 SongBrief 时要求设备认证。',
    ko: 'SongBrief를 열 때 기기 인증을 요구합니다.',
  ),
  'Enable SongBrief app lock.': _LocalizedCopy(
    ja: 'SongBriefのアプリロックを有効にします。',
    zh: '启用 SongBrief 应用锁。',
    ko: 'SongBrief 앱 잠금을 활성화합니다.',
  ),
  'Authentication was not completed.': _LocalizedCopy(
    ja: '認証が完了しませんでした。',
    zh: '认证未完成。',
    ko: '인증이 완료되지 않았습니다.',
  ),
  'Remove ads': _LocalizedCopy(ja: '広告を非表示', zh: '移除广告', ko: '광고 제거'),
  'Product ID': _LocalizedCopy(ja: '商品ID', zh: '商品 ID', ko: '상품 ID'),
  'Reload product': _LocalizedCopy(
    ja: '商品を再取得',
    zh: '重新加载商品',
    ko: '상품 다시 불러오기',
  ),
  'Restore': _LocalizedCopy(ja: '復元', zh: '恢复', ko: '복원'),
  'Premium purchase is not available yet. Once enabled, you can buy ad removal here.':
      _LocalizedCopy(
        ja: 'プレミアム購入はまだ利用できません。有効になると、ここで広告非表示を購入できます。',
        zh: '高级版购买尚不可用。启用后可在此购买广告移除。',
        ko: '프리미엄 구매는 아직 사용할 수 없습니다. 활성화되면 여기에서 광고 제거를 구매할 수 있습니다.',
      ),
  'AdMob test': _LocalizedCopy(ja: 'AdMobテスト', zh: 'AdMob 测试', ko: 'AdMob 테스트'),
  'AdMob live': _LocalizedCopy(ja: 'AdMob本番', zh: 'AdMob 正式', ko: 'AdMob 실서비스'),
  'Store unavailable': _LocalizedCopy(
    ja: 'ストア利用不可',
    zh: '商店不可用',
    ko: '스토어 사용 불가',
  ),
  'Songs played in the last 30 days': _LocalizedCopy(
    ja: '直近30日に再生した曲',
    zh: '最近 30 天播放过的歌曲',
    ko: '최근 30일 동안 재생한 곡',
  ),
  'Songs with zero plays': _LocalizedCopy(
    ja: '再生回数が0の曲',
    zh: '播放次数为 0 的歌曲',
    ko: '재생 횟수가 0인 곡',
  ),
  'per track': _LocalizedCopy(ja: '曲あたり', zh: '每首歌', ko: '곡당'),
  'Above average plays': _LocalizedCopy(
    ja: '平均以上の再生',
    zh: '高于平均播放',
    ko: '평균 이상 재생',
  ),
  'Songs at or above the library average': _LocalizedCopy(
    ja: 'ライブラリ平均以上の曲',
    zh: '达到或高于资料库平均值的歌曲',
    ko: '라이브러리 평균 이상인 곡',
  ),
  'Songs marked as cloud library items': _LocalizedCopy(
    ja: 'クラウドライブラリ項目の曲',
    zh: '标记为云资料库项目的歌曲',
    ko: '클라우드 라이브러리 항목으로 표시된 곡',
  ),
  'Different views of the current library': _LocalizedCopy(
    ja: '現在のライブラリを別の視点で表示します。',
    zh: '从不同角度查看当前资料库。',
    ko: '현재 라이브러리를 다른 관점으로 봅니다.',
  ),
  'Where plays and tracks are concentrated': _LocalizedCopy(
    ja: '再生と曲がどこに集中しているか',
    zh: '播放和歌曲集中在哪里',
    ko: '재생과 곡이 어디에 집중되어 있는지',
  ),
  'Top artists': _LocalizedCopy(ja: 'トップアーティスト', zh: '热门艺人', ko: '상위 아티스트'),
  'No artist play data yet.': _LocalizedCopy(
    ja: 'アーティスト別の再生データはまだありません。',
    zh: '尚无艺人播放数据。',
    ko: '아티스트별 재생 데이터가 아직 없습니다.',
  ),
  'No genre metadata was returned.': _LocalizedCopy(
    ja: 'ジャンルのメタデータが取得されていません。',
    zh: '未返回流派元数据。',
    ko: '장르 메타데이터가 없습니다.',
  ),
  'No source data yet.': _LocalizedCopy(
    ja: '元データがまだありません。',
    zh: '尚无来源数据。',
    ko: '원본 데이터가 아직 없습니다.',
  ),
  'Auto-generated views from play counts and metadata': _LocalizedCopy(
    ja: '再生回数とメタデータから自動生成したリスト',
    zh: '根据播放次数和元数据自动生成的视图',
    ko: '재생 횟수와 메타데이터로 자동 생성한 보기',
  ),
  'Inspect playback patterns by year, day, and genre': _LocalizedCopy(
    ja: '年、日、ジャンル別に再生パターンを確認します。',
    zh: '按年份、日期和流派查看播放模式。',
    ko: '연도, 날짜, 장르별 재생 패턴을 확인합니다.',
  ),
  'Inspect playback patterns by year and genre': _LocalizedCopy(
    ja: '年とジャンル別に再生パターンを確認します。',
    zh: '按年份和流派查看播放模式。',
    ko: '연도와 장르별 재생 패턴을 확인합니다.',
  ),
  'Release-year concentration and daily play activity': _LocalizedCopy(
    ja: '発売年の偏りと日別の再生活動',
    zh: '发行年份集中度和每日播放活动',
    ko: '발매 연도 집중도와 일별 재생 활동',
  ),
  'Release-year concentration from the current library': _LocalizedCopy(
    ja: '現在のライブラリにおける発売年の偏り',
    zh: '当前资料库的发行年份集中度',
    ko: '현재 라이브러리의 발매 연도 집중도',
  ),
  'Release year x plays': _LocalizedCopy(
    ja: '発売年 × 再生回数',
    zh: '发行年份 × 播放次数',
    ko: '발매 연도 × 재생 횟수',
  ),
  'Release year x songs': _LocalizedCopy(
    ja: '発売年 × 曲数',
    zh: '发行年份 × 歌曲数',
    ko: '발매 연도 × 곡 수',
  ),
  'Release dates are not available yet.': _LocalizedCopy(
    ja: '発売日情報はまだ利用できません。',
    zh: '发行日期尚不可用。',
    ko: '발매일 정보를 아직 사용할 수 없습니다.',
  ),
  'Songs without release dates are excluded.': _LocalizedCopy(
    ja: '発売日がない曲は除外されます。',
    zh: '没有发行日期的歌曲会被排除。',
    ko: '발매일이 없는 곡은 제외됩니다.',
  ),
  'Release-year songs': _LocalizedCopy(
    ja: '発売年の曲',
    zh: '发行年份歌曲',
    ko: '발매 연도 곡',
  ),
  'Years': _LocalizedCopy(ja: '年', zh: '年份', ko: '연도'),
  'Top year': _LocalizedCopy(ja: '最多の年', zh: '最高年份', ko: '상위 연도'),
  'Avg / song': _LocalizedCopy(ja: '平均 / 曲', zh: '平均 / 歌曲', ko: '평균 / 곡'),
  'Tap a year point': _LocalizedCopy(ja: '年の点をタップ', zh: '点击年份点', ko: '연도 점을 탭'),
  'Show plays and song count': _LocalizedCopy(
    ja: '再生回数と曲数を表示',
    zh: '显示播放次数和歌曲数',
    ko: '재생 횟수와 곡 수 표시',
  ),
  'Recent-track estimate': _LocalizedCopy(
    ja: '最近再生からの推定',
    zh: '根据最近播放估算',
    ko: '최근 재생 기반 추정',
  ),
  'Selected day': _LocalizedCopy(ja: '選択日', zh: '所选日期', ko: '선택한 날짜'),
  'Song detail is unavailable for this day.': _LocalizedCopy(
    ja: 'この日の曲詳細は利用できません。',
    zh: '此日期的歌曲详情不可用。',
    ko: '이 날짜의 곡 상세 정보를 사용할 수 없습니다.',
  ),
  'Peak day': _LocalizedCopy(ja: 'ピーク日', zh: '峰值日', ko: '피크일'),
  'Consecutive active days ending today': _LocalizedCopy(
    ja: '今日までの連続アクティブ日数',
    zh: '截至今天的连续活跃天数',
    ko: '오늘까지의 연속 활동 일수',
  ),
  'Best run in this range': _LocalizedCopy(
    ja: 'この範囲の最長連続',
    zh: '此范围内最长连续',
    ko: '이 범위의 최장 연속',
  ),
  'Quiet days': _LocalizedCopy(ja: '静かな日', zh: '安静日', ko: '조용한 날'),
  'Days without detected plays': _LocalizedCopy(
    ja: '再生が検出されなかった日',
    zh: '未检测到播放的日期',
    ko: '재생이 감지되지 않은 날',
  ),
  'Genre stack by release year': _LocalizedCopy(
    ja: '発売年別ジャンル構成',
    zh: '按发行年份的流派构成',
    ko: '발매 연도별 장르 구성',
  ),
  'Play counts split by the strongest genres': _LocalizedCopy(
    ja: '主要ジャンル別の再生回数',
    zh: '按主要流派拆分播放次数',
    ko: '주요 장르별 재생 횟수',
  ),
  'Genre and release date metadata are required.': _LocalizedCopy(
    ja: 'ジャンルと発売日のメタデータが必要です。',
    zh: '需要流派和发行日期元数据。',
    ko: '장르와 발매일 메타데이터가 필요합니다.',
  ),
  'Era mix': _LocalizedCopy(ja: '年代ミックス', zh: '年代组合', ko: '시대 구성'),
  'Which release decades dominate the library': _LocalizedCopy(
    ja: 'どの発売年代が多いか',
    zh: '哪些发行年代占主导',
    ko: '어떤 발매 연대가 많은지',
  ),
  'Release decade songs': _LocalizedCopy(
    ja: '発売年代の曲',
    zh: '发行年代歌曲',
    ko: '발매 연대 곡',
  ),
  'Rediscovery, listening range, and album completion': _LocalizedCopy(
    ja: '再発見、聴取の幅、アルバム制覇率',
    zh: '重新发现、收听范围和专辑完成度',
    ko: '재발견, 청취 범위, 앨범 완주율',
  ),
  'Save PNG': _LocalizedCopy(ja: 'PNGを保存', zh: '保存 PNG', ko: 'PNG 저장'),
  'Share': _LocalizedCopy(ja: '共有', zh: '分享', ko: '공유'),
  'Image save was cancelled.': _LocalizedCopy(
    ja: '画像保存をキャンセルしました。',
    zh: '已取消保存图片。',
    ko: '이미지 저장을 취소했습니다.',
  ),
  'Recap image saved.': _LocalizedCopy(
    ja: 'リキャップ画像を保存しました。',
    zh: '已保存回顾图片。',
    ko: '리캡 이미지를 저장했습니다.',
  ),
  'SongBrief Recap': _LocalizedCopy(
    ja: 'SongBriefリキャップ',
    zh: 'SongBrief 回顾',
    ko: 'SongBrief 리캡',
  ),
  'Sharing is not available on this device.': _LocalizedCopy(
    ja: 'この端末では共有を利用できません。',
    zh: '此设备无法使用分享。',
    ko: '이 기기에서는 공유를 사용할 수 없습니다.',
  ),
  'None yet': _LocalizedCopy(ja: 'まだありません', zh: '暂无', ko: '아직 없음'),
  'Recaps appear after daily listening records accumulate.': _LocalizedCopy(
    ja: '日々の聴取記録がたまるとリキャップを表示します。',
    zh: '每日收听记录积累后会显示回顾。',
    ko: '일별 청취 기록이 쌓이면 리캡이 표시됩니다.',
  ),
  'new plays': _LocalizedCopy(ja: '新規再生', zh: '新增播放', ko: '새 재생'),
  'No old favorites need rediscovery.': _LocalizedCopy(
    ja: '再発見が必要な昔のお気に入りはありません。',
    zh: '没有需要重新发现的旧收藏。',
    ko: '재발견할 오래된 즐겨 듣던 곡이 없습니다.',
  ),
  'Album groups appear after the library is loaded.': _LocalizedCopy(
    ja: 'ライブラリを読み込むとアルバムグループを表示します。',
    zh: '资料库加载后会显示专辑分组。',
    ko: '라이브러리를 불러오면 앨범 그룹이 표시됩니다.',
  ),
  'Burnout detection appears after several listening records.': _LocalizedCopy(
    ja: '複数の聴取記録がたまると聴き飽き検知を表示します。',
    zh: '积累多条收听记录后会显示听腻检测。',
    ko: '여러 청취 기록이 쌓이면 번아웃 감지를 표시합니다.',
  ),
  'No sharp drop-off detected in the saved period.': _LocalizedCopy(
    ja: '保存済み期間では急な減衰は検出されませんでした。',
    zh: '保存期间未检测到明显下降。',
    ko: '저장된 기간에는 급격한 감소가 감지되지 않았습니다.',
  ),
  'soon': _LocalizedCopy(ja: 'まもなく', zh: '很快', ko: '곧'),
  'Skip rate': _LocalizedCopy(ja: 'スキップ率', zh: '跳过率', ko: '스킵률'),
  'The first listening record will be saved after the next library update.':
      _LocalizedCopy(
        ja: '次のライブラリ更新後に最初の聴取記録を保存します。',
        zh: '下次资料库更新后会保存第一条收听记录。',
        ko: '다음 라이브러리 업데이트 후 첫 청취 기록을 저장합니다.',
      ),
  'Window': _LocalizedCopy(ja: '期間', zh: '范围', ko: '기간'),
  'Top gains since previous record': _LocalizedCopy(
    ja: '前回の記録からの増加トップ',
    zh: '相较上一条记录的增长排行',
    ko: '이전 기록 이후 증가 상위',
  ),
  'No play-count changes were found between the last two records.':
      _LocalizedCopy(
        ja: '直近2回の記録間で再生回数の変化は見つかりませんでした。',
        zh: '最近两条记录之间没有发现播放次数变化。',
        ko: '최근 두 기록 사이에 재생 횟수 변화가 없습니다.',
      ),
  'Trend bars appear after records from two or more days are available.':
      _LocalizedCopy(
        ja: '2日以上の記録がそろうと傾向バーを表示します。',
        zh: '有两天以上的记录后会显示趋势条。',
        ko: '2일 이상의 기록이 있으면 추세 막대를 표시합니다.',
      ),
  'All artist groups in the current library': _LocalizedCopy(
    ja: '現在のライブラリ内のすべてのアーティストグループ',
    zh: '当前资料库中的所有艺人分组',
    ko: '현재 라이브러리의 모든 아티스트 그룹',
  ),
  'All album groups in the current library': _LocalizedCopy(
    ja: '現在のライブラリ内のすべてのアルバムグループ',
    zh: '当前资料库中的所有专辑分组',
    ko: '현재 라이브러리의 모든 앨범 그룹',
  ),
  'Songs sorted by total listening time': _LocalizedCopy(
    ja: '総再生時間順の曲',
    zh: '按总收听时间排序的歌曲',
    ko: '총 청취 시간순 곡',
  ),
  'No playlist membership was returned for this song.': _LocalizedCopy(
    ja: 'この曲が含まれるプレイリスト情報は取得されませんでした。',
    zh: '未返回此歌曲所属播放列表信息。',
    ko: '이 곡이 포함된 플레이리스트 정보를 가져오지 못했습니다.',
  ),
  'Playlist songs': _LocalizedCopy(
    ja: 'プレイリスト内の曲',
    zh: '播放列表歌曲',
    ko: '플레이리스트 곡',
  ),
  'No Music library songs were returned by iOS.': _LocalizedCopy(
    ja: 'iOSからミュージックライブラリの曲が返されませんでした。',
    zh: 'iOS 未返回音乐资料库歌曲。',
    ko: 'iOS에서 음악 라이브러리 곡을 반환하지 않았습니다.',
  ),
  'Playlist': _LocalizedCopy(ja: 'プレイリスト', zh: '播放列表', ko: '플레이리스트'),
  'Often played, not heard in 30+ days': _LocalizedCopy(
    ja: 'よく聴いたが30日以上再生なし',
    zh: '常听但 30 天以上未播放',
    ko: '자주 들었지만 30일 이상 재생 없음',
  ),
  'High skip rate': _LocalizedCopy(ja: '高スキップ率', zh: '高跳过率', ko: '높은 스킵률'),
  'Songs with repeated skips versus plays': _LocalizedCopy(
    ja: '再生に対してスキップが多い曲',
    zh: '相对播放次数跳过较多的歌曲',
    ko: '재생 대비 스킵이 많은 곡',
  ),
  'No high-skip songs': _LocalizedCopy(
    ja: '高スキップ率の曲はありません',
    zh: '没有高跳过率歌曲',
    ko: '스킵률이 높은 곡이 없습니다',
  ),
  'Songs with one play or less': _LocalizedCopy(
    ja: '再生回数が1回以下の曲',
    zh: '播放 1 次或更少的歌曲',
    ko: '재생 횟수가 1회 이하인 곡',
  ),
  'Songs without returned playlist membership': _LocalizedCopy(
    ja: '所属プレイリストが返されていない曲',
    zh: '未返回所属播放列表的歌曲',
    ko: '소속 플레이리스트가 반환되지 않은 곡',
  ),
  'background record': _LocalizedCopy(
    ja: 'バックグラウンド記録',
    zh: '后台记录',
    ko: '백그라운드 기록',
  ),
  'app record': _LocalizedCopy(ja: 'アプリ記録', zh: '应用记录', ko: '앱 기록'),
  'Underplayed': _LocalizedCopy(ja: '未再生・低再生', zh: '未播放/低播放', ko: '미재생/저재생'),
  'Unplayed': _LocalizedCopy(ja: '未再生', zh: '未播放', ko: '미재생'),
  'Unplayed songs': _LocalizedCopy(ja: '未再生の曲', zh: '未播放歌曲', ko: '미재생 곡'),
  'Waiting': _LocalizedCopy(ja: '待機中', zh: '等待中', ko: '대기 중'),
  'Weekdays': _LocalizedCopy(ja: '曜日', zh: '星期', ko: '요일'),
  'Year': _LocalizedCopy(ja: '年', zh: '年', ko: '연도'),
  'Sponsored placement': _LocalizedCopy(ja: '広告枠', zh: '广告位', ko: '광고 영역'),
  'Sponsored': _LocalizedCopy(ja: '広告', zh: '广告', ko: '광고'),
  'Loading a small banner ad': _LocalizedCopy(
    ja: '小さなバナー広告を読み込み中',
    zh: '正在加载小横幅广告',
    ko: '작은 배너 광고를 불러오는 중',
  ),
  'Ad loaded': _LocalizedCopy(ja: '広告を読み込みました', zh: '广告已加载', ko: '광고를 불러왔습니다'),
  'Set a live AdMob ad unit ID before release': _LocalizedCopy(
    ja: '公開前に本番のAdMob広告ユニットIDを設定してください',
    zh: '发布前请设置正式的 AdMob 广告单元 ID',
    ko: '출시 전에 실제 AdMob 광고 단위 ID를 설정하세요',
  ),
  'Ad preview for this launch mode': _LocalizedCopy(
    ja: 'この起動モードの広告プレビュー',
    zh: '当前启动模式的广告预览',
    ko: '현재 실행 모드의 광고 미리보기',
  ),
  'Ad is temporarily unavailable': _LocalizedCopy(
    ja: '広告を一時的に表示できません',
    zh: '广告暂时不可用',
    ko: '광고를 일시적으로 사용할 수 없습니다',
  ),
};
