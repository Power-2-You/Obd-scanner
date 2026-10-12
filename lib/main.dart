import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  final services = await AppServices.create();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    services.telemetry.recordError(
      details.exception,
      details.stack,
      context: 'flutter',
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    services.telemetry.recordError(error, stack, context: 'platform');
    return true;
  };

  runApp(MghApp(services: services));
}
