import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translations.dart';

class LanguageManager extends ChangeNotifier {
  static final LanguageManager _instance = LanguageManager._internal();
  factory LanguageManager() => _instance;
  LanguageManager._internal();

  String _currentLanguage = 'en';
  String get currentLanguage => _currentLanguage;

  /// 지원 언어(표시 이름). 중국어·일본어는 번역을 채우는 중이라 [showDraftLanguages] 가 true 일 때만 설정에 보인다.
  static const Map<String, String> languageNames = {'en': 'EN', 'ko': 'KO', 'zh': '中文', 'ja': '日本語'};
  static const List<String> releasedLanguages = ['en', 'ko'];
  static const List<String> draftLanguages = ['zh', 'ja'];
  static const bool showDraftLanguages = false;
  static List<String> get visibleLanguages => [...releasedLanguages, if (showDraftLanguages) ...draftLanguages];

  /// 강조 표기 `[존]` 을 떼어 낸 문구 — 공유 문구 등 강조를 그릴 수 없는 곳에 쓴다
  static String stripEmphasis(String s) => s.replaceAll('[', '').replaceAll(']', '');

  /// `[존]에서 [버]텨라` → (글자, 강조 여부) 조각들
  static List<(String, bool)> parseEmphasis(String s) {
    final out = <(String, bool)>[];
    final re = RegExp(r'\[([^\]]+)\]');
    int i = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > i) out.add((s.substring(i, m.start), false));
      out.add((m.group(1)!, true));
      i = m.end;
    }
    if (i < s.length) out.add((s.substring(i), false));
    return out;
  }

  /// Helper to access via Provider context to ensure rebuilds on change.
  /// Set listen: false when calling from event handlers (onPressed, onTap, etc.)
  static LanguageManager of(BuildContext context, {bool listen = true}) {
    return Provider.of<LanguageManager>(context, listen: listen);
  }

  Future<void> init() async {
    print('LanguageManager: init() called');
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'ko';
    print('LanguageManager: Loaded language $_currentLanguage');
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    print('LanguageManager: changeLanguage($languageCode) called. Current: $_currentLanguage');
    if (_currentLanguage == languageCode) return;

    if (appTranslations.containsKey(languageCode)) {
      // Optimistic update
      _currentLanguage = languageCode;
      notifyListeners();
      print('LanguageManager: Language changed to $languageCode (Optimistic)');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language', languageCode);
        print('LanguageManager: Persisted language to prefs');
      } catch (e) {
        print('LanguageManager: Failed to save language: $e');
      }
    } else {
      print('LanguageManager: Invalid language code $languageCode');
    }
  }

  /// 화면 표시용 문구. 한글은 어절 단위로만 줄이 바뀌도록 [keepWords] 를 적용한다.
  /// 공유·클립보드처럼 앱 밖으로 나가는 문자열은 [stripJoiners] 로 되돌려서 쓴다.
  /// 두 줄 이상 문구의 줄바꿈 위치는 스트링 테이블(translations.dart)의 \n 으로 정한다.
  String translate(String key) {
    // Default to EN if key missing in current language
    final raw = appTranslations[_currentLanguage]?[key] ??
        appTranslations['en']?[key] ??
        key;
    return _wrapCache.putIfAbsent('$_currentLanguage|$key', () => keepWords(raw));
  }

  final Map<String, String> _wrapCache = {};

  static const String _wordJoiner = '\u2060';
  static final RegExp _hangul = RegExp('[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7A3]');

  /// 한글은 기본적으로 글자마다 줄바꿈이 허용돼 어절 한가운데서 잘린다.
  /// 어절 안의 글자 사이에 WORD JOINER(U+2060, 폭 0)를 넣어 공백에서만 줄이 바뀌게 한다.
  /// `{name}` 같은 치환자 안에는 넣지 않는다(replaceAll 이 깨지지 않게).
  static String keepWords(String s) {
    // 짧은 라벨·버튼(자간이 들어간 것 포함)은 줄이 바뀔 일이 없다 — 제어 문자에도 자간이 붙어
    // "또 는"처럼 벌어지므로 넣지 않는다. 공백이 있고 16자를 넘는 설명 문구에만 적용.
    if (s.length <= 16 || !s.contains(' ') || !_hangul.hasMatch(s)) return s;
    final out = StringBuffer();
    bool inPlaceholder = false;
    String? prev;
    for (final ch in s.split('')) {
      if (ch == '{') inPlaceholder = true;
      if (prev != null &&
          !inPlaceholder &&
          prev != '}' &&
          ch.trim().isNotEmpty &&
          prev.trim().isNotEmpty &&
          (_hangul.hasMatch(ch) || _hangul.hasMatch(prev))) {
        out.write(_wordJoiner);
      }
      out.write(ch);
      if (ch == '}') inPlaceholder = false;
      prev = ch;
    }
    return out.toString();
  }

  /// 앱 밖(공유·클립보드)으로 나가는 문자열에서 줄바꿈 제어 문자를 뺀다
  static String stripJoiners(String s) => s.replaceAll(_wordJoiner, '');
}
