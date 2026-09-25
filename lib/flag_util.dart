// ─────────────────────────────────────────────────────────────
// 국기 값 다루기 — 게임(design_system.CountryChip)과 백오피스가 같이 쓴다.
// 저장 값은 이모지 국기(🇰🇷)가 기본이고, 옛 기록·백오피스가 남긴 'KR' 같은 코드도 들어 있다.
// 윈도우·웹에서는 이모지 국기가 글자로 보이므로 화면에는 늘 이미지(country_flags)로 그린다.
// ─────────────────────────────────────────────────────────────

/// 국기 값 → ISO 코드(KR). 모르는 값이면 ''
String flagToIso(String flag) {
  final s = flag.trim();
  final runes = s.runes.toList();
  if (runes.length == 2 && runes.every((r) => r >= 0x1F1E6 && r <= 0x1F1FF)) {
    return String.fromCharCodes([for (final r in runes) r - 0x1F1E6 + 0x41]);
  }
  if (s.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(s)) return s.toUpperCase();
  return '';
}
