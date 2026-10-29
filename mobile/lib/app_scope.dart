import 'package:flutter/widgets.dart';

import 'api/api_client.dart';
import 'models/app_user.dart';

/// Makes the API client and the signed-in user available to every route.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.api, required super.child, this.user, this.onSignOut});

  final ApiClient api;
  final AppUser? user;
  final VoidCallback? onSignOut;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!;
  }

  static ApiClient apiOf(BuildContext context) => of(context).api;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api || user != oldWidget.user || onSignOut != oldWidget.onSignOut;
}
