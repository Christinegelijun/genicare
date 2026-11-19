import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:venicare_server/src/care_store.dart';
import 'package:venicare_server/src/consult_api.dart';
import 'package:venicare_server/src/http_utils.dart';
import 'package:venicare_shared/venicare_shared.dart';

/// Routes take the acting doctor or care recipient from the path. That is a
/// development shortcut: once auth lands, identity must come from the access
/// token and the path id must be checked against it.
class CareApi {
  CareApi(this.store, {Clock? clock}) : _clock = clock ?? DateTime.now;

  final CareStore store;
  final Clock _clock;

  Handler get handler {
    final router = Router()
      ..get('/healthz', (Request _) => jsonResponse({'status': 'ok'}))
      ..post('/api/v1/care-recipients/<rid>/sync', _sync)
      ..get('/api/v1/care-recipients/<rid>/doctors', _patientDoctors)
      ..post('/api/v1/care-recipients/<rid>/reports', _sendReport)
      ..get('/api/v1/care-recipients/<rid>/reports', _patientReports)
      ..get('/api/v1/doctors/<did>', _doctorProfile)
      ..get('/api/v1/doctors/<did>/reports', _doctorInbox)
      ..get('/api/v1/doctors/<did>/reports/<id>', _doctorReport)
      ..post('/api/v1/doctors/<did>/reports/<id>/read', _markRead)
      ..post('/api/v1/doctors/<did>/reports/<id>/replies', _reply);
    ConsultApi(store, _clock).mount(router);

    return const Pipeline()
        .addMiddleware(_cors())
        .addMiddleware(_errors())
        .addHandler(router.call);
  }

  Future<Response> _sync(Request request, String rid) async {
    _requirePatient(rid);
    final body = await readJsonBody(request);
    store.upsertCareData(
      rid,
      readings: _items(body['readings'], VitalReading.fromJson),
      doses: _items(body['doses'], MedicationDose.fromJson),
      events: _items(body['events'], CareEvent.fromJson),
    );
    return jsonResponse({'syncedAt': _clock().toUtc().toIso8601String()});
  }

  Response _patientDoctors(Request request, String rid) {
    _requirePatient(rid);
    return jsonResponse({
      'items': store.doctorsFor(rid).map((d) => d.toJson()).toList(),
    });
  }

  Future<Response> _sendReport(Request request, String rid) async {
    final patient = _requirePatient(rid);
    final body = await readJsonBody(request);
    final doctorIds = requireField<List<Object?>>(
      body,
      'doctorIds',
    ).cast<String>();
    if (doctorIds.isEmpty) {
      throw const ApiException(400, 'INVALID_REQUEST', '至少选择一位医生');
    }
    final doctors = [
      for (final id in doctorIds)
        if (store.isAuthorized(recipientId: rid, doctorId: id))
          store.doctor(id)!
        else
          throw const ApiException(
            403,
            'DOCTOR_NOT_AUTHORIZED',
            '该医生未获授权查看此人报告',
          ),
    ];

    final now = _clock();
    final HealthReport report;
    try {
      report = buildHealthReport(
        id: newId('rpt'),
        patient: patient,
        periodStart: DateTime.parse(requireField<String>(body, 'periodStart')),
        periodEnd: DateTime.parse(requireField<String>(body, 'periodEnd')),
        generatedAt: now,
        requestedBy: requireField<String>(body, 'requestedBy'),
        familyNote: body['familyNote'] as String?,
        readings: store.readings(rid),
        doses: store.doses(rid),
        events: store.events(rid),
      );
    } on FormatException catch (e) {
      throw ApiException(400, 'INVALID_REQUEST', e.message);
    } on ArgumentError catch (e) {
      throw ApiException(400, 'INVALID_REQUEST', '${e.message}');
    }

    final deliveries = [
      for (final doctor in doctors)
        ReportDelivery(
          id: newId('dlv'),
          report: report,
          doctorId: doctor.id,
          doctorName: doctor.name,
          status: DeliveryStatus.sent,
          sentAt: now,
        ),
    ];
    deliveries.forEach(store.saveDelivery);
    return jsonResponse({
      'items': deliveries.map((d) => d.toJson()).toList(),
    }, status: 201);
  }

  Response _patientReports(Request request, String rid) {
    _requirePatient(rid);
    return jsonResponse({
      'items': store.deliveriesForPatient(rid).map((d) => d.toJson()).toList(),
    });
  }

  Response _doctorProfile(Request request, String did) {
    return jsonResponse(_requireDoctor(did).toJson());
  }

  Response _doctorInbox(Request request, String did) {
    _requireDoctor(did);
    final status = request.url.queryParameters['status'];
    final items = store
        .deliveriesForDoctor(did)
        .where((d) => d.status != DeliveryStatus.revoked)
        .where((d) => status == null || d.status.name == status)
        .map((d) => d.toInboxItem().toJson())
        .toList();
    return jsonResponse({'items': items});
  }

  Response _doctorReport(Request request, String did, String id) {
    return jsonResponse(_requireDelivery(did, id).toJson());
  }

  Response _markRead(Request request, String did, String id) {
    final delivery = _requireDelivery(did, id);
    if (delivery.status != DeliveryStatus.sent) {
      return jsonResponse(delivery.toJson());
    }
    final updated = delivery.copyWith(
      status: DeliveryStatus.read,
      readAt: _clock(),
    );
    store.saveDelivery(updated);
    return jsonResponse(updated.toJson());
  }

  Future<Response> _reply(Request request, String did, String id) async {
    final delivery = _requireDelivery(did, id);
    final content = requireField<String>(
      await readJsonBody(request),
      'content',
    ).trim();
    if (content.isEmpty) {
      throw const ApiException(400, 'INVALID_REQUEST', '回复内容不能为空');
    }
    final now = _clock();
    final updated = delivery.copyWith(
      status: DeliveryStatus.replied,
      readAt: delivery.readAt ?? now,
      replies: [
        ...delivery.replies,
        DoctorReply(
          id: newId('rpl'),
          doctorId: did,
          doctorName: delivery.doctorName,
          content: content,
          createdAt: now,
        ),
      ],
    );
    store.saveDelivery(updated);
    return jsonResponse(updated.toJson(), status: 201);
  }

  ReportPatient _requirePatient(String rid) {
    return store.patient(rid) ??
        (throw const ApiException(404, 'NOT_FOUND', '找不到该照护对象'));
  }

  DoctorProfile _requireDoctor(String did) {
    return store.doctor(did) ??
        (throw const ApiException(404, 'NOT_FOUND', '找不到该医生'));
  }

  ReportDelivery _requireDelivery(String did, String id) {
    _requireDoctor(did);
    final delivery = store.delivery(id);
    // Another doctor's report answers 404, not 403, so ids cannot be probed.
    if (delivery == null ||
        delivery.doctorId != did ||
        delivery.status == DeliveryStatus.revoked) {
      throw const ApiException(404, 'NOT_FOUND', '找不到该报告');
    }
    return delivery;
  }
}

List<T> _items<T>(Object? value, T Function(Json) fromJson) {
  try {
    return (value as List<Object?>? ?? const [])
        .map((item) => fromJson(item! as Json))
        .toList();
  } on Object {
    throw const ApiException(400, 'INVALID_REQUEST', '同步数据格式错误');
  }
}

Middleware _errors() {
  return (inner) => (request) async {
    try {
      return await inner(request);
    } on ApiException catch (e) {
      return jsonResponse({
        'error': {'code': e.code, 'message': e.message},
      }, status: e.status);
    }
  };
}

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'access-control-allow-headers': 'content-type, authorization',
};

/// Open CORS is for local development with the web doctor client only.
Middleware _cors() {
  return (inner) => (request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok(null, headers: _corsHeaders);
    }
    final response = await inner(request);
    return response.change(headers: _corsHeaders);
  };
}
