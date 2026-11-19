import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:venicare_shared/venicare_shared.dart';

abstract interface class DoctorApi {
  Future<DoctorProfile> profile();

  Future<List<ReportInboxItem>> inbox({DeliveryStatus? status});

  Future<ReportDelivery> delivery(String deliveryId);

  Future<ReportDelivery> markRead(String deliveryId);

  Future<ReportDelivery> reply(String deliveryId, String content);

  Future<DoctorPresence> presence();

  Future<DoctorPresence> setPresence(DoctorPresence presence);

  Future<AdminBoard> adminBoard();

  Future<WeekSchedule> weekSchedule(DateTime from);
}

class ApiError implements Exception {
  const ApiError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Until login exists the doctor id is passed in at build time; see README.
class HttpDoctorApi implements DoctorApi {
  HttpDoctorApi({
    required this.baseUrl,
    required this.doctorId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String doctorId;
  final http.Client _client;

  String get _root => '$baseUrl/api/v1/doctors/$doctorId';

  @override
  Future<DoctorProfile> profile() async {
    return DoctorProfile.fromJson(await _send('GET', _root));
  }

  @override
  Future<List<ReportInboxItem>> inbox({DeliveryStatus? status}) async {
    final query = status == null ? '' : '?status=${status.name}';
    final body = await _send('GET', '$_root/reports$query');
    return (body['items']! as List<Object?>)
        .map((item) => ReportInboxItem.fromJson(item! as Json))
        .toList();
  }

  @override
  Future<ReportDelivery> delivery(String deliveryId) async {
    return ReportDelivery.fromJson(
      await _send('GET', '$_root/reports/$deliveryId'),
    );
  }

  @override
  Future<ReportDelivery> markRead(String deliveryId) async {
    return ReportDelivery.fromJson(
      await _send('POST', '$_root/reports/$deliveryId/read'),
    );
  }

  @override
  Future<ReportDelivery> reply(String deliveryId, String content) async {
    return ReportDelivery.fromJson(
      await _send('POST', '$_root/reports/$deliveryId/replies', {
        'content': content,
      }),
    );
  }

  @override
  Future<DoctorPresence> presence() async {
    final body = await _send('GET', '$_root/presence');
    return DoctorPresence.values.byName(body['presence']! as String);
  }

  @override
  Future<DoctorPresence> setPresence(DoctorPresence presence) async {
    final body = await _send('PUT', '$_root/presence', {
      'presence': presence.name,
    });
    return DoctorPresence.values.byName(body['presence']! as String);
  }

  @override
  Future<AdminBoard> adminBoard() async {
    return AdminBoard.fromJson(await _send('GET', '$_root/admin/board'));
  }

  @override
  Future<WeekSchedule> weekSchedule(DateTime from) async {
    final date =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    return WeekSchedule.fromJson(
      await _send('GET', '$_root/admin/schedule?from=$date&days=7'),
    );
  }

  Future<Json> _send(String method, String url, [Json? body]) async {
    final http.Response response;
    try {
      final request = http.Request(method, Uri.parse(url));
      if (body != null) {
        request
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode(body);
      }
      response = await http.Response.fromStream(await _client.send(request));
    } on Exception {
      throw const ApiError('无法连接服务器，请检查网络或稍后重试');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Json;
    if (response.statusCode >= 400) {
      final error = decoded['error'] as Json?;
      throw ApiError(error?['message'] as String? ?? '请求失败');
    }
    return decoded;
  }
}
