import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  final Uri apiBaseUrl;

  /// `--dart-define=API_BASE_URL=http://192.168.1.20:3000` wins. Otherwise the
  /// iOS simulator reaches the Mac's localhost directly, and the Android
  /// emulator reaches it through its 10.0.2.2 alias.
  factory AppConfig.fromEnvironment() {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) return AppConfig(apiBaseUrl: Uri.parse(defined));
    final host = !kIsWeb && Platform.isAndroid ? '10.0.2.2' : 'localhost';
    return AppConfig(apiBaseUrl: Uri.parse('http://$host:3000'));
  }
}
