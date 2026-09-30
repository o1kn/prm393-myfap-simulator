import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/academic_repository.dart';
import '../data/repositories/application_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/grade_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/user_repository.dart';
import '../viewmodels/auth_view_model.dart';
import '../views/home/home_shell.dart';
import '../views/login_screen.dart';
import '../views/splash_screen.dart';
import 'app_theme.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
}

/// Gốc ứng dụng. Nhận [auth] và [db] từ ngoài để test thay bằng bản giả.
///
/// Luồng dữ liệu (MVVM): View → ViewModel (ChangeNotifier) → Repository →
/// Firebase Auth / Cloud Firestore.
class MyFapApp extends StatelessWidget {
  const MyFapApp({super.key, required this.auth, required this.db});

  final FirebaseAuth auth;
  final FirebaseFirestore db;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AcademicRepository(db)),
        Provider(create: (_) => GradeRepository(db)),
        Provider(create: (_) => UserRepository(db)),
        Provider(create: (_) => ApplicationRepository(db)),
        Provider(create: (_) => NotificationRepository(db)),
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(AuthRepository(auth, db)),
        ),
      ],
      child: MaterialApp(
        title: 'myFAP (giả lập)',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        initialRoute: Routes.splash,
        routes: {
          Routes.splash: (_) => const SplashScreen(),
          Routes.login: (_) => const LoginScreen(),
          Routes.home: (_) => const HomeShell(),
        },
      ),
    );
  }
}
