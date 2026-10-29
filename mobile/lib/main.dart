import 'package:flutter/material.dart';

import 'app.dart';
import 'config.dart';
import 'session/session_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MeetingActionApp(config: AppConfig.fromEnvironment(), sessionStore: SharedPreferencesSessionStore()));
}
