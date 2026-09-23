// ─────────────────────────────────────────────────────────────
// 시즌 — 난이도를 크게 바꾸면 시즌을 올려 랭킹을 새로 시작한다. docs/RELEASE.md §시즌 정책
//  - 랭킹(주·월·올해)은 **현재 시즌 시작 이후** 기록만 본다(RankingSystem._getPeriodStart).
//  - 새 기록에는 season 번호를 같이 남긴다(나중에 시즌별 명예의 전당).
//  - 명패는 시즌이 바뀌어도 유지된다.
// 시즌을 올리려면 starts 에 시작 시각(UTC)을 하나 추가하면 된다 — current 는 마지막 번호.
// ─────────────────────────────────────────────────────────────
class Season {
  /// 시즌 시작 시각(UTC). 0 = 존 체계 이후 전부(1.4.0 출시일에 시즌 1을 추가할 예정)
  static final List<DateTime> starts = [DateTime.utc(2000)];

  static int get current => starts.length - 1;
  static DateTime get currentStart => starts.last.toLocal();
}
