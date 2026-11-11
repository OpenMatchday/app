import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/open_matchday_theme.dart';
import 'media_bridge.dart';
import 'role_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Spike-only smoke: flutter run --dart-define=SPIKE_AUTO_PING=true
  if (const bool.fromEnvironment('SPIKE_AUTO_PING')) {
    try {
      final result = await MediaBridge().pingMedia();
      debugPrint('SPIKE_PING platform=${result.platform} stamp=${result.stamp}');
    } on PlatformException catch (error) {
      debugPrint('SPIKE_PING_FAIL ${error.code} ${error.message}');
    } catch (error) {
      debugPrint('SPIKE_PING_FAIL $error');
    }
  }
  runApp(const OpenMatchdayApp());
}

class OpenMatchdayApp extends StatelessWidget {
  const OpenMatchdayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Matchday',
      theme: openMatchdayDirectorTheme(),
      home: const RoleShellPage(),
    );
  }
}
