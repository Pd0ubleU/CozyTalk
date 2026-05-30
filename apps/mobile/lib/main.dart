// ignore_for_file: unused_import
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'shared/prefs_provider.dart';
// chatroom imports
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/hello/presentation/screens/hello_screen.dart';
import 'features/user_status/presentation/providers/user_status_provider.dart';
// main UI imports
import 'theme/app_theme.dart';
import 'theme/app_routes.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart' as ui;
import 'screens/notification_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/blocked_screen.dart';
import 'screens/dress_up_screen.dart';
import 'screens/mood_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/friend_chat_screen.dart';
import 'screens/choose_room_type_screen.dart';
import 'screens/select_background_screen.dart';
import 'screens/join_room_id_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/finding_room_screen.dart';
import 'screens/admin_console_screen.dart';

const _useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

// TOGGLE: flip to true for legacy UI home (design preview), false for chatroom backend testing
const _useMainUI = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ),
  );
  await remoteConfig.setDefaults({'content_filtering_enabled': false});
  try {
    await remoteConfig.fetchAndActivate();
  } catch (e) {
    // Non-fatal — cached/default values remain active. Log so CI/devs can diagnose.
    debugPrint('Remote Config fetch failed: $e');
  }

  if (_useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).useFunctionsEmulator('127.0.0.1', 5001);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    FirebaseDatabase.instance.useDatabaseEmulator('127.0.0.1', 9000);
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    }
  } else if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (_useMainUI) {
      return MaterialApp(
        title: 'CozyTalk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const _MainUIAuthRouter(),
        routes: {
          AppRoutes.notification: (_) => const NotificationScreen(),
          AppRoutes.profile: (_) => const ProfileScreen(),
          AppRoutes.blocked: (_) => const BlockedScreen(),
          AppRoutes.dressUp: (_) => const DressUpScreen(),
          AppRoutes.mood: (_) => const MoodScreen(),
          AppRoutes.friends: (_) => const FriendsScreen(),
          AppRoutes.friendChat: (_) => const FriendChatScreen(),
          AppRoutes.chooseRoomType: (_) => const ChooseRoomTypeScreen(),
          AppRoutes.selectBackground: (ctx) {
            final args = ModalRoute.of(ctx)?.settings.arguments as String?;
            return SelectBackgroundScreen(roomType: args);
          },
          AppRoutes.joinRoomId: (_) => const JoinRoomIdScreen(),
          AppRoutes.findingRoom: (_) => const FindingRoomScreen(),
          AppRoutes.chatScreen: (_) => const ChatScreen(),
          AppRoutes.groupChatScreen: (_) => const GroupChatScreen(),
        },
      );
    }
    return MaterialApp(
      title: 'CozyTalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const _AuthRouter(),
      routes: {
        AppRoutes.notification: (_) => const NotificationScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.blocked: (_) => const BlockedScreen(),
        AppRoutes.dressUp: (_) => const DressUpScreen(),
        AppRoutes.mood: (_) => const MoodScreen(),
        AppRoutes.friends: (_) => const FriendsScreen(),
        AppRoutes.friendChat: (_) => const FriendChatScreen(),
        AppRoutes.chooseRoomType: (_) => const ChooseRoomTypeScreen(),
        AppRoutes.selectBackground: (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments as String?;
          return SelectBackgroundScreen(roomType: args);
        },
        AppRoutes.joinRoomId: (_) => const JoinRoomIdScreen(),
        AppRoutes.chatScreen: (_) => const ChatScreen(),
        AppRoutes.groupChatScreen: (_) => const GroupChatScreen(),
        AppRoutes.findingRoom: (_) => const FindingRoomScreen(),
      },
    );
  }
}

class _MainUIAuthRouter extends ConsumerWidget {
  const _MainUIAuthRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthStatus>(authNotifierProvider.select((s) => s.status), (
      _,
      next,
    ) {
      if (next == AuthStatus.authenticated) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    ref.listen<String?>(authNotifierProvider.select((s) => s.error), (_, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    });
    final authState = ref.watch(authNotifierProvider);
    final status = authState.status;
    if (status == AuthStatus.authenticated) {
      final email = (authState.user?.email ?? '').toLowerCase();
      if (email.isNotEmpty && email.endsWith('@cozytalk.com')) {
        return const AdminConsoleScreen();
      }
      return const HomeScreen();
    }
    return switch (status) {
      AuthStatus.idle => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      _ => const ui.LoginScreen(),
    };
  }
}

// ignore: unused_element
class _AuthRouter extends ConsumerWidget {
  const _AuthRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ownStatusNotifierProvider);
    final status = ref.watch(authNotifierProvider.select((s) => s.status));
    return switch (status) {
      AuthStatus.authenticated => const HelloScreen(),
      AuthStatus.idle => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      _ => const LoginScreen(),
    };
  }
}
