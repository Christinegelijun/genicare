import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_doctor/src/state/workbench_controller.dart';
import 'package:venicare_shared/venicare_shared.dart';

enum WorkbenchSection { reports, admin }

final workbenchSectionProvider =
    NotifierProvider<WorkbenchSectionNotifier, WorkbenchSection>(
      WorkbenchSectionNotifier.new,
    );

class WorkbenchSectionNotifier extends Notifier<WorkbenchSection> {
  @override
  WorkbenchSection build() => WorkbenchSection.reports;

  void set(WorkbenchSection section) => state = section;
}

final presenceProvider = AsyncNotifierProvider<PresenceNotifier, DoctorPresence>(
  PresenceNotifier.new,
);

class PresenceNotifier extends AsyncNotifier<DoctorPresence> {
  @override
  Future<DoctorPresence> build() => ref.read(doctorApiProvider).presence();

  Future<void> set(DoctorPresence presence) async {
    final previous = state;
    state = AsyncData(presence);
    try {
      final saved = await ref.read(doctorApiProvider).setPresence(presence);
      if (!ref.mounted) return;
      state = AsyncData(saved);
      ref.invalidate(adminBoardProvider);
    } on Object {
      if (!ref.mounted) return;
      state = previous;
      rethrow;
    }
  }
}

final adminBoardProvider = FutureProvider<AdminBoard>(
  (ref) => ref.watch(doctorApiProvider).adminBoard(),
);

final boardDepartmentProvider =
    NotifierProvider<BoardDepartmentNotifier, String?>(
      BoardDepartmentNotifier.new,
    );

class BoardDepartmentNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? departmentId) => state = departmentId;
}

DateTime mondayOf(DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

final scheduleWeekProvider = NotifierProvider<ScheduleWeekNotifier, DateTime>(
  ScheduleWeekNotifier.new,
);

class ScheduleWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => mondayOf(DateTime.now());

  void shift(int weeks) => state = state.add(Duration(days: 7 * weeks));

  void reset() => state = mondayOf(DateTime.now());
}

final weekScheduleProvider = FutureProvider<WeekSchedule>(
  (ref) => ref
      .watch(doctorApiProvider)
      .weekSchedule(ref.watch(scheduleWeekProvider)),
);
