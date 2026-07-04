// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'SongBrief';

  @override
  String get appLockedTitle => 'SongBrief가 잠겨 있습니다';

  @override
  String get appLockedSubtitle => '기기 인증으로 잠금을 해제하세요.';

  @override
  String get authenticationFailed => '인증에 실패했습니다.';

  @override
  String get unlockSongBriefReason => 'SongBrief 잠금을 해제합니다.';

  @override
  String get unlock => '잠금 해제';

  @override
  String get sponsoredPlacement => '광고 영역';

  @override
  String get sponsored => '광고';

  @override
  String get adLoadingSmallBanner => '작은 배너 광고를 불러오는 중';

  @override
  String get adLoaded => '광고를 불러왔습니다';

  @override
  String get adMissingLiveUnit => '출시 전에 실제 AdMob 광고 단위 ID를 설정하세요';

  @override
  String get adPreviewForLaunchMode => '현재 실행 모드의 광고 미리보기';

  @override
  String get adTemporarilyUnavailable => '광고를 일시적으로 사용할 수 없습니다';

  @override
  String get premiumUnlockedByLaunchMode => '실행 모드로 프리미엄이 활성화되어 있습니다.';

  @override
  String get premiumPurchaseWaiting => '스토어의 구매 확인을 기다리고 있습니다.';

  @override
  String get premiumRestoreRequestSent => '스토어에 복원 요청을 보냈습니다.';

  @override
  String get premiumActiveAdsRemoved => '프리미엄이 활성화되어 광고가 제거되었습니다.';

  @override
  String get premiumPurchasePending => '구매가 대기 중입니다.';

  @override
  String get premiumPurchaseFailed => '구매에 실패했습니다.';

  @override
  String get premiumStoreUnavailable => '스토어를 사용할 수 없습니다.';

  @override
  String get premiumConfigureProduct =>
      'App Store Connect에서 비소모성 상품을 설정하면 구매가 활성화됩니다.';
}
