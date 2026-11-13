[1mdiff --git a/lib/core/app_backend.dart b/lib/core/app_backend.dart[m
[1mindex 967a6d0..2dbe26c 100644[m
[1m--- a/lib/core/app_backend.dart[m
[1m+++ b/lib/core/app_backend.dart[m
[36m@@ -11,7 +11,11 @@[m [mimport 'sync/sync_manager.dart';[m
 [m
 enum AppBackendEnvironment { production, review }[m
 [m
[31m-bool hasAdminRole(User? user) => user?.appMetadata['role'] == 'admin';[m
[32m+[m[32mFuture<bool> hasAdminRole(User? user) async {[m
[32m+[m[32m  if (user == null) return false;[m
[32m+[m[32m  final refreshed = await Supabase.instance.client.auth.getUser();[m
[32m+[m[32m  return refreshed.user?.appMetadata['role'] == 'admin';[m
[32m+[m[32m}[m
 [m
 bool isPublishableSupabaseKey(String key) {[m
   if (key.startsWith('sb_publishable_')) return true;[m
[36m@@ -117,7 +121,10 @@[m [mclass AppBackendRegistry {[m
   LocalDataSource get localDataSource => active.localDataSource;[m
   AppDatabase get database => active.database;[m
   SyncManager get syncManager => active.syncManager;[m
[31m-  bool get currentUserIsAdmin => hasAdminRole(client.auth.currentUser);[m
[32m+[m[32m  Future<bool> get currentUserIsAdmin async {[m
[32m+[m[32m    final user = client.auth.currentUser;[m
[32m+[m[32m    return await hasAdminRole(user);[m
[32m+[m[32m  }[m
 [m
   AppBackendContext _contextFor(AppBackendEnvironment environment) {[m
     final context = _contexts[environment];[m
