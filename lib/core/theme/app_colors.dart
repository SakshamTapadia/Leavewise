import 'package:flutter/material.dart';
import 'package:leavewise/features/leave_balance/domain/leave_balance.dart';
import 'package:leavewise/features/leave_optimizer/domain/optimizer_models.dart';

/// Design tokens. Spacing follows an 8dp grid.
class AppColors {
  AppColors._();

  static const holiday = Color(0xFFEF5350);
  static const leave = Color(0xFFF5C84C);
  static const weekend = Color(0xFFAEE8D5);
  static const background = Color(0xFFFAFAFC);
  static const textPrimary = Color(0xFF20212B);
  static const textSecondary = Color(0xFF777987);
  static const accent = Color(0xFF1F2A60);
  static const darkSurface = Color(0xFF14151C);
  static const darkCard = Color(0xFF1D1E28);
}

class Gap {
  Gap._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
}

Color dayKindColor(DayKind kind) {
  switch (kind) {
    case DayKind.holiday:
      return AppColors.holiday;
    case DayKind.weekend:
      return AppColors.weekend;
    case DayKind.leave:
    case DayKind.existingLeave:
      return AppColors.leave;
  }
}

/// Short letter shown on a day so status never depends on color alone.
String dayKindLetter(DayKind kind) {
  switch (kind) {
    case DayKind.holiday:
      return 'H';
    case DayKind.weekend:
      return 'O';
    case DayKind.leave:
    case DayKind.existingLeave:
      return 'L';
  }
}

String dayKindLabel(DayKind kind) {
  switch (kind) {
    case DayKind.holiday:
      return 'Public holiday';
    case DayKind.weekend:
      return 'Weekend or day off';
    case DayKind.leave:
      return 'Leave needed';
    case DayKind.existingLeave:
      return 'Leave already planned';
  }
}

String leaveStatusLabel(LeaveStatus status) {
  switch (status) {
    case LeaveStatus.suggested:
      return 'Suggested';
    case LeaveStatus.planned:
      return 'Planned';
    case LeaveStatus.applied:
      return 'Applied';
    case LeaveStatus.approved:
      return 'Approved';
    case LeaveStatus.rejected:
      return 'Rejected';
    case LeaveStatus.cancelled:
      return 'Cancelled';
  }
}

Color leaveStatusColor(LeaveStatus status) {
  switch (status) {
    case LeaveStatus.suggested:
      return const Color(0xFF8A8DA0);
    case LeaveStatus.planned:
      return const Color(0xFFC99A00);
    case LeaveStatus.applied:
      return const Color(0xFF3D6FD8);
    case LeaveStatus.approved:
      return const Color(0xFF2E9A6B);
    case LeaveStatus.rejected:
      return const Color(0xFFD64541);
    case LeaveStatus.cancelled:
      return const Color(0xFF8A8DA0);
  }
}
