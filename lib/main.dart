import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';

/// Android đọc cấu hình Firebase từ `android/app/google-services.json`
/// (plugin com.google.gms.google-services), nên không cần truyền options.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyFapApp(auth: FirebaseAuth.instance, db: FirebaseFirestore.instance));
}
