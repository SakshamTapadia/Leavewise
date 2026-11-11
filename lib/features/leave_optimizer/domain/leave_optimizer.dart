import 'dart:math' as math;

import 'package:leavewise/core/utils/date_utils.dart';
import 'package:leavewise/features/leave_optimizer/domain/optimizer_models.dart';

/// Pure Dart leave optimiser. No Flutter, storage or network dependencies.
///
/// Model: within the planning horizon every day is either "free" (a holiday,
/// a non-working weekday, or an already-planned leave) or "costly" (a normal
/// working day that needs a new leave). A recommendation is a contiguous
/// window containing exactly c costly days that cannot be extended on either
/// side without spending another leave. Every such maximal window is
/// enumerated for c = 1..maxLeaves, so the result is exhaustive rather than
/// heuristic, and durations come straight from the calendar.
class LeaveOptimizer {
  const LeaveOptimizer();

  /// Every maximal break within the input's limits, in no particular order.
  List<LeaveRecommendation> candidates(OptimizerInput input) {
    if (!input.schedule.isValid) {
      throw ArgumentError('Work schedule must have 1..7 valid weekdays');
    }
    final grid = _DayGrid.tryBuild(input);
    if (grid == null) return <LeaveRecommendation>[];

    final balanceCap = input.availableBalance;
    final maxLeaves = balanceCap == null
        ? input.leaveBudget
        : math.min(input.leaveBudget, balanceCap);
    if (maxLeaves <= 0) return <LeaveRecommendation>[];

    final result = <LeaveRecommendation>[];
    final costly = grid.costlyPositions;
    for (var i = 0; i < grid.length; i++) {
      // Only start where the previous day is not free, otherwise the window
      // could grow leftwards at no cost and would not be maximal.
      if (i > 0 && grid.free[i - 1]) continue;
      final first = grid.costlyBefore[i];
      for (var c = 1; c <= maxLeaves; c++) {
        final index = first + c - 1;
        if (index >= costly.length) break;
        final last =
            index + 1 < costly.length ? costly[index + 1] - 1 : grid.length - 1;
        final total = last - i + 1;
        if (total < input.minimumDaysOff || total <= c) continue;
        result.add(grid.recommendation(i, last));
      }
    }
    return result;
  }

  /// Ranked recommendations. By default no two recommendations overlap and,
  /// when a balance is set, their combined leaves never exceed it.
  List<LeaveRecommendation> recommend(
    OptimizerInput input, {
    RecommendationSort sort = RecommendationSort.bestEfficiency,
    int? limit,
    bool allowOverlap = false,
  }) {
    final all = candidates(input)..sort((a, b) => _compare(a, b, sort));
    if (allowOverlap) {
      return limit == null ? all : all.take(limit).toList();
    }
    final picked = <LeaveRecommendation>[];
    var remaining = input.availableBalance;
    for (final candidate in all) {
      if (limit != null && picked.length >= limit) break;
      if (remaining != null && candidate.leavesRequired > remaining) continue;
      if (picked.any((p) => p.overlaps(candidate))) continue;
      picked.add(candidate);
      if (remaining != null) remaining -= candidate.leavesRequired;
    }
    return picked;
  }

  /// Breaks that need no leave and contain at least one holiday, such as a
  /// long weekend. Already-planned leave is not treated as free here.
  List<FreeStretch> freeStretches(
    OptimizerInput input, {
    int minimumLength = 3,
  }) {
    final grid = _DayGrid.tryBuild(input);
    if (grid == null) return <FreeStretch>[];
    final stretches = <FreeStretch>[];
    var i = 0;
    while (i < grid.length) {
      if (!grid.freeWithoutLeave[i]) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < grid.length && grid.freeWithoutLeave[j + 1]) {
        j++;
      }
      final names = <String>[];
      for (var k = i; k <= j; k++) {
        names.addAll(grid.holidayNames[k] ?? const <String>[]);
      }
      if (j - i + 1 >= minimumLength && names.isNotEmpty) {
        stretches.add(
          FreeStretch(
            start: addDays(grid.start, i),
            end: addDays(grid.start, j),
            holidayNames: names,
          ),
        );
      }
      i = j + 1;
    }
    return stretches;
  }

  /// Picks a non-overlapping set of breaks that spends at most [totalLeaves]
  /// across the horizon, maximising [objective]. Solved exactly with dynamic
  /// programming over breaks ordered by end date.
  AnnualPlan planAnnual(
    OptimizerInput input, {
    required int totalLeaves,
    AnnualObjective objective = AnnualObjective.longestBreaks,
  }) {
    final balanceCap = input.availableBalance;
    final cap =
        balanceCap == null ? totalLeaves : math.min(totalLeaves, balanceCap);
    if (cap <= 0) return AnnualPlan(const []);

    final cands = candidates(input)
        .where((c) => c.leavesRequired <= cap)
        .toList()
      ..sort((a, b) {
        final byEnd = a.end.compareTo(b.end);
        return byEnd != 0 ? byEnd : a.start.compareTo(b.start);
      });
    final m = cands.length;
    if (m == 0) return AnnualPlan(const []);

    // prev[k] = how many candidates end strictly before cands[k] starts.
    final prev = List<int>.filled(m, 0);
    for (var k = 0; k < m; k++) {
      var lo = 0;
      var hi = m;
      while (lo < hi) {
        final mid = (lo + hi) ~/ 2;
        if (cands[mid].end.isBefore(cands[k].start)) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      prev[k] = lo;
    }

    int score(LeaveRecommendation r) {
      final value = objective == AnnualObjective.totalDaysOff
          ? r.totalDays
          : r.totalDays * r.totalDays;
      // Primary: value. Secondary: fewer leaves.
      return value * 1000 - r.leavesRequired;
    }

    final dp = List.generate(m + 1, (_) => List<int>.filled(cap + 1, 0));
    for (var j = 1; j <= m; j++) {
      final cand = cands[j - 1];
      final c = cand.leavesRequired;
      final value = score(cand);
      final p = prev[j - 1];
      for (var b = 0; b <= cap; b++) {
        var best = dp[j - 1][b];
        if (c <= b) {
          final take = value + dp[p][b - c];
          if (take > best) best = take;
        }
        dp[j][b] = best;
      }
    }

    final chosen = <LeaveRecommendation>[];
    var j = m;
    var b = cap;
    while (j > 0) {
      if (dp[j][b] == dp[j - 1][b]) {
        j--;
      } else {
        final cand = cands[j - 1];
        chosen.add(cand);
        b -= cand.leavesRequired;
        j = prev[j - 1];
      }
    }
    chosen.sort((a, b) => a.start.compareTo(b.start));
    return AnnualPlan(chosen);
  }
}

int _compare(
  LeaveRecommendation a,
  LeaveRecommendation b,
  RecommendationSort sort,
) {
  final totalDesc = b.totalDays.compareTo(a.totalDays);
  final leavesAsc = a.leavesRequired.compareTo(b.leavesRequired);
  // a is more efficient than b when a.total / a.leaves > b.total / b.leaves.
  // Cross-multiplying avoids floating point error.
  final efficiencyDesc =
      (b.totalDays * a.leavesRequired).compareTo(a.totalDays * b.leavesRequired);
  final startAsc = a.start.compareTo(b.start);

  final List<int> chain;
  switch (sort) {
    case RecommendationSort.maxDaysOff:
      chain = [totalDesc, leavesAsc, startAsc];
    case RecommendationSort.minLeaves:
      chain = [leavesAsc, totalDesc, startAsc];
    case RecommendationSort.bestEfficiency:
      chain = [efficiencyDesc, totalDesc, startAsc];
    case RecommendationSort.earliest:
      chain = [startAsc, efficiencyDesc, totalDesc];
  }
  for (final result in chain) {
    if (result != 0) return result;
  }
  return a.end.compareTo(b.end);
}

/// Day-by-day view of the planning horizon.
class _DayGrid {
  _DayGrid._({
    required this.start,
    required this.length,
    required this.working,
    required this.existing,
    required this.holidayNames,
    required this.free,
    required this.freeWithoutLeave,
    required this.costlyPositions,
    required this.costlyBefore,
  });

  final DateTime start;
  final int length;
  final List<bool> working;
  final List<bool> existing;
  final Map<int, List<String>> holidayNames;

  /// Holiday, non-working weekday, or already-planned leave.
  final List<bool> free;

  /// Holiday or non-working weekday only.
  final List<bool> freeWithoutLeave;

  /// Indices of days that would each cost one new leave.
  final List<int> costlyPositions;

  /// costlyBefore[i] = number of costly days at indices < i.
  final List<int> costlyBefore;

  static _DayGrid? tryBuild(OptimizerInput input) {
    final start = input.horizonStart;
    final length = daysBetween(start, input.horizonEnd) + 1;
    if (length <= 0) return null;

    final names = <int, List<String>>{};
    for (final h in input.holidays) {
      final index = daysBetween(start, h.date);
      if (index < 0 || index >= length) continue;
      final list = names.putIfAbsent(index, () => <String>[]);
      if (!list.contains(h.name)) list.add(h.name);
    }

    final working = List<bool>.filled(length, false);
    final existing = List<bool>.filled(length, false);
    final free = List<bool>.filled(length, false);
    final freeWithoutLeave = List<bool>.filled(length, false);
    final costly = <int>[];
    final costlyBefore = List<int>.filled(length + 1, 0);
    for (var i = 0; i < length; i++) {
      final date = addDays(start, i);
      working[i] = input.schedule.isWorkingDay(date);
      existing[i] = input.existingLeaveDays.contains(date);
      freeWithoutLeave[i] = names.containsKey(i) || !working[i];
      free[i] = freeWithoutLeave[i] || existing[i];
      costlyBefore[i] = costly.length;
      if (!free[i]) costly.add(i);
    }
    costlyBefore[length] = costly.length;

    return _DayGrid._(
      start: start,
      length: length,
      working: working,
      existing: existing,
      holidayNames: names,
      free: free,
      freeWithoutLeave: freeWithoutLeave,
      costlyPositions: costly,
      costlyBefore: costlyBefore,
    );
  }

  LeaveRecommendation recommendation(int from, int to) {
    final days = <BreakDay>[];
    for (var i = from; i <= to; i++) {
      final names = holidayNames[i];
      final DayKind kind;
      if (names != null) {
        kind = DayKind.holiday;
      } else if (!working[i]) {
        kind = DayKind.weekend;
      } else if (existing[i]) {
        kind = DayKind.existingLeave;
      } else {
        kind = DayKind.leave;
      }
      days.add(
        BreakDay(
          date: addDays(start, i),
          kind: kind,
          holidayNames: names ?? const [],
        ),
      );
    }
    return LeaveRecommendation(days: days);
  }
}
