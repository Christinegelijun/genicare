import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_doctor/src/app.dart';

void main() {
  runApp(const ProviderScope(child: DoctorApp()));
}
