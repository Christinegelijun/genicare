import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:venicare_server/venicare_server.dart';

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  final store = InMemoryCareStore();
  if (Platform.environment['VENICARE_SEED_DEMO'] != 'false') {
    seedDemoData(store, DateTime.now());
  }

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(CareApi(store).handler);
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('VeniCare API listening on http://localhost:${server.port}');
}
