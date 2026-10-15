import 'dart:async';

import 'package:flutter/material.dart';

import '../injection_container.dart';
import 'sync_manager.dart';
import 'sync_types.dart';

class SyncRefreshListener extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onSyncComplete;

  const SyncRefreshListener({
    super.key,
    required this.child,
    required this.onSyncComplete,
  });

  @override
  State<SyncRefreshListener> createState() => _SyncRefreshListenerState();
}

class _SyncRefreshListenerState extends State<SyncRefreshListener> {
  StreamSubscription<SyncStatus>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _subscription = sl<SyncManager>().status.listen((status) {
      if (status == SyncStatus.success) {
        unawaited(_refreshAfterSync());
      }
    });
  }

  Future<void> _refreshAfterSync() async {
    try {
      await widget.onSyncComplete();
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to refresh local data after sync: $error\n$stackTrace',
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
