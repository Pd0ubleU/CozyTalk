// ignore_for_file: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
// chatroom imports
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/hello/presentation/screens/hello_screen.dart';
// main UI imports
import 'theme/app_theme.dart';
import 'theme/app_routes.dart';
import 'screens/home_screen.dart';
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
import 'screens/admin_console_screen.dart';

const _useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

// TOGGLE: flip to true for legacy UI home (design preview), false for chatroom backend testing
const _useMainUI = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).useFunctionsEmulator('127.0.0.1', 5001);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    FirebaseDatabase.instance.useDatabaseEmulator('127.0.0.1', 9000);
  }

  runApp(const ProviderScope(child: MyApp()));
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
        initialRoute: AppRoutes.adminConsole,
        //initialRoute: AppRoutes.home, // TODO: revert to AppRoutes.home
        routes: {
          AppRoutes.home:             (_) => const HomeScreen(),
          AppRoutes.notification:     (_) => const NotificationScreen(),
          AppRoutes.profile:          (_) => const ProfileScreen(),
          AppRoutes.blocked:          (_) => const BlockedScreen(),
          AppRoutes.dressUp:          (_) => const DressUpScreen(),
          AppRoutes.mood:             (_) => const MoodScreen(),
          AppRoutes.friends:          (_) => const FriendsScreen(),
          AppRoutes.friendChat:       (_) => const FriendChatScreen(),
          AppRoutes.chooseRoomType:   (_) => const ChooseRoomTypeScreen(),
          AppRoutes.selectBackground: (ctx) {
            final args = ModalRoute.of(ctx)?.settings.arguments as String?;
            return SelectBackgroundScreen(roomType: args);
          },
          AppRoutes.joinRoomId:       (_) => const JoinRoomIdScreen(),
          AppRoutes.chatScreen:       (_) => const ChatScreen(),
          AppRoutes.groupChatScreen:  (_) => const GroupChatScreen(),
          AppRoutes.adminConsole:     (_) => const AdminConsoleScreen(),
        },
      );
    }
    return MaterialApp(
      title: 'CozyTalk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const _AuthRouter(),
    );
  }
}

class _AuthRouter extends ConsumerWidget {
  const _AuthRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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