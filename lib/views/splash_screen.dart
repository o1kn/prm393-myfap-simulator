import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/app_theme.dart';
import '../viewmodels/auth_view_model.dart';

/// Splash → còn phiên đăng nhập thì vào Home, không thì sang Login
/// (Module 10: auto login).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final auth = context.read<AuthViewModel>();
    await auth.restore();
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacementNamed(auth.user == null ? Routes.login : Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: fapNavy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'myFAP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text('FPT University', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFFF39200)),
          ],
        ),
      ),
    );
  }
}
