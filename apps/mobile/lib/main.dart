import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venicare_app/src/app.dart';
import 'package:venicare_app/src/data/app_mode_store.dart';
import 'package:venicare_app/src/state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [appModeStoreProvider.overrideWithValue(AppModeStore(prefs))],
      child: const VeniCareApp(),
    ),
  );
}
