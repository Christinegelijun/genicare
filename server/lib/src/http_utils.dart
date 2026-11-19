import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:venicare_shared/venicare_shared.dart';

typedef Clock = DateTime Function();

class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;
}

String newId(String prefix) {
  final random = Random.secure();
  final suffix = List.generate(
    16,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
  return '${prefix}_$suffix';
}

Future<Json> readJsonBody(Request request) async {
  try {
    return jsonDecode(await request.readAsString()) as Json;
  } on FormatException {
    throw const ApiException(400, 'INVALID_REQUEST', '请求体不是合法 JSON');
  } on TypeError {
    throw const ApiException(400, 'INVALID_REQUEST', '请求体必须是 JSON 对象');
  }
}

T requireField<T>(Json body, String name) {
  final value = body[name];
  if (value is T) return value;
  throw ApiException(400, 'INVALID_REQUEST', '缺少或错误的字段 $name');
}

T parseEnum<T extends Enum>(List<T> values, String? name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw ApiException(400, 'INVALID_REQUEST', '缺少或错误的字段 $field');
}

Response jsonResponse(Object body, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
