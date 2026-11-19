import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_doctor/src/api/doctor_api.dart';
import 'package:venicare_shared/venicare_shared.dart';

final doctorApiProvider = Provider<DoctorApi>(
  (ref) => HttpDoctorApi(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8081',
    ),
    doctorId: const String.fromEnvironment(
      'DOCTOR_ID',
      defaultValue: 'doctor-zhang',
    ),
  ),
);

final doctorProfileProvider = FutureProvider<DoctorProfile>(
  (ref) => ref.watch(doctorApiProvider).profile(),
);

final inboxFilterProvider = NotifierProvider<InboxFilter, DeliveryStatus?>(
  InboxFilter.new,
);

class InboxFilter extends Notifier<DeliveryStatus?> {
  @override
  DeliveryStatus? build() => null;

  void set(DeliveryStatus? status) => state = status;
}

final inboxProvider = FutureProvider<List<ReportInboxItem>>(
  (ref) => ref
      .watch(doctorApiProvider)
      .inbox(status: ref.watch(inboxFilterProvider)),
);

final selectedDeliveryProvider =
    NotifierProvider<SelectedDelivery, AsyncValue<ReportDelivery>?>(
      SelectedDelivery.new,
    );

class SelectedDelivery extends Notifier<AsyncValue<ReportDelivery>?> {
  @override
  AsyncValue<ReportDelivery>? build() => null;

  String? get _currentId => state?.value?.id;

  Future<void> open(String deliveryId) async {
    final api = ref.read(doctorApiProvider);
    state = const AsyncLoading();
    try {
      var delivery = await api.delivery(deliveryId);
      if (delivery.status == DeliveryStatus.sent) {
        delivery = await api.markRead(deliveryId);
        ref.invalidate(inboxProvider);
      }
      if (!ref.mounted) return;
      state = AsyncData(delivery);
    } on Object catch (error, stack) {
      if (!ref.mounted) return;
      state = AsyncError(error, stack);
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> reply(String content) async {
    final id = _currentId;
    if (id == null) return '请先选择一份报告';
    try {
      final updated = await ref.read(doctorApiProvider).reply(id, content);
      if (!ref.mounted) return null;
      state = AsyncData(updated);
      ref.invalidate(inboxProvider);
      return null;
    } on ApiError catch (error) {
      return error.message;
    }
  }
}
