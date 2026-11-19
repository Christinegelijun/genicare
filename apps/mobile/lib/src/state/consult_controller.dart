import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/data/demo_consult_repository.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_shared/venicare_shared.dart';

final consultRepositoryProvider = Provider<DemoConsultRepository>(
  (ref) => DemoConsultRepository(),
);

final consultDepartmentProvider =
    NotifierProvider<ConsultDepartmentNotifier, String?>(
      ConsultDepartmentNotifier.new,
    );

class ConsultDepartmentNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? departmentId) => state = departmentId;
}

final consultDepartmentsProvider = Provider<List<Department>>(
  (ref) => ref.watch(consultRepositoryProvider).departments(),
);

final consultDoctorsProvider = Provider<List<DoctorCard>>((ref) {
  final departmentId = ref.watch(consultDepartmentProvider);
  // Rebuild when appointments change.
  ref.watch(myAppointmentsProvider);
  return ref
      .watch(consultRepositoryProvider)
      .doctors(departmentId: departmentId);
});

final myAppointmentsProvider =
    NotifierProvider<MyAppointmentsNotifier, List<MyAppointment>>(
      MyAppointmentsNotifier.new,
    );

class MyAppointmentsNotifier extends Notifier<List<MyAppointment>> {
  @override
  List<MyAppointment> build() => _load();

  List<MyAppointment> _load() {
    final recipientId = ref.read(appControllerProvider).recipient.id;
    return ref.read(consultRepositoryProvider).myAppointments(recipientId);
  }

  void refresh() => state = _load();

  String? book({
    required String slotId,
    required ConsultMode mode,
    String? note,
  }) {
    final app = ref.read(appControllerProvider);
    final self = app.members.firstWhere((m) => m.isSelf);
    try {
      ref
          .read(consultRepositoryProvider)
          .book(
            careRecipientId: app.recipient.id,
            patientName: app.recipient.name,
            slotId: slotId,
            mode: mode,
            bookedBy: self.name,
            note: note,
          );
      refresh();
      return null;
    } on StateError catch (error) {
      return error.message;
    }
  }

  String? cancel(String appointmentId) {
    final recipientId = ref.read(appControllerProvider).recipient.id;
    try {
      ref.read(consultRepositoryProvider).cancel(recipientId, appointmentId);
      refresh();
      return null;
    } on StateError catch (error) {
      return error.message;
    }
  }
}
