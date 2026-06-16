import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const UbuntuOasisApp());
}

class UbuntuOasisApp extends StatelessWidget {
  const UbuntuOasisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title:             'Ubuntu Oasis',
      debugShowCheckedModeBanner: false,
      theme:             ubuntuTheme(),
      routerConfig:      router,
    );
  }
}
