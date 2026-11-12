import 'package:flutter/material.dart';

import 'app_backend.dart';

class BackendEnvironmentScope extends StatelessWidget {
  const BackendEnvironmentScope({
    required this.backend,
    required this.builder,
    super.key,
  });

  final AppBackendRegistry backend;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppBackendEnvironment>(
      valueListenable: backend.environmentListenable,
      builder: (context, environment, _) => KeyedSubtree(
        key: ValueKey(environment),
        child: builder(context),
      ),
    );
  }
}
